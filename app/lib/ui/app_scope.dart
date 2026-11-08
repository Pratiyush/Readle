import 'package:flutter/widgets.dart';

import '../content/content_repository.dart';
import '../content/models.dart';
import '../services/speech.dart';
import '../services/word_player.dart';
import '../state/app_state.dart';

/// The app's dependencies, handed down the tree. Rebuilds dependants when [AppState] changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required this.content,
    required this.speech,
    required this.player,
    required super.child,
  }) : super(notifier: state);

  final ContentRepository content;
  final Speech speech;
  final WordPlayer player;

  /// Say a word: its recorded clip when there is one, the device's German voice otherwise.
  Future<void> sayWord(DictEntry? entry, String text) async {
    await speech.stop();
    final clip = content.wordAudio(entry);
    if (clip != null && await player.play(clip)) return;
    await speech.speak(entry?.headword ?? text, rate: state.settings.speechRate);
  }

  AppState get state => notifier!;

  /// Subscribes the caller to state changes.
  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  /// For callbacks: no subscription.
  static AppScope read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!;
}
