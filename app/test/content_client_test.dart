// The content client against an in-memory CDN: version compare, the 24-hour check with
// If-None-Match, sha256 verification, the atomic swap, rollback, min_client and offline.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show FileImage;
import 'package:flutter_test/flutter_test.dart';
import 'package:readle/content/cdn/content_client.dart';
import 'package:readle/content/cdn/content_store.dart';
import 'package:readle/content/cdn/fetcher.dart';
import 'package:readle/content/cdn/manifest.dart' show checkedPath, checkedSlug, contentCdnEnabled;
import 'package:readle/content/content_repository.dart';
import 'package:readle/content/layered_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/cdn_fixture.dart';

/// Reads assets straight from the app folder, so these tests need no asset build.
class DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(await File(key).readAsBytes());
}

class _Offline implements Fetcher {
  @override
  Future<FetchResult> get(Uri url, {String? etag}) => throw const SocketException('offline');
}

void main() {
  late Directory root;
  late SharedPreferences prefs;
  var clock = DateTime(2026, 11, 8, 9);

  setUp(() async {
    root = Directory.systemTemp.createTempSync('readle-cdn');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    clock = DateTime(2026, 11, 8, 9);
  });
  tearDown(() => root.deleteSync(recursive: true));

  ContentClient client(CdnFixture cdn, {Fetcher? fetcher}) => ContentClient(
    fetcher: fetcher ?? cdn.fetcher,
    store: ContentStore(root),
    prefs: prefs,
    bundledIds: {'brot'},
    base: Uri.parse('https://cdn.test/'),
    now: () => clock,
  );

  test('the CDN check is off unless the build turns it on (CONTENT_CDN_ENABLED)', () {
    expect(contentCdnEnabled, isFalse);
  });

  group('every request stays on the CDN host, every file inside the content folder', () {
    test('paths must be relative to the CDN root', () {
      for (final ok in ['manifest.json', 'files/ab/abc123.webp', 'stories/a1.3f2a.json', 'feed/stories.0a1b.json']) {
        expect(checkedPath(ok), ok);
      }
      for (final bad in [
        'https://evil.test/x.json',
        '//evil.test/x',
        '/etc/passwd',
        '../x.json',
        'a/../b',
        'a//b',
        '',
        './a',
        'a?b=1',
        'a b',
      ]) {
        expect(() => checkedPath(bad), throwsFormatException, reason: bad);
      }
      expect(checkedSlug('was-der-dolmetscher-nicht-sagte'), isNotEmpty);
      for (final bad in ['../../escape', 'a/b', 'Brot', '', '-x']) {
        expect(() => checkedSlug(bad), throwsFormatException, reason: bad);
      }
    });

    test('a manifest pointing at another host is refused, silently, with no request to it', () async {
      for (final url in ['https://evil.test/feed.json', '../feed.json']) {
        final cdn = CdnFixture();
        final feed = cdn.manifest['feed']['stories'] as Map<String, dynamic>;
        cdn.manifest['feed'] = {
          'stories': {...feed, 'url': url},
        };
        cdn.files['manifest.json'] = utf8.encode(jsonEncode(cdn.manifest));
        final c = client(cdn);
        await c.check(force: true);
        expect(c.kind, UpdateKind.none, reason: url);
        expect(cdn.requests, ['manifest.json'], reason: url);
      }
    });

    test('a story slug that would write outside the content folder fails the install, nothing written', () async {
      final cdn = CdnFixture(slug: '../../escape');
      final c = client(cdn);
      await c.check();
      expect(c.kind, UpdateKind.available);
      expect(await c.update(), isFalse);
      expect(await ContentStore(root).current(), isNull, reason: 'nothing installed');
      expect(File('${root.parent.path}/escape.json').existsSync(), isFalse);
      expect(root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('escape.json')), isEmpty);
    });
  });

  test('the bundled version: no prompt and no further downloads', () async {
    final cdn = CdnFixture(version: 1);
    final c = client(cdn);
    await c.check();
    expect(c.kind, UpdateKind.none);
    expect(cdn.requests, ['manifest.json']);
  });

  test('a newer version with a story the app lacks: prompt, then install it on tap', () async {
    final cdn = CdnFixture();
    final c = client(cdn);
    await c.check();
    expect((c.kind, c.newStories), (UpdateKind.available, 1));
    expect(await c.update(), isTrue);
    expect(c.kind, UpdateKind.none);

    final set = (await ContentStore(root).current())!;
    expect(set.version, 2);
    final lib = (await set.readJson('library.json'))['stories'] as List;
    expect([for (final s in lib) s['id']], [newSlug]);
    expect(lib.single['title'], newTitle);
    expect(await set.file('images/$newSlug.webp').exists(), isTrue);
    expect((await set.readJson('clips.json')).keys, ['de.abbuchung.n']);
    expect(root.listSync().whereType<Directory>().map((d) => d.uri.pathSegments[d.uri.pathSegments.length - 2]), [
      set.dir.uri.pathSegments[set.dir.uri.pathSegments.length - 2],
    ], reason: 'no staging or old set left behind');

    // The prompt survives an app restart until installed, and not after.
    expect(client(cdn).kind, UpdateKind.none);
  });

  test('at most one manifest request a day, then If-None-Match (304)', () async {
    final cdn = CdnFixture(version: 1);
    final c = client(cdn);
    await c.check();
    clock = clock.add(const Duration(hours: 23));
    await c.check();
    expect(cdn.requests, ['manifest.json'], reason: 'second open the same day: no request');
    clock = clock.add(const Duration(hours: 2));
    await c.check();
    expect(cdn.requests, ['manifest.json', 'manifest.json']);
    expect(c.kind, UpdateKind.none, reason: '304: the cached manifest is evaluated again');
  });

  test('a file whose hash does not match is refused and the installed set is kept', () async {
    final v2 = CdnFixture();
    final c2 = client(v2);
    await c2.check();
    expect(await c2.update(), isTrue);
    final before = (await ContentStore(root).current())!;

    final other = utf8.encode('a different picture');
    final v3 = CdnFixture(version: 3, image: other);
    v3.etag = '"v3"';
    final h = CdnFixture.sha(other);
    v3.files['files/${h.substring(0, 2)}/$h.webp'] = utf8.encode('tampered in transit');
    final c3 = client(v3);
    await c3.check(force: true);
    expect(c3.kind, UpdateKind.none, reason: 'v3 adds no story beyond the installed one');
    // Force the download path: a fresh install with v3 must fail on the tampered picture.
    await ContentStore(root).current().then((s) => s!.file('library.json').writeAsString('{"stories":[]}'));
    await c3.check(force: true);
    expect(c3.kind, UpdateKind.available);
    expect(await c3.update(), isFalse);

    final after = (await ContentStore(root).current())!;
    expect((after.version, after.dir.path), (before.version, before.dir.path), reason: 'rolled back');
    expect(root.listSync().whereType<Directory>().where((d) => d.path.contains('staging')), isEmpty);
    expect(c3.kind, UpdateKind.available, reason: 'offered again; retried on the next tap or day');
  });

  test('min_client above this build asks for an app update and keeps the content', () async {
    final c = client(CdnFixture(minClient: 99));
    await c.check();
    expect(c.kind, UpdateKind.appTooOld);
  });

  test('offline: the check fails silently and is retried on the next open', () async {
    final c = client(CdnFixture(), fetcher: _Offline());
    await c.check();
    expect(c.kind, UpdateKind.none);
    expect(prefs.getInt('readle.cdn.lastCheck'), isNull);
  });

  test('the library shows the installed story, linked like a bundled one', () async {
    final cdn = CdnFixture();
    final c = client(cdn);
    await c.check();
    await c.update();
    final bundle = DiskBundle();
    final repo = LayeredContentRepository(
      bundled: AssetContentRepository(bundle: bundle, decodeInIsolate: false),
      store: ContentStore(root),
      bundle: bundle,
      cdn: Uri.parse('https://cdn.test/'),
    );
    await repo.reload();
    final lib = await repo.library();
    expect(lib.first.id, newSlug, reason: 'newest first');
    expect(lib.length, 108);
    expect(repo.image(lib.first.image), isA<FileImage>());

    final story = await repo.story(newSlug);
    final linked = {
      for (final s in story.sentences)
        for (final t in s.tokens)
          if (t.key != null) t.text: t.key,
    };
    expect(linked, containsPair('gibt', 'de.geben.v'));
    expect(linked, containsPair('Bäcker', 'de.bäcker.n'));
    expect(linked, containsPair('Abbuchung', 'de.abbuchung.n'));

    final dict = await repo.dictionary();
    expect(dict['de.geben.v'], isNotNull);
    expect(dict['de.abbuchung.n'], isNotNull, reason: 'from lexicon.json');
    expect(repo.wordAudio(dict['de.abbuchung.n']), startsWith('https://cdn.test/files/'));
    expect(repo.wordAudio(dict['de.geben.v']), 'assets/content/audio/de.geben.v.mp3');
  });
}
