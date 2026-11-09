/// The parts of the german-content CDN manifest (`/manifest.json`, schema german-content/manifest@1)
/// that Readle reads. Spec: `German/docs/content-client.md`.
library;

/// The content-client contract this build understands. A manifest whose `min_client` is higher asks
/// for an app update before it can deliver new content.
const contentClientVersion = 1;

/// The `content_version` the bundled stories correspond to (the CDN's first release).
const bundledContentVersion = 1;

/// Whether the app checks the content CDN for new stories at all. Off by default (hub decision,
/// 2026-11-09) until the privacy policy covers content downloads and each CDN deploy is approved;
/// turn on with `--dart-define=CONTENT_CDN_ENABLED=true`. Stories already installed stay readable
/// either way.
const contentCdnEnabled = bool.fromEnvironment('CONTENT_CDN_ENABLED');

/// The live CDN. Tests and local runs point the client at `content/tools/serve` instead.
const cdnBase = String.fromEnvironment('CONTENT_CDN', defaultValue: 'https://german-content.pratiyush1.workers.dev/');

final _segment = RegExp(r'^[A-Za-z0-9_-][A-Za-z0-9._-]*$');
final _sha256 = RegExp(r'^[0-9a-f]{64}$');
final _slug = RegExp(r'^[a-z0-9][a-z0-9-]*$');

/// A file path from the manifest, the feed or the lookup must be relative to the CDN root, so every
/// request stays on the CDN's own host: no scheme, host, query, leading "/", "." or "..".
/// The hash already guards the bytes; this guards where the app connects to.
String checkedPath(String path) {
  if (path.isEmpty || !path.split('/').every(_segment.hasMatch)) throw FormatException('unsafe CDN path', path);
  return path;
}

String checkedSha256(String sha) {
  if (!_sha256.hasMatch(sha)) throw FormatException('not a sha256', sha);
  return sha;
}

/// A story slug becomes a file name on the device: lowercase letters, digits and hyphens only.
String checkedSlug(String slug) {
  if (!_slug.hasMatch(slug)) throw FormatException('unsafe story slug', slug);
  return slug;
}

/// A content-addressed file: its path on the CDN and the sha256 it must have.
class FileRef {
  const FileRef(this.url, this.sha256, this.bytes);
  final String url;
  final String sha256;
  final int bytes;

  /// Null when the entry is absent; a present entry with a bad path or hash rejects the manifest.
  static FileRef? fromJson(Object? j) {
    if (j == null) return null;
    if (j is! Map<String, dynamic> || j['url'] is! String || j['sha256'] is! String) throw FormatException('bad file entry', j);
    return FileRef(checkedPath(j['url'] as String), checkedSha256(j['sha256'] as String), (j['bytes'] as num?)?.toInt() ?? 0);
  }
}

class LevelFiles {
  const LevelFiles({this.stories, this.index});
  final FileRef? stories;
  final FileRef? index;
}

class Manifest {
  const Manifest({required this.contentVersion, required this.minClient, this.feedStories, this.lookup, this.levels = const {}});

  factory Manifest.fromJson(Map<String, dynamic> j) {
    if (j['schema'] != 'german-content/manifest@1') throw FormatException('manifest schema ${j['schema']}');
    final levels = <String, LevelFiles>{};
    for (final e in ((j['levels'] as Map<String, dynamic>?) ?? const {}).entries) {
      final l = e.value as Map<String, dynamic>;
      levels[e.key.toUpperCase()] = LevelFiles(stories: FileRef.fromJson(l['stories']), index: FileRef.fromJson(l['index']));
    }
    return Manifest(
      contentVersion: (j['content_version'] as num).toInt(),
      minClient: (j['min_client'] as num?)?.toInt() ?? 1,
      feedStories: FileRef.fromJson((j['feed'] as Map<String, dynamic>?)?['stories']),
      lookup: FileRef.fromJson(j['lookup']),
      levels: levels,
    );
  }

  final int contentVersion;
  final int minClient;
  final FileRef? feedStories;
  final FileRef? lookup;
  final Map<String, LevelFiles> levels;

  /// The stories pack whose url a feed entry names (`level_file`), with its expected hash.
  FileRef? storiesFile(String url) {
    for (final l in levels.values) {
      if (l.stories?.url == url) return l.stories;
    }
    return null;
  }
}

/// One entry of `feed/stories.json`.
class FeedStory {
  const FeedStory({required this.id, required this.level, required this.levelFile});
  final String id; // de.story.<slug>
  final String level;
  final String levelFile;

  String get slug => id.replaceFirst('de.story.', '');

  static List<FeedStory> listFromJson(Map<String, dynamic> j) => [
    for (final s in (j['stories'] as List).cast<Map<String, dynamic>>())
      FeedStory(id: s['id'] as String, level: (s['cefr'] as String? ?? '').toUpperCase(), levelFile: s['level_file'] as String),
  ];
}
