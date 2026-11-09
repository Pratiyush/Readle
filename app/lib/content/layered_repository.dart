import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'cdn/content_store.dart';
import 'cdn/manifest.dart';
import 'content_repository.dart';
import 'linker.dart';
import 'models.dart';

/// The bundled content with the stories installed from the CDN layered on top. Screens see one
/// library: downloaded stories are linked on first open by [Linker] (the builder's own rules), and
/// their words are looked up in the bundled dictionary plus `assets/linker/lexicon.json`. A word
/// without a bundled clip plays the CDN's recording, or the device voice when offline.
///
/// After [reload] completes, reads come from memory, so screens and widget tests never wait on
/// file IO.
class LayeredContentRepository implements ContentRepository {
  LayeredContentRepository({required this.bundled, required this.store, AssetBundle? bundle, Uri? cdn})
    : _bundle = bundle ?? rootBundle,
      _cdn = cdn ?? Uri.parse(cdnBase);

  final AssetContentRepository bundled;
  final ContentStore store;
  final AssetBundle _bundle;
  final Uri _cdn;

  List<StoryMeta> _installed = const [];
  Map<String, String> _clips = const {};
  InstalledSet? _set;
  Linker? _linker;
  Dictionary? _dictionary;
  final _stories = <String, Story>{};
  Future<void>? _loading;
  bool _loaded = false;

  /// Re-reads the installed set (at start and after every update).
  Future<void> reload() => _loading = _load().whenComplete(() => _loaded = true);

  Future<void> _load() async {
    _dictionary = null;
    _stories.clear();
    final set = await store.current();
    if (set == null) return _clear();
    try {
      final lib = await set.readJson('library.json');
      _installed = [
        for (final s in (lib['stories'] as List).cast<Map<String, dynamic>>())
          StoryMeta.fromJson({...s, 'image': s['image'] == null ? null : set.file(s['image'] as String).path}),
      ];
      _clips = await set.file('clips.json').exists() ? (await set.readJson('clips.json')).cast<String, String>() : const {};
      _set = set;
      await Future.wait([_linkerReady(), dictionary(), bundled.library()]);
    } catch (e) {
      debugPrint('installed content unreadable, using the bundled stories: $e');
      _clear();
    }
  }

  void _clear() {
    _set = null;
    _installed = const [];
    _clips = const {};
  }

  // A future made in this zone once loaded: a widget test's fake clock never flushes one completed
  // in the real zone (where file IO ran).
  Future<void> _ready() => _loaded ? Future.value() : (_loading ??= reload());

  Future<Linker> _linkerReady() async =>
      _linker ??= Linker.fromJson(await _decode(await _bundle.loadString('assets/linker/linker.json', cache: false)));

  static Future<Map<String, dynamic>> _decode(String text) async =>
      (kIsWeb || text.length < 50000 ? jsonDecode(text) : await compute(jsonDecode, text)) as Map<String, dynamic>;

  @override
  Future<List<StoryMeta>> library() async {
    await _ready();
    final base = await bundled.library();
    if (_installed.isEmpty) return base;
    final have = {for (final s in base) s.id};
    final all = [...base, ..._installed.where((s) => !have.contains(s.id))];
    // Newest first, as tools/build_content.py orders stories.json.
    all.sort((a, b) => b.publishedAt != a.publishedAt ? b.publishedAt.compareTo(a.publishedAt) : b.id.compareTo(a.id));
    return all;
  }

  @override
  Future<Story> story(String id) async {
    final cached = _stories[id];
    if (cached != null) return cached;
    await _ready();
    final meta = _installed.where((s) => s.id == id).firstOrNull;
    if (meta == null || _set == null) return bundled.story(id);
    final raw = await _set!.readJson('stories/$id.json');
    final linker = await _linkerReady();
    final story = Story.fromJson({
      ...meta.toJson(),
      'sentences': [
        for (final s in (raw['sentences'] as List).cast<Map<String, dynamic>>())
          {'de': s['de'], 'en': s['en'], 't': linker.tokenise(s['de'] as String)},
      ],
    });
    return _stories[id] = story;
  }

  @override
  Future<Dictionary> dictionary() async {
    final ready = _dictionary;
    if (ready != null) return ready;
    final base = await bundled.dictionary();
    if (_set == null) return base;
    final more = await _decode(await _bundle.loadString('assets/linker/lexicon.json', cache: false));
    return _dictionary = {
      for (final e in more.entries)
        e.key: DictEntry.fromJson({
          ...e.value as Map<String, dynamic>,
          if (_clips[e.key] != null) 'au': _cdn.resolve(_clips[e.key]!).toString(),
        }),
      ...base,
    };
  }

  @override
  ImageProvider? image(String? path) => path != null && path.startsWith('/') ? FileImage(File(path)) : bundled.image(path);

  @override
  String? wordAudio(DictEntry? entry) => entry?.audio != null && entry!.audio!.startsWith('http') ? entry.audio : bundled.wordAudio(entry);
}
