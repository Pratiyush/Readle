import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../linker.dart';
import 'content_store.dart';
import 'fetcher.dart';
import 'manifest.dart';

enum UpdateKind {
  /// Nothing to offer: offline, checked recently, or no story Readle doesn't already have.
  none,

  /// New stories are on the CDN; the library offers "Update" (never automatic).
  available,

  /// The CDN needs a newer app (`min_client`); installed content keeps working.
  appTooOld,
}

/// The daily content check and the on-tap update, per `German/docs/content-client.md`:
/// at most one manifest request per 24 h on app open (with If-None-Match), a prompt only when there
/// are stories this app doesn't have, sha256-verified downloads written to a staging directory and
/// swapped in atomically, the previous set kept on any failure. Fails silently offline.
class ContentClient extends ChangeNotifier {
  ContentClient({
    required this.fetcher,
    required this.store,
    required this.prefs,
    required this.bundledIds,
    Uri? base,
    DateTime Function()? now,
    this.clientVersion = contentClientVersion,
  })  : base = base ?? Uri.parse(cdnBase),
        _now = now ?? DateTime.now {
    final pending = prefs.getString(_kPending);
    if (pending != null) {
      final j = jsonDecode(pending) as Map<String, dynamic>;
      kind = UpdateKind.values.byName(j['kind'] as String);
      newStories = (j['stories'] as num?)?.toInt() ?? 0;
    }
  }

  final Fetcher fetcher;
  final ContentStore store;
  final SharedPreferences prefs;

  /// Slugs of the stories bundled with the app; only stories outside this set are downloaded.
  final Set<String> bundledIds;
  final Uri base;
  final int clientVersion;
  final DateTime Function() _now;

  static const _kLastCheck = 'readle.cdn.lastCheck';
  static const _kEtag = 'readle.cdn.etag';
  static const _kManifest = 'readle.cdn.manifest';
  static const _kPending = 'readle.cdn.pending';
  static const checkInterval = Duration(hours: 24);

  UpdateKind kind = UpdateKind.none;
  int newStories = 0;
  bool busy = false;

  /// Bumped after every successful install, so screens reload the library.
  int installs = 0;

  Uri _url(String path) => base.resolve(checkedPath(path));

  /// The daily check. Never throws; [force] skips the 24-hour limit (Settings → Check now).
  Future<void> check({bool force = false}) async {
    final last = prefs.getInt(_kLastCheck);
    if (!force && last != null && _now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < checkInterval) return;
    try {
      final cached = prefs.getString(_kManifest);
      final r = await fetcher.get(_url('manifest.json'), etag: cached == null ? null : prefs.getString(_kEtag));
      if (r.status == 304 && cached != null) {
        await prefs.setInt(_kLastCheck, _now().millisecondsSinceEpoch);
        await _evaluate(Manifest.fromJson(jsonDecode(cached) as Map<String, dynamic>));
        return;
      }
      if (r.status != 200) return;
      final text = utf8.decode(r.body);
      final manifest = Manifest.fromJson(jsonDecode(text) as Map<String, dynamic>);
      await prefs.setString(_kManifest, text);
      if (r.etag != null) await prefs.setString(_kEtag, r.etag!);
      await prefs.setInt(_kLastCheck, _now().millisecondsSinceEpoch);
      await _evaluate(manifest);
    } catch (e) {
      debugPrint('content check failed (will retry next open): $e');
    }
  }

  Future<void> _evaluate(Manifest m) async {
    final installed = (await store.current())?.version ?? bundledContentVersion;
    if (m.minClient > clientVersion) return _set(UpdateKind.appTooOld, 0);
    if (m.contentVersion <= installed || m.feedStories == null) return _set(UpdateKind.none, 0);
    final feed = await _feed(m);
    final have = await _installedSlugs();
    final fresh = feed.where((s) => !bundledIds.contains(s.slug) && !have.contains(s.slug)).length;
    // A newer version that only changes words or media Readle doesn't use is not worth a prompt.
    _set(fresh > 0 ? UpdateKind.available : UpdateKind.none, fresh);
  }

  Future<List<FeedStory>> _feed(Manifest m) async {
    final bytes = await fetchVerified(fetcher, _url(m.feedStories!.url), m.feedStories!.sha256);
    return FeedStory.listFromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
  }

  Future<Set<String>> _installedSlugs() async {
    final set = await store.current();
    if (set == null) return {};
    try {
      final lib = await set.readJson('library.json');
      return {for (final s in lib['stories'] as List) (s as Map<String, dynamic>)['id'] as String};
    } catch (_) {
      return {};
    }
  }

  void _set(UpdateKind k, int stories) {
    kind = k;
    newStories = stories;
    if (k == UpdateKind.none) {
      prefs.remove(_kPending);
    } else {
      prefs.setString(_kPending, jsonEncode({'kind': k.name, 'stories': stories}));
    }
    notifyListeners();
  }

