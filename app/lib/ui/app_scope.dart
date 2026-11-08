import 'package:flutter/widgets.dart';

import '../content/content_repository.dart';
import '../services/speech.dart';
import '../state/app_state.dart';

/// The app's dependencies, handed down the tree. Rebuilds dependants when [AppState] changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required this.content,
    required this.speech,
    required super.child,
  }) : super(notifier: state);

  final ContentRepository content;
  final Speech speech;

  AppState get state => notifier!;

  /// Subscribes the caller to state changes.
  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  /// For callbacks: no subscription.
  static AppScope read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!;
}
