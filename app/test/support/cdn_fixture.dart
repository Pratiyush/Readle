// A miniature german-content CDN (manifest@1 layout, content-addressed files) with one story the
// app doesn't bundle. Served from memory for unit and UI tests, or written to disk for
// `content/tools/serve` in the end-to-end test.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:readle/content/cdn/fetcher.dart';

const newSlug = 'neuer-baecker';
const newTitle = 'Der neue Bäcker';

class CdnFixture {
  CdnFixture({int version = 2, int minClient = 1, List<int>? image, String slug = newSlug}) {
    final img = image ?? File('assets/content/images/brot.webp').readAsBytesSync();
    final story = {
      'id': 'de.story.$slug',
      'slug': slug,
      'title': newTitle,
      'cefr': 'A1',
      'published_at': '2099-01-01',
      'collection': 'fiction',
      'sentences': [
        {'de': 'Der Bäcker gibt mir ein Brot.', 'en': 'The baker gives me a loaf of bread.'},
        {'de': 'Die Abbuchung kommt morgen.', 'en': 'The debit comes tomorrow.'},
      ],
      'image': {'path': 'story-images/de.story.$slug.webp'},
      'audio': null,
    };
    final brot = {...story, 'id': 'de.story.brot', 'slug': 'brot', 'title': 'Brot ist hier wichtig'};
    final imageUrl = _file(img, 'webp');
    final pack = _hashed('stories/a1', {
      'schema': 'german-content/stories@1',
      'level': 'A1',
      'stories': [brot, story],
    });
    final index = _hashed('index/a1', {
      'schema': 'german-content/file-index@1',
      'level': 'A1',
      'story_images': {
        'de.story.$slug': {'path': 'story-images/x.webp', 'sha256': sha(img), 'bytes': img.length, 'url': imageUrl},
      },
    });
    final clip = _file(utf8.encode('ID3 fake clip'), 'mp3');
    final lookup = _hashed('lookup', {
      'schema': 'german-content/lookup@1',
      'clips': {
        'de.abbuchung.n': {'url': clip, 'sha256': sha(files[clip]!)},
      },
    });
    final feed = _hashed('feed/stories', {
      'schema': 'german-content/feed-stories@1',
      'stories': [
        {'id': 'de.story.brot', 'cefr': 'A1', 'level_file': pack.url},
        {'id': 'de.story.$slug', 'cefr': 'A1', 'level_file': pack.url},
      ],
    });
    manifest = {
      'schema': 'german-content/manifest@1',
      'content_version': version,
      'min_client': minClient,
      'levels': {
        'a1': {'stories': pack.json, 'index': index.json},
      },
      'feed': {'stories': feed.json},
      'lookup': lookup.json,
    };
    files['manifest.json'] = utf8.encode(jsonEncode(manifest));
  }

  late final Map<String, dynamic> manifest;
  final files = <String, List<int>>{};
  final requests = <String>[];
  String etag = '"v1"';

  static String sha(List<int> b) => sha256.convert(b).toString();

  String _file(List<int> bytes, String ext) {
    final h = sha(bytes);
    final url = 'files/${h.substring(0, 2)}/$h.$ext';
    files[url] = bytes;
    return url;
  }

  ({String url, Map<String, dynamic> json}) _hashed(String stem, Object body) {
    final bytes = utf8.encode(jsonEncode(body));
    final h = sha(bytes);
    final url = '$stem.${h.substring(0, 12)}.json';
    files[url] = bytes;
    return (url: url, json: {'url': url, 'sha256': h, 'bytes': bytes.length});
  }

  /// Serves [files] from memory like the CDN, incl. If-None-Match on the manifest.
  Fetcher get fetcher => _MemoryFetcher(this);

  /// Writes the fixture as a dist/ directory for content/tools/serve.
  Directory writeTo(Directory dir) {
    for (final e in files.entries) {
      File('${dir.path}/${e.key}')
        ..createSync(recursive: true)
        ..writeAsBytesSync(e.value);
    }
    return dir;
  }
}

class _MemoryFetcher implements Fetcher {
  _MemoryFetcher(this.cdn);
  final CdnFixture cdn;
  bool offline = false;

  @override
  Future<FetchResult> get(Uri url, {String? etag}) async {
    final path = url.path.replaceFirst('/', '');
    cdn.requests.add(path);
    final body = cdn.files[path];
    if (body == null) return const FetchResult(404, []);
    if (path == 'manifest.json' && etag == cdn.etag) return FetchResult(304, const [], etag: cdn.etag);
    return FetchResult(200, body, etag: path == 'manifest.json' ? cdn.etag : null);
  }
}
