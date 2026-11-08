// Small phone + 200 % system text on every screen (no overflow), and Flutter's accessibility
// guidelines (tap targets, labels, contrast) on the screens built from standard controls.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readle/state/app_state.dart';

import 'flows.dart';

void main() {
  testWidgets('320×640 at 200 % text: every screen lays out', (tester) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final h = await pumpApp(tester);
    h.state.toggleWord(key: 'de.geben.v', word: 'geben', storyId: 'brot', context: 'Es gibt viele Brote.');
    h.state.finishStory('brot');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'library');
    await openBrot(tester);
    expect(tester.takeException(), isNull, reason: 'reader');
    await tapWord(tester, 'gibt');
    expect(tester.takeException(), isNull, reason: 'word sheet');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('finish')), const Key('reader-list'));
    await tester.tap(find.byKey(const Key('finish')));
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const Key('quiz-prompt')));
    expect(tester.takeException(), isNull, reason: 'quiz');
    await tester.tap(find.byTooltip('Close quiz'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'back from quiz');
    for (final tab in ['tab-words', 'tab-progress', 'tab-stories']) {
      await tester.tap(find.byKey(Key(tab)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
    final error = tester.takeException();
    expect(error, isNull, reason: error is FlutterError ? error.toStringDeep() : '$error');
  });

  testWidgets('library, words and progress meet the tap-target, label and contrast guidelines', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    final h = await pumpApp(tester);
    h.state.toggleWord(key: 'de.geben.v', word: 'geben', storyId: 'brot', context: 'Es gibt viele Brote.');
    await tester.pumpAndSettle();
    for (final tab in ['tab-stories', 'tab-words', 'tab-progress']) {
      await tester.tap(find.byKey(Key(tab)));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: tab);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline), reason: tab);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: tab);
      await expectLater(tester, meetsGuideline(textContrastGuideline), reason: tab);
    }
    handle.dispose();
  });

  testWidgets('dark theme: every tab, the reader and the word sheet meet the contrast guideline', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    final h = await pumpApp(tester);
    h.state.updateSettings(h.state.settings.copyWith(theme: ThemeChoice.dark));
    h.state.toggleWord(key: 'de.geben.v', word: 'geben', storyId: 'brot', context: 'Es gibt viele Brote.');
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byKey(const Key('tab-stories')))).brightness, Brightness.dark);
    for (final tab in ['tab-stories', 'tab-words', 'tab-progress']) {
      await tester.tap(find.byKey(Key(tab)));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline), reason: 'dark $tab');
    }
    await tester.tap(find.byKey(const Key('tab-stories')));
    await tester.pumpAndSettle();
    await openBrot(tester);
    await expectLater(tester, meetsGuideline(textContrastGuideline), reason: 'dark reader');
    await tapWord(tester, 'gibt');
    await expectLater(tester, meetsGuideline(textContrastGuideline), reason: 'dark word sheet');
    handle.dispose();
  });
}
