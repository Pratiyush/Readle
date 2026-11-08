import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models.dart';

/// Everything the app reads — stories, pictures, the dictionary — goes through one repository.
/// Today it is the bundled assets; the shared german-content CDN (stories, daily articles, word
/// sets) can be added later as another implementation, or one that layers live packs over the
/// bundled content, without touching any screen.
abstract class ContentRepository {
  Future<List<StoryMeta>> library();
  Future<Story> story(String id);
  Future<Dictionary> dictionary();

  /// The picture for a library or story `image` path, or null when there is none.
  ImageProvider? image(String? path);
}

/// Reads the compiled JSON bundled under `assets/content/` (a symlink to the web app's
/// public/content). Each file is parsed once; a failed load is retried on the next call.
class AssetContentRepository implements ContentRepository {
  AssetContentRepository({AssetBundle? bundle, this.base = 'assets/content/', this.decodeInIsolate = true})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String base;

  /// Off in widget tests, where a spawned isolate never completes under the fake clock.
  final bool decodeInIsolate;
  final _cache = <String, Future<Object?>>{};
  final _parsed = <String, Object?>{};

  Future<T> _load<T>(String path, T Function(Object? json) parse) {
    // Already parsed: hand out a fresh future in the caller's zone (a future completed in another
    // zone would deliver there, which a widget test's fake clock never flushes).
    if (_parsed.containsKey(path)) return Future.value(_parsed[path] as T);
    final hit = _cache.putIfAbsent(path, () async {
      final text = await _bundle.loadString(base + path, cache: false);
      // The dictionary is ~200 KB: decode it off the UI thread.
      final json = decodeInIsolate && text.length > 50000 ? await compute(jsonDecode, text) : jsonDecode(text);
      return _parsed[path] = parse(json);
    });
    hit.catchError((Object _) {
      _cache.remove(path);
      return null;
    });
    return hit.then((v) => v as T);
  }

  @override
  Future<List<StoryMeta>> library() => _load('stories.json',
      (j) => [for (final s in j as List) StoryMeta.fromJson(s as Map<String, dynamic>)]);

  @override
  Future<Story> story(String id) =>
      _load('stories/$id.json', (j) => Story.fromJson(j as Map<String, dynamic>));

  @override
  Future<Dictionary> dictionary() => _load('dict.json', (j) => {
        for (final e in (j as Map<String, dynamic>).entries) e.key: DictEntry.fromJson(e.value as Map<String, dynamic>),
      });

  @override
  ImageProvider? image(String? path) => path == null ? null : AssetImage(base + path, bundle: _bundle);
}
