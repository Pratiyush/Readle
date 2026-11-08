// End-to-end flows shared by the headless widget tests (test/widget_test.dart) and the on-device
// integration test (integration_test/app_test.dart), so both always check the same behaviour.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readle/app.dart';
import 'package:readle/content/content_repository.dart';
import 'package:readle/services/speech.dart';
import 'package:readle/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Harness {
  Harness(this.state, this.speech);
  final AppState state;
  final RecordingSpeech speech;
}

Future<Harness> pumpApp(WidgetTester tester, {bool decodeInIsolate = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  final state = await AppState.load(prefs);
  final speech = RecordingSpeech(duration: const Duration(milliseconds: 120));
  final content = AssetContentRepository(decodeInIsolate: decodeInIsolate);
  // Load the content for real before the app's first frame (assets are real I/O).
  await tester.runAsync(() async {
    await content.library();
    await content.dictionary();
    await content.story('brot');
  });
  await tester.pumpWidget(ReadleApp(state: state, content: content, speech: speech));
  await tester.pumpAndSettle();
  return Harness(state, speech);
}

/// Pump until [finder] matches: on a real device, loading and route transitions take wall time.
Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 15)}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (finder.evaluate().isEmpty) {
    final onScreen = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().take(20);
    fail('Timed out waiting for $finder. On screen: ${onScreen.join(' | ')}');
  }
}

/// Type into the library search and put the soft keyboard away (on a device it shrinks the list).
Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('search')), text);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> openBrot(WidgetTester tester) async {
  await search(tester, 'Brot ist hier');
  await waitFor(tester, find.byKey(const Key('story-brot')));
  await tester.ensureVisible(find.byKey(const Key('story-brot')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('story-brot')));
  await tester.pumpAndSettle();
  await waitFor(tester, find.byKey(const Key('reader-list')));
  expect(find.text('Brot ist hier wichtig'), findsOneWidget);
}

