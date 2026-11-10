// Haptics on success (better loop: Feel): a light tap for a right quiz answer, a medium one for
// a story quiz finished at 80 % or more, a selection click for "Knew it" in practice. Wrong
// answers stay silent. The system's own haptics setting still decides whether anything is felt.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flows.dart';

void main() {
  late List<String> felt;

  setUp(() {
    felt = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') felt.add((call.arguments as String).replaceFirst('HapticFeedbackType.', ''));
      return null;
    });
  });

  Future<void> toQuiz(WidgetTester tester) async {
    await pumpApp(tester);
    await openBrot(tester);
    await reveal(tester, find.byKey(const Key('finish')), const Key('reader-list'));
    await tester.tap(find.byKey(const Key('finish')));
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const Key('option-0')));
    felt.clear();
  }

  testWidgets('every answer right: a light tap each, then a medium one for the finished story', (tester) async {
    await toQuiz(tester);
    var questions = 0;
    while (find.byKey(const Key('correct-option')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('correct-option')));
      await tester.pumpAndSettle();
      questions++;
      expect(felt.last, 'lightImpact');
      await tester.tap(find.byKey(const Key('continue')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('result-headline')), findsOneWidget);
    expect(felt, [...List.filled(questions, 'lightImpact'), 'mediumImpact']);
  });

  testWidgets('a wrong answer is silent', (tester) async {
    await toQuiz(tester);
    final right = tester.widget<KeyedSubtree>(find.byKey(const Key('correct-option')));
    final wrong = find
        .byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('option-'))
        .evaluate()
        .firstWhere((e) => e.findAncestorWidgetOfExactType<KeyedSubtree>() != right);
    await tester.tap(find.byWidget(wrong.widget));
    await tester.pumpAndSettle();
    expect(felt, isEmpty);
  });

  testWidgets('practice: "Knew it" clicks', (tester) async {
    final h = await pumpApp(tester);
    h.state.toggleWord(key: 'de.geben.v', word: 'geben', storyId: 'brot', context: 'Es gibt viele Brote.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-words')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('practice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-answer')));
    await tester.pumpAndSettle();
    felt.clear();
    await tester.tap(find.byKey(const Key('knew-it')));
    await tester.pumpAndSettle();
    expect(felt, ['selectionClick']);
  });
}
