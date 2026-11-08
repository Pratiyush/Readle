import 'package:audioplayers/audioplayers.dart';

/// Plays a word's recorded pronunciation (Lernle's clips, bundled as assets).
abstract class WordPlayer {
  /// Plays the asset at [assetPath] (`assets/content/audio/…`); false if it could not be played.
  Future<bool> play(String assetPath);
  Future<void> stop();
}

class AssetWordPlayer implements WordPlayer {
  final _player = AudioPlayer();

  @override
  Future<bool> play(String assetPath) async {
    try {
      await _player.stop();
      // AssetSource paths are relative to the `assets/` prefix of the audio cache.
      await _player.play(AssetSource(assetPath.replaceFirst('assets/', '')));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() => _player.stop();
}

/// Records what would be played. Used by tests.
class RecordingWordPlayer implements WordPlayer {
  RecordingWordPlayer({this.works = true});
  final bool works;
  final played = <String>[];

  @override
  Future<bool> play(String assetPath) async {
    played.add(assetPath);
    return works;
  }

  @override
  Future<void> stop() async {}
}