  /// Downloads every story the CDN has and the app doesn't, with its picture, and makes them the
  /// installed set. Returns false (and keeps the previous content) on any failure.
  Future<bool> update() async {
    final cached = prefs.getString(_kManifest);
    if (busy || cached == null) return false;
    busy = true;
    notifyListeners();
    final m = Manifest.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    final staged = await store.stage(m.contentVersion);
    try {
      final previous = await store.current();
      final reuse = previous == null ? <String, String>{} : await _files(previous);
      final files = <String, String>{};

      Future<List<int>> get(String url, String sha, String saveAs) async {
        final old = reuse[sha];
        final bytes = old != null && await previous!.file(old).exists()
            ? await previous.file(old).readAsBytes()
            : await fetchVerified(fetcher, _url(url), sha);
        if (!hashMatches(bytes, sha)) throw HashMismatch(_url(url));
        final out = File('${staged.path}/$saveAs');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(bytes, flush: true);
        files[sha] = saveAs;
        return bytes;
      }

      final wanted = (await _feed(m)).where((s) => !bundledIds.contains(s.slug)).toList();
      final metas = <Map<String, dynamic>>[];
      for (final levelFile in {for (final s in wanted) s.levelFile}) {
        final ref = m.storiesFile(levelFile);
        if (ref == null) throw FormatException('no hash for $levelFile');
        final pack = jsonDecode(utf8.decode(await get(ref.url, ref.sha256, 'packs/${ref.sha256}.json'))) as Map<String, dynamic>;
        final ids = {for (final s in wanted.where((s) => s.levelFile == levelFile)) s.id};
        final stories = [for (final s in (pack['stories'] as List).cast<Map<String, dynamic>>()) if (ids.contains(s['id'])) s];
        final level = (pack['level'] as String? ?? stories.first['cefr'] as String).toUpperCase();
        final index = m.levels[level]?.index;
        final images = index == null
            ? const <String, dynamic>{}
            : ((jsonDecode(utf8.decode(await get(index.url, index.sha256, 'packs/${index.sha256}.json'))) as Map<String, dynamic>)['story_images']
                    as Map<String, dynamic>? ??
                const {});
        for (final s in stories) {
          final slug = checkedSlug((s['slug'] as String?) ?? (s['id'] as String).replaceFirst('de.story.', ''));
          await File('${staged.path}/stories/$slug.json').create(recursive: true).then((f) => f.writeAsString(jsonEncode(s), flush: true));
          String? image;
          final img = images[s['id']] as Map<String, dynamic>?;
          if (img != null) {
            await get(img['url'] as String, checkedSha256(img['sha256'] as String), 'images/$slug.webp');
            image = 'images/$slug.webp';
          }
          metas.add(storyMeta(s, slug, image));
        }
      }
      if (m.lookup != null && wanted.isNotEmpty) {
        final lookup = jsonDecode(utf8.decode(await get(m.lookup!.url, m.lookup!.sha256, 'packs/lookup.json'))) as Map<String, dynamic>;
        final clips = {
          for (final e in ((lookup['clips'] as Map<String, dynamic>?) ?? const {}).entries)
            e.key: checkedPath((e.value as Map<String, dynamic>)['url'] as String),
        };
        await File('${staged.path}/packs/lookup.json').delete();
        files.remove(m.lookup!.sha256);
        await File('${staged.path}/clips.json').writeAsString(jsonEncode(clips), flush: true);
      }
      await File('${staged.path}/library.json').writeAsString(jsonEncode({'stories': metas}), flush: true);
      await File('${staged.path}/files.json').writeAsString(jsonEncode(files), flush: true);
      await store.commit(staged, m.contentVersion);
      installs++;
      _set(UpdateKind.none, 0);
      return true;
    } catch (e) {
      debugPrint('content update failed, keeping the installed content: $e');
      await store.discard(staged);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, String>> _files(InstalledSet set) async {
    try {
      return (await set.readJson('files.json')).cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  /// Library metadata for a CDN story, in the bundled `stories.json` shape (reading time at a
  /// learner's 60 words a minute, as tools/build_content.py's reading_minutes).
  static Map<String, dynamic> storyMeta(Map<String, dynamic> s, String slug, String? image) {
    final sentences = (s['sentences'] as List).cast<Map<String, dynamic>>();
    final words = sentences.fold<int>(0, (n, x) => n + Linker.tokenRe.allMatches(x['de'] as String).length);
    return {
      'id': slug,
      'title': s['title'],
      'level': (s['cefr'] as String).toUpperCase(),
      'collection': s['collection'] ?? 'fiction',
      'publishedAt': s['published_at'] ?? '',
      'image': image,
      'teaser': sentences.first['de'],
      'teaserEn': sentences.first['en'],
      'words': words,
      'minutes': (words / 60 + 0.5).floor().clamp(1, 1 << 30),
    };
  }
}
