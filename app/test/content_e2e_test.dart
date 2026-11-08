// End to end over real HTTP: the fixture CDN written to disk and served by the hub's
// `content/tools/serve` (CDN-like headers, ETag / If-None-Match), then the app's own HttpFetcher,
// ContentClient and LayeredContentRepository. Skipped where the sibling content repo or node is
// missing (a standalone checkout of this repo).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readle/content/cdn/content_client.dart';
import 'package:readle/content/cdn/content_store.dart';
import 'package:readle/content/cdn/fetcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/cdn_fixture.dart';

const serve = '../../content/tools/serve';

void main() {
  final canServe = File(serve).existsSync() && Process.runSync('which', ['node']).exitCode == 0;

  test('check, 304, download and install through content/tools/serve', () async {
    final dist = CdnFixture().writeTo(Directory.systemTemp.createTempSync('readle-dist'));
    final root = Directory.systemTemp.createTempSync('readle-store');
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final server = await Process.start('node', [serve, '--dir', dist.path, '--port', '$port']);
    addTearDown(() {
      server.kill();
      dist.deleteSync(recursive: true);
      root.deleteSync(recursive: true);
    });
    final base = Uri.parse('http://127.0.0.1:$port/');
    final fetcher = HttpFetcher();
    for (var i = 0; i < 50; i++) {
      try {
        if ((await fetcher.get(base.resolve('manifest.json'))).status == 200) break;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 11, 8);
    final client = ContentClient(
      fetcher: fetcher,
      store: ContentStore(root),
      prefs: prefs,
      bundledIds: {'brot'},
      base: base,
      now: () => now,
    );
    await client.check();
    expect((client.kind, client.newStories), (UpdateKind.available, 1));
    expect(prefs.getString('readle.cdn.etag'), isNotNull, reason: 'the server sends an ETag');

    final etag = prefs.getString('readle.cdn.etag');
    final again = await fetcher.get(base.resolve('manifest.json'), etag: etag);
    expect(again.status, 304, reason: 'If-None-Match is honoured');

    expect(await client.update(), isTrue);
    final set = (await ContentStore(root).current())!;
    final lib = jsonDecode(await set.file('library.json').readAsString()) as Map<String, dynamic>;
    expect([for (final s in lib['stories'] as List) s['id']], [newSlug]);
    expect(await set.file('images/$newSlug.webp').length(), greaterThan(1000));

    now = now.add(const Duration(days: 1, hours: 1));
    await client.check();
    expect(client.kind, UpdateKind.none, reason: 'next day: 304, everything installed');
  }, skip: canServe ? false : 'needs node and ../../content/tools/serve');
}
