import 'package:flutter/widgets.dart';

/// A title that never splits a word. Flutter has no hyphenation, so a German compound wider than
/// the line ("Sonntagsruhe" at large text sizes) is broken anywhere and reads as two words. This
/// shrinks the font just enough for the longest word to fit on a line, and otherwise wraps
/// between words as usual.
class WholeWordsText extends StatelessWidget {
  const WholeWordsText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final base = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, c) {
        var factor = 1.0;
        if (c.hasBoundedWidth) {
          for (final word in text.split(RegExp(r'\s+'))) {
            if (word.isEmpty) continue;
            final painter = TextPainter(
              text: TextSpan(text: word, style: base),
              textDirection: direction,
              textScaler: scaler,
              maxLines: 1,
            )..layout();
            if (painter.width > c.maxWidth) {
              final fit = c.maxWidth / painter.width * 0.98;
              if (fit < factor) factor = fit;
            }
            painter.dispose();
          }
        }
        factor = factor.clamp(0.5, 1.0);
        final size = base.fontSize ?? 14;
        return Text(text, style: factor < 1 ? style.copyWith(fontSize: size * factor) : style);
      },
    );
  }
}
