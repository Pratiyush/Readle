import 'dart:convert';
import 'dart:io';

/// The stories installed from the CDN, as one immutable directory per content version:
///
///     <root>/current.json        {"version": 2, "dir": "v2-<time>"}: the only pointer the app reads
///     <root>/v2-<time>/library.json     StoryMeta JSON for each downloaded story (image = absolute path)
///     <root>/v2-<time>/stories/<slug>.json   the CDN story as published (linked when opened)
///     <root>/v2-<time>/images/<slug>.webp
///     <root>/v2-<time>/clips.json       dictionary id → CDN clip path, for words without a bundled clip
///     <root>/v2-<time>/files.json       sha256 → file in this set, so the next update reuses what it has
///
/// An update is written to a staging directory, verified, renamed into place and only then made
/// current by atomically replacing current.json. A failure at any step leaves the previous set
/// current and untouched.
class ContentStore {
  ContentStore(this.root);
  final Directory root;

  File get _pointer => File('${root.path}/current.json');

  /// The installed set, or null when only the bundled content exists (or the pointer is unreadable).
  Future<InstalledSet?> current() async {
    try {
      if (!await _pointer.exists()) return null;
      final j = jsonDecode(await _pointer.readAsString()) as Map<String, dynamic>;
      final dir = Directory('${root.path}/${j['dir']}');
      if (!await dir.exists()) return null;
      return InstalledSet((j['version'] as num).toInt(), dir);
    } catch (_) {
      return null;
    }
  }

  /// A fresh, empty staging directory for [version].
  Future<Directory> stage(int version) async {
    final dir = Directory('${root.path}/staging-$version');
    if (await dir.exists()) await dir.delete(recursive: true);
    return dir.create(recursive: true);
  }

  /// Moves a fully written staging directory into place and makes it current.
  Future<InstalledSet> commit(Directory staged, int version) async {
    // A unique name, so the set being replaced stays intact until the pointer has moved.
    final name = 'v$version-${DateTime.now().microsecondsSinceEpoch}';
    final dir = await staged.rename('${root.path}/$name');
    final tmp = File('${root.path}/current.json.tmp');
    await tmp.writeAsString(jsonEncode({'version': version, 'dir': name}), flush: true);
    await tmp.rename(_pointer.path); // atomic on the same filesystem
    await _sweep(keep: dir.path);
    return InstalledSet(version, dir);
  }

  Future<void> discard(Directory staged) async {
    if (await staged.exists()) await staged.delete(recursive: true);
  }

  /// Deletes every set and staging directory except [keep]. Best effort.
  Future<void> _sweep({required String keep}) async {
    try {
      await for (final e in root.list()) {
        final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (e is Directory && e.path != keep && (name.startsWith('v') || name.startsWith('staging-'))) {
          await e.delete(recursive: true);
        }
      }
    } catch (_) {}
  }
}

class InstalledSet {
  const InstalledSet(this.version, this.dir);
  final int version;
  final Directory dir;

  File file(String relative) => File('${dir.path}/$relative');

  Future<Map<String, dynamic>> readJson(String relative) async => jsonDecode(await file(relative).readAsString()) as Map<String, dynamic>;
}
