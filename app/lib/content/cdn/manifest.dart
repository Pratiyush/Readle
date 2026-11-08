/// The parts of the german-content CDN manifest (`/manifest.json`, schema german-content/manifest@1)
/// that Readle reads. Spec: `German/docs/content-client.md`.
library;

/// The content-client contract this build understands. A manifest whose `min_client` is higher asks
/// for an app update before it can deliver new content.
const contentClientVersion = 1;

/// The `content_version` the bundled stories correspond to (the CDN's first release).
const bundledContentVersion = 1;

/// The live CDN. Tests and local runs point the client at `content/tools/serve` instead.
const cdnBase = String.fromEnvironment('CONTENT_CDN', defaultValue: 'https://german-content.pratiyush1.workers.dev/');

/// A content-addressed file: its path on the CDN and the sha256 it must have.
class FileRef {
  const FileRef(this.url, this.sha256, this.bytes);
  final String url;
  final String sha256;
  final int bytes;

  static FileRef? fromJson(Object? j) {
    if (j is! Map<String, dynamic> || j['url'] is! String || j['sha256'] is! String) return null;
    return FileRef(j['url'] as String, j['sha256'] as String, (j['bytes'] as num?)?.toInt() ?? 0);
  }
}

class LevelFiles {
  const LevelFiles({this.stories, this.index});
  final FileRef? stories;
  final FileRef? index;
}

class Manifest {
  const Manifest({
    required this.contentVersion,
    required this.minClient,
    this.feedStories,
    this.lookup,
    this.levels = const {},
  });

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
