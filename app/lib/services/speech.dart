import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// German text-to-speech. The device engine in the app; a recorder in tests.
abstract class Speech {
  /// Whether a German voice exists. Without one, the Listen controls are hidden rather than
  /// reading German with an English voice.
  Future<bool> available();

  /// Completes when the text has been spoken, or as soon as [stop] interrupts it.
  Future<void> speak(String text, {double rate = 0.9});

  Future<void> stop();
}

class DeviceSpeech implements Speech {
  DeviceSpeech() : _tts = FlutterTts();

  final FlutterTts _tts;
  Future<bool>? _ready;

  Future<bool> _init() => _ready ??= () async {
        try {
          final ok = await _tts.isLanguageAvailable('de-DE');
          if (ok != true) return false;
          await _tts.setLanguage('de-DE');
          await _tts.awaitSpeakCompletion(true);
          return true;
        } catch (_) {
          return false;
        }
      }();

  @override
  Future<bool> available() => _init();

  @override
  Future<void> speak(String text, {double rate = 0.9}) async {
    if (!await _init()) return;
    // flutter_tts: 0.5 is the platform's normal pace; the settings use the web app's units (0.9).
    await _tts.setSpeechRate((rate * 0.5).clamp(0.1, 1.0));
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

/// Records what would be said; each utterance "takes" [duration]. Used by tests and on devices
/// where the engine can't be trusted.
class RecordingSpeech implements Speech {
  RecordingSpeech({this.duration = const Duration(milliseconds: 150), this.hasVoice = true});

  final Duration duration;
  final bool hasVoice;
  final spoken = <String>[];
  Completer<void>? _current;

  @override
  Future<bool> available() async => hasVoice;

  @override
  Future<void> speak(String text, {double rate = 0.9}) {
    spoken.add(text);
    final done = Completer<void>();
    _current = done;
    Timer(duration, () {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  @override
  Future<void> stop() async {
    final c = _current;
    if (c != null && !c.isCompleted) c.complete();
  }
}
