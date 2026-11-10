// End-to-end flows shared by the headless widget tests (test/widget_test.dart) and the on-device
// integration test (integration_test/app_test.dart), so both always check the same behaviour.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:readle/app.dart';
import 'package:readle/config.dart' show playStoreUrl;
import 'package:readle/content/cdn/content_client.dart';
import 'package:readle/content/cdn/content_store.dart';
import 'package:readle/content/content_repository.dart';
import 'package:readle/content/layered_repository.dart';
import 'package:readle/services/ads.dart';
import 'package:readle/services/reminders.dart';
import 'package:readle/services/share.dart';
import 'package:readle/services/speech.dart';
import 'package:readle/services/word_player.dart';
import 'package:readle/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/cdn_fixture.dart';

class Harness {
  Harness(this.state, this.speech, this.player, this.reminders, this.sharer);
  final AppState state;
  final RecordingSpeech speech;
  final RecordingWordPlayer player;
  final RecordingReminders reminders;
  final RecordingSharer sharer;
}

Future<Harness> pumpApp(
  WidgetTester tester, {
  bool decodeInIsolate = false,
  bool onboarded = true,
  bool clipsWork = true,
  bool germanVoice = true,
  ContentRepository? content,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  // Every flow but the onboarding one starts past the first-launch level question.
  final state = await AppState.load(prefs)
    ..onboarded = onboarded;
  final speech = RecordingSpeech(duration: const Duration(milliseconds: 120), hasVoice: germanVoice);
  final repo = content ?? AssetContentRepository(decodeInIsolate: decodeInIsolate);
  // Load the content for real before the app's first frame (assets are real I/O).
  await tester.runAsync(() async {
    await repo.library();
    await repo.dictionary();
    await repo.story('brot');
  });
  final player = RecordingWordPlayer(works: clipsWork);
  final reminders = RecordingReminders();
  DailyReminder(state: state, reminders: reminders).start();
  final sharer = RecordingSharer();
  await tester.pumpWidget(
    ReadleApp(state: state, content: repo, speech: speech, player: player, ads: NoAds(), reminders: reminders, sharer: sharer),
  );
  await tester.pumpAndSettle();
  return Harness(state, speech, player, reminders, sharer);
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
  await reveal(tester, find.byKey(const Key('search')), const PageStorageKey('library'));
  await tester.enterText(find.byKey(const Key('search')), text);
  // "Done" on the keyboard closes it the way a user does (a bare unfocus() left the device's
  // test text input disconnected, so the next enterText never arrived).
  await tester.testTextInput.receiveAction(TextInputAction.done);
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
  // Bring the paragraph with the word on screen first (large text pushes it below the fold).
  await tester.ensureVisible(find.textContaining(word, findRichText: true).first);
  await tester.pumpAndSettle();
  await tester.tapOnText(find.textRange.ofSubstring(word).first);
  await tester.pumpAndSettle();
}

Future<void> libraryFilters(WidgetTester tester) async {
  await pumpApp(tester);
  expect(find.byKey(const Key('daily')), findsOneWidget);
  // Typed directly: on Android, closing the keyboard between two entries drops the second one.
  await tester.enterText(find.byKey(const Key('search')), 'bread');
  await tester.pumpAndSettle();
  await waitFor(tester, find.byKey(const Key('story-frisches-brot-in-der-baeckerei')));
  await tester.enterText(find.byKey(const Key('search')), 'zzzz');
  await tester.pumpAndSettle();
  await waitFor(tester, find.text('No stories match these filters.', skipOffstage: false));
}

Future<void> tapWordAndSave(WidgetTester tester) async {
  final h = await pumpApp(tester);
  await openBrot(tester);
  await tapWord(tester, 'gibt');
  expect(find.byKey(const Key('word-sheet')), findsOneWidget);
  expect(find.text('geben'), findsWidgets);
  expect(find.textContaining('to give'), findsOneWidget);
  expect(h.player.played, ['assets/content/audio/de.geben.v.mp3'], reason: 'tapping a word plays its recorded clip');
  await tester.tap(find.byKey(const Key('save-word')));
  await tester.pumpAndSettle();
  expect(find.text('✓ Saved to your words'), findsOneWidget);
  expect(h.state.words.keys, contains('de.geben.v'));

  await tester.tap(find.byTooltip('Close'));
  await tester.pumpAndSettle();
  await tapWord(tester, 'Deutschland');
  expect(find.textContaining('No dictionary entry'), findsOneWidget);
  expect(h.player.played, hasLength(1), reason: 'a name has no clip');
  expect(h.speech.spoken.last, 'Deutschland', reason: 'so the device voice says it');
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
  // Share the finished story: one 1080 × 1350 PNG card and a line with the German title.
  await tester.tap(find.byKey(const Key('share-result')));
  for (var i = 0; i < 100 && h.sharer.shared.isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(h.sharer.shared, hasLength(1));
  final card = h.sharer.shared.single;
  expect(card.png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], reason: 'a PNG');
  expect((_pngSize(card.png)), (1080, 1350));
  expect(card.text, contains('„Brot ist hier wichtig“ (A1)'));
  expect(card.fileName, endsWith('.png'));
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
  // Without a content client (CONTENT_CDN_ENABLED off, the default) there is nothing to check.
  expect(find.byKey(const Key('content-check'), skipOffstage: false), findsNothing);
  await reveal(tester, find.byKey(const Key('theme')), const Key('progress-list'));
  await tester.tap(find.byKey(const Key('theme')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dark').last);
  await tester.pumpAndSettle();
  expect(h.state.settings.theme, ThemeChoice.dark);
  expect(Theme.of(tester.element(find.byKey(const Key('theme')))).brightness, Brightness.dark);
  // Story level: the same choice as the library's level chips, so the list and story of the day follow it.
  await reveal(tester, find.byKey(const Key('story-level')), const Key('progress-list'));
  await tester.tap(find.byKey(const Key('story-level')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('A2 · elementary').last);
  await tester.pumpAndSettle();
  expect(h.state.settings.level, 'A2');
  await reveal(tester, find.byKey(const Key('reset')), const Key('progress-list'));
  await tester.tap(find.byKey(const Key('reset')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirm-reset')));
  await tester.pumpAndSettle();
  expect(h.state.read, isEmpty);
  expect(h.state.settings.theme, ThemeChoice.system);
  expect(h.state.settings.level, 'all');
}

Future<void> continueReading(WidgetTester tester) async {
  final h = await pumpApp(tester);
  expect(find.byKey(const Key('continue-card')), findsNothing, reason: 'nothing to continue on a fresh install');
  await openBrot(tester);
  await tester.drag(find.byKey(const Key('reader-list')), const Offset(0, -400));
  await tester.pumpAndSettle();
  expect(h.state.progress['brot'], greaterThan(0), reason: 'scrolling records how far you read');
  await tester.tap(find.byKey(const Key('reader-back')));
  await tester.pumpAndSettle();
  await waitFor(tester, find.byKey(const Key('continue-card')));
  expect(find.descendant(of: find.byKey(const Key('continue-card')), matching: find.text('Brot ist hier wichtig')), findsOneWidget);
  await tester.tap(find.byKey(const Key('continue-card')));
  await tester.pumpAndSettle();
  await waitFor(tester, find.byKey(const Key('reader-list')));
  final position = tester
      .state<ScrollableState>(find.descendant(of: find.byKey(const Key('reader-list')), matching: find.byType(Scrollable)).first)
      .position;
  expect(position.pixels, greaterThan(0), reason: 'reopens where you left off');
  h.state.finishStory('brot');
  await tester.tap(find.byKey(const Key('reader-back')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('continue-card')), findsNothing, reason: 'a finished story is not offered again');
}

Future<void> firstRunWordTip(WidgetTester tester) async {
  final h = await pumpApp(tester);
  await openBrot(tester);
  expect(find.byKey(const Key('word-tip')), findsOneWidget, reason: 'first run: the one thing to learn');
  await tapWord(tester, 'gibt');
  await tester.tap(find.byTooltip('Close'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('word-tip')), findsNothing);
  expect(h.state.wordTipSeen, isTrue);
}

/// New stories from the content CDN: the library offers them (never downloads by itself), one tap
/// installs them, and the new story opens with tappable words, linked on the device by the
/// builder's own rules. The CDN is the in-memory fixture, so this runs the same on a device.
/// The app with a content client on the in-memory CDN fixture. [checkFirst]: the daily check has
/// run before the first frame; otherwise the caller runs it.
Future<(AppState, ContentClient, LayeredContentRepository)> pumpWithCdn(
  WidgetTester tester, {
  bool checkFirst = true,
  bool onWifi = false,
  int minClient = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  final state = await AppState.load(prefs)
    ..onboarded = true;
  late Directory root;
  late ContentClient updates;
  late LayeredContentRepository content;
  await tester.runAsync(() async {
    root = await Directory.systemTemp.createTemp('readle-flow');
    final image = (await rootBundle.load('assets/content/images/brot.webp')).buffer.asUint8List();
    final cdn = CdnFixture(image: image, minClient: minClient);
    final store = ContentStore(root);
    final bundled = AssetContentRepository();
    content = LayeredContentRepository(bundled: bundled, store: store, cdn: Uri.parse('https://cdn.test/'));
    await content.reload();
    await content.dictionary();
    updates = ContentClient(
      fetcher: cdn.fetcher,
      store: store,
      prefs: prefs,
      bundledIds: {for (final s in await bundled.library()) s.id},
      base: Uri.parse('https://cdn.test/'),
      autoUpdate: () => state.settings.autoUpdateOnWifi,
      unmetered: () async => onWifi,
      afterInstall: content.reload,
    );
    if (checkFirst) await updates.check();
  });
  addTearDown(() => root.deleteSync(recursive: true));
  await tester.pumpWidget(
    ReadleApp(state: state, content: content, speech: RecordingSpeech(), player: RecordingWordPlayer(), ads: NoAds(), updates: updates),
  );
  await tester.pumpAndSettle();
  return (state, updates, content);
}

Future<void> contentUpdate(WidgetTester tester) async {
  final (_, updates, content) = await pumpWithCdn(tester);
  expect(find.text('📚 1 new story to read'), findsOneWidget);
  expect(find.text(newTitle), findsNothing, reason: 'nothing downloads before the tap');

  await tester.runAsync(() async {
    await tester.tap(find.byKey(const Key('content-update-button')));
    for (var i = 0; i < 200 && (updates.busy || updates.installs == 0); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(updates.installs, 1);
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    ); // let the store settle (the client reloaded the content before it notified)
    await content.story(newSlug); // read the file now, outside the fake clock
  });
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('content-update')), findsNothing);
  await search(tester, 'Bäcker');
  await tester.tap(find.text(newTitle).last);
  await tester.pumpAndSettle();
  await waitFor(tester, find.byKey(const Key('reader-list')));
  await tapWord(tester, 'gibt');
  expect(find.byKey(const Key('headword')), findsOneWidget);
  await tester.tap(find.byTooltip('Close'));
  await tester.pumpAndSettle();
  await tapWord(tester, 'Abbuchung');
  expect(find.textContaining('Abbuchung'), findsWidgets, reason: 'a word only lexicon.json knows');
}

/// Listen from here: after checking a sentence's meaning, hear it read, then the rest of the story.
Future<void> listenFromHere(WidgetTester tester) async {
  final h = await pumpApp(tester);
  await openBrot(tester);
  await tester.tap(find.byKey(const Key('show-all-translations')));
  await tester.pumpAndSettle();
  await reveal(tester, find.byKey(const Key('listen-from-4')), const Key('reader-list'));
  await tester.tap(find.byKey(const Key('listen-from-4')));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  expect(h.speech.spoken.first, 'Das nennt man Abendbrot.', reason: 'starts at the chosen sentence');
  expect(h.speech.spoken.length, 4, reason: 'then reads on to the end (sentences 5-8)');
  expect(find.byTooltip('Listen'), findsOneWidget, reason: 'done: the app bar offers Listen again');
}

/// Every flow, by name, for both runners.
/// First launch: the level question. "Not sure? Start at A1" is every level in order, so the story
/// of the day is an A1 story; picking a level shows that level's stories.
Future<void> onboarding(WidgetTester tester) async {
  var h = await pumpApp(tester, onboarded: false);
  await waitFor(tester, find.byKey(const Key('onboarding')));
  expect(find.byKey(const Key('tab-stories')), findsNothing, reason: 'the question comes before the app');
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final key in ['onboard-A1', 'onboard-B2', 'onboard-not-sure']) {
    expect(tester.getRect(find.byKey(Key(key))).bottom, lessThanOrEqualTo(screen.height), reason: '$key on screen without scrolling');
  }
  await tester.tap(find.byKey(const Key('onboard-not-sure')));
  await tester.pumpAndSettle();
  final daily = find.byKey(const Key('daily'));
  await waitFor(tester, daily);
  expect(h.state.onboarded, isTrue);
  expect(h.state.settings.level, 'all');
  expect(
    find.descendant(of: daily, matching: find.text('A1')),
    findsOneWidget,
    reason: 'all levels start at A1',
  );

  h = await pumpApp(tester, onboarded: false);
  await waitFor(tester, find.byKey(const Key('onboard-B1')));
  await tester.tap(find.byKey(const Key('onboard-B1')));
  await tester.pumpAndSettle();
  await waitFor(tester, daily);
  expect(h.state.settings.level, 'B1');
  expect(find.descendant(of: daily, matching: find.text('B1')), findsOneWidget);
}

Future<void> dailyReminder(WidgetTester tester) async {
  final h = await pumpApp(tester);
  await tester.tap(find.byKey(const Key('tab-progress')));
  await tester.pumpAndSettle();
  await waitFor(tester, find.byKey(const Key('progress-list')));
  final toggle = find.byKey(const Key('reminder'));
  await reveal(tester, toggle, const Key('progress-list'));
  expect(tester.widget<SwitchListTile>(toggle).value, isFalse, reason: 'off by default');
  expect(find.byKey(const Key('reminder-time')), findsNothing);
  expect(h.reminders.permissionAsks, 0, reason: 'never asked before the learner turns it on');

  // Permission denied: the switch stays off and says where to allow it.
  h.reminders.granted = false;
  await tester.tap(toggle);
  await tester.pumpAndSettle();
  expect(h.state.settings.reminder, isFalse);
  expect(find.byKey(const Key('reminder-denied')), findsOneWidget);
  expect(h.reminders.pending, isEmpty);
  ScaffoldMessenger.of(tester.element(toggle)).removeCurrentSnackBar();
  await tester.pumpAndSettle();

  h.reminders.granted = true;
  await tester.tap(toggle);
  await tester.pumpAndSettle();
  expect(h.state.settings.reminder, isTrue);
  expect(h.reminders.pending, hasLength(reminderDays));
  expect(h.reminders.pending.map((t) => (t.hour, t.minute)).toSet(), {(19, 0)});

  // A new time, typed into the picker (12- or 24-hour, as the device shows times).
  final time = find.byKey(const Key('reminder-time'));
  await reveal(tester, time, const Key('progress-list'));
  String shown(int h, int m) => TimeOfDay(hour: h, minute: m).format(tester.element(time));
  expect(find.descendant(of: time, matching: find.text(shown(19, 0))), findsOneWidget);
  await tester.tap(time);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Switch to text input mode'));
  await tester.pumpAndSettle();
  final fields = find.descendant(of: find.byType(TimePickerDialog), matching: find.byType(TextField));
  await tester.enterText(fields.first, '07');
  await tester.enterText(fields.last, '30');
  if (find.text('AM').evaluate().isNotEmpty) await tester.tap(find.text('AM'));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  expect(h.state.settings.reminderMinutes, 7 * 60 + 30);
  expect(h.reminders.pending.map((t) => (t.hour, t.minute)).toSet(), {(7, 30)});
  expect(find.descendant(of: time, matching: find.text(shown(7, 30))), findsOneWidget);

  await tester.tap(toggle);
  await tester.pumpAndSettle();
  expect(h.state.settings.reminder, isFalse);
  expect(h.reminders.pending, isEmpty);
  expect(find.byKey(const Key('reminder-time')), findsNothing);
}

/// New stories on Wi-Fi, on their own, once the learner allowed it in Settings: no banner, no tap,
/// and the library that is already on screen shows them.
Future<void> contentOnWifi(WidgetTester tester) async {
  final (state, updates, content) = await pumpWithCdn(tester, checkFirst: false, onWifi: true);
  await tester.tap(find.byKey(const Key('tab-progress')));
  await tester.pumpAndSettle();
  final allow = find.byKey(const Key('auto-update-wifi'));
  await reveal(tester, allow, const Key('progress-list'));
  expect(tester.widget<SwitchListTile>(allow).value, isFalse, reason: 'asks first, by default');
  await tester.tap(allow);
  await tester.pumpAndSettle();
  expect(state.settings.autoUpdateOnWifi, isTrue);
  await tester.tap(find.byKey(const Key('tab-stories')));
  await tester.pumpAndSettle();
  expect(find.text(newTitle, skipOffstage: false), findsNothing);

  await tester.runAsync(() async {
    await updates.check(); // the next app open's daily check
    for (var i = 0; i < 100 && updates.installs == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(updates.installs, 1, reason: 'installed without a tap');
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    ); // let the store settle (the client reloaded the content before it notified)
  });
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('content-update')), findsNothing, reason: 'nothing left to offer');
  await search(tester, 'Bäcker');
  expect(find.text(newTitle), findsWidgets);
}

/// A CDN that needs a newer app: the library says so and links to the store; reading goes on.
Future<void> contentAppTooOld(WidgetTester tester) async {
  final launcher = RecordingLauncher();
  final before = UrlLauncherPlatform.instance;
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = before);
  await pumpWithCdn(tester, minClient: 99);
  expect(find.text('Update the app to get new stories.'), findsOneWidget);
  expect(find.byKey(const Key('content-update-button')), findsNothing);
  await tester.tap(find.byKey(const Key('update-app')));
  await tester.pumpAndSettle();
  expect(launcher.launched, [playStoreUrl]);
  await openBrot(tester);
  expect(find.byKey(const Key('reader-list')), findsOneWidget, reason: 'installed content keeps working');
}

/// Records the URLs the app opens instead of leaving it.
class RecordingLauncher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  final launched = <String>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }

  @override
  Future<bool> canLaunch(String url) async => true;
}

final flows = <String, Future<void> Function(WidgetTester)>{
  'first launch: pick a level, or not sure → start at A1': onboarding,
  'library search and story of the day': libraryFilters,
  'tap a word, save it, translations, names unglossed': tapWordAndSave,
  'listening reads every sentence and stops on leave': listenThenLeave,
  'listen from here: one sentence, then on to the end': listenFromHere,
  'finish a story, quiz, progress': quizAndProgress,
  'practice saved words with spaced repetition': practiceWords,
  'settings: dark theme and reset': settingsAndReset,
  'continue reading: card, then back to the same place': continueReading,
  'first run: the tap-a-word tip until the first tap': firstRunWordTip,
  'new stories from the CDN: offer, install, read': contentUpdate,
  'daily reminder: off by default, on asks first, a new time, off': dailyReminder,
  'new stories on Wi-Fi, on their own once allowed': contentOnWifi,
  'a CDN that needs a newer app: say so, link to the store': contentAppTooOld,
};

/// Width and height from a PNG's IHDR chunk.
(int, int) _pngSize(List<int> png) {
  int u32(int o) => (png[o] << 24) | (png[o + 1] << 16) | (png[o + 2] << 8) | png[o + 3];
  return (u32(16), u32(20));
}
