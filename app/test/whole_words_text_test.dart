// Titles never split a German word: the font shrinks until the longest word fits a line.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readle/ui/whole_words_text.dart';

void main() {
  Future<double> sizeAt(WidgetTester tester, double width, double scale) async {
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: width, child: const WholeWordsText('Die Sonntagsruhe im Alltag', style: TextStyle(fontSize: 24)))),
      ),
    ));
    return tester.widget<Text>(find.byType(Text)).style!.fontSize!;
  }

  double wordWidth(double fontSize, double scale) {
    final p = TextPainter(
        text: TextSpan(text: 'Sonntagsruhe', style: TextStyle(fontSize: fontSize)),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(scale))
      ..layout();
    return p.width;
  }

  testWidgets('a long word that fits keeps the size', (tester) async {
    expect(await sizeAt(tester, 400, 1), 24);
  });

  testWidgets('a word wider than the line shrinks the title until it fits', (tester) async {
    final size = await sizeAt(tester, 300, 2);
    expect(size, lessThan(24));
    expect(wordWidth(size, 2), lessThanOrEqualTo(300));
  });
}
