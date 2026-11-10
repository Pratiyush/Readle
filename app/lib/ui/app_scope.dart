import 'package:flutter/widgets.dart';

import '../content/cdn/content_client.dart';
import '../content/content_repository.dart';
import '../content/models.dart';
import '../services/ads.dart';
import '../services/reminders.dart';
import '../services/share.dart';
import '../services/speech.dart';
import '../services/word_player.dart';
import '../state/app_state.dart';

/// The app's dependencies, handed down the tree. Rebuilds dependants when [AppState], [Ads]
/// (ready after consent) or the content [updates] change.
class AppScope extends InheritedNotifier<Listenable> {
  AppScope({
    super.key,
    required this.state,
    required this.content,
    required this.speech,
    required this.player,
    required this.ads,
    this.updates,
    this.reminders,
    this.sharer,
    required super.child,
  }) : super(notifier: Listenable.merge([state, ads, ?updates]));

  final AppState state;
  final Ads ads;

  /// New stories from the content CDN; null where the app runs without it (tests, previews).
  final ContentClient? updates;

  /// The daily reminder's platform side; null where the app runs without notifications.
  final Reminders? reminders;

  /// The system share sheet; null where the app runs without it (then nothing offers to share).
  final Sharer? sharer;

  final ContentRepository content;
  final Speech speech;
  final WordPlayer player;

  /// Say a word: its recorded clip when there is one, the device's German voice otherwise.
  Future<void> sayWord(DictEntry? entry, String text) async {
    await speech.stop();
    final clip = content.wordAudio(entry);
    if (clip != null && await player.play(clip)) return;
    // The production gate wants every fallback to device TTS visible.
    debugPrint('word audio: TTS fallback for "${entry?.headword ?? text}" (${clip == null ? 'no clip' : 'clip failed'})');
    await speech.speak(entry?.headword ?? text, rate: state.settings.speechRate);
  }

  /// Subscribes the caller to state changes.
  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  /// For callbacks: no subscription.
  static AppScope read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!;
}