/// Scroll [target] fully into view inside [list] (a partly visible widget can miss a tap).
Future<void> reveal(WidgetTester tester, Finder target, Key list) async {
  final scrollable = find.descendant(of: find.byKey(list), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(target, 300, scrollable: scrollable);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> tapWord(WidgetTester tester, String word) async {
  await tester.tapOnText(find.textRange.ofSubstring(word).first);
  await tester.pumpAndSettle();
}

Future<void> libraryFilters(WidgetTester tester) async {
  await pumpApp(tester);
  expect(find.byKey(const Key('daily')), findsOneWidget);
  await search(tester, 'bread');
  expect(find.byKey(const Key('story-frisches-brot-in-der-baeckerei')), findsOneWidget);
  await search(tester, 'zzzz');
  expect(find.text('No stories match these filters.'), findsOneWidget);
}

Future<void> tapWordAndSave(WidgetTester tester) async {
  final h = await pumpApp(tester);
  await openBrot(tester);
  await tapWord(tester, 'gibt');
  expect(find.byKey(const Key('word-sheet')), findsOneWidget);
  expect(find.text('geben'), findsWidgets);
  expect(find.textContaining('to give'), findsOneWidget);
  await tester.tap(find.byKey(const Key('save-word')));
  await tester.pumpAndSettle();
  expect(find.text('✓ Saved to your words'), findsOneWidget);
  expect(h.state.words.keys, contains('de.geben.v'));

  await tester.tap(find.byTooltip('Close'));
  await tester.pumpAndSettle();
  await tapWord(tester, 'Deutschland');
  expect(find.textContaining('No dictionary entry'), findsOneWidget);
  await tester.tap(find.byTooltip('Close'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('show-all-translations')));
  await tester.pumpAndSettle();
  expect(find.text('In Germany, bread is very important.'), findsOneWidget);
}

Future<void> listenThenLeave(WidgetTester tester) async {
  final h = await pumpApp(tester);
  await openBrot(tester);
  await tester.tap(find.byKey(const Key('listen')));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  expect(h.speech.spoken.length, 8, reason: 'reads the whole story');
  expect(find.byTooltip('Listen'), findsOneWidget);

  await tester.tap(find.byKey(const Key('listen')));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.byKey(const Key('reader-back')));
  await tester.pumpAndSettle();
  final atLeave = h.speech.spoken.length;
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  expect(h.speech.spoken.length, atLeave, reason: 'stops when leaving the reader');
}

Future<void> quizAndProgress(WidgetTester tester) async {
  final h = await pumpApp(tester);
  await openBrot(tester);
  await reveal(tester, find.byKey(const Key('finish')), const Key('reader-list'));
  await tester.tap(find.byKey(const Key('finish')));
  await tester.pumpAndSettle();
  await waitFor(tester, find.byKey(const Key('option-0')));
  for (var i = 0; i < 10 && find.byKey(const Key('option-0')).evaluate().isNotEmpty; i++) {
    await tester.tap(find.byKey(const Key('option-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feedback')), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue')));
    await tester.pumpAndSettle();
  }
  expect(find.byKey(const Key('result-headline')), findsOneWidget);
  expect(h.state.read.keys, contains('brot'));
  expect(h.state.quiz.keys, contains('brot'));
  await tester.tap(find.byKey(const Key('next-story')));
  await tester.pumpAndSettle();
  await waitFor(tester, find.byKey(const Key('story-brot')));
  expect(find.descendant(of: find.byKey(const Key('story-brot')), matching: find.text('✓ Read')), findsOneWidget);
  expect(find.descendant(of: find.byKey(const Key('streak')), matching: find.text('🔥 1')), findsOneWidget);
}

Future<void> practiceWords(WidgetTester tester) async {
  final h = await pumpApp(tester);
  h.state.toggleWord(key: 'de.geben.v', word: 'geben', storyId: 'brot', context: 'Es gibt viele Brote.');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('tab-words')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('word-de.geben.v')), findsOneWidget);
  await tester.tap(find.byKey(const Key('practice')));
  await tester.pumpAndSettle();
  expect(tester.widget<Text>(find.byKey(const Key('fc-word'))).data, 'geben');
  await tester.tap(find.byKey(const Key('show-answer')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('fc-gloss')), findsOneWidget);
  await tester.tap(find.byKey(const Key('knew-it')));
  await tester.pumpAndSettle();
  expect(find.text('Session complete'), findsOneWidget);
  expect(h.state.words['de.geben.v']!.card.box, 1);
  await tester.tap(find.byKey(const Key('back-to-words')));
  await tester.pumpAndSettle();
  expect(find.text('All caught up!'), findsOneWidget);
}

Future<void> settingsAndReset(WidgetTester tester) async {
  final h = await pumpApp(tester);
  h.state.finishStory('brot');
  await tester.tap(find.byKey(const Key('tab-progress')));
  await tester.pumpAndSettle();
  await waitFor(tester, find.byKey(const Key('progress-list')));
  await reveal(tester, find.byKey(const Key('theme')), const Key('progress-list'));
  await tester.tap(find.byKey(const Key('theme')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dark').last);
  await tester.pumpAndSettle();
  expect(h.state.settings.theme, ThemeChoice.dark);
  expect(Theme.of(tester.element(find.byKey(const Key('theme')))).brightness, Brightness.dark);
  await reveal(tester, find.byKey(const Key('reset')), const Key('progress-list'));
  await tester.tap(find.byKey(const Key('reset')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirm-reset')));
  await tester.pumpAndSettle();
  expect(h.state.read, isEmpty);
  expect(h.state.settings.theme, ThemeChoice.system);
}

/// Every flow, by name, for both runners.
final flows = <String, Future<void> Function(WidgetTester)>{
  'library search and story of the day': libraryFilters,
  'tap a word, save it, translations, names unglossed': tapWordAndSave,
  'listening reads every sentence and stops on leave': listenThenLeave,
  'finish a story, quiz, progress': quizAndProgress,
  'practice saved words with spaced repetition': practiceWords,
  'settings: dark theme and reset': settingsAndReset,
};
