// Owner rule: no Claude colours (coral, salmon, peach, pink, terracotta, Claude's cream paper).
// Same bands as German/tools/colour-audit.mjs and src/palette.test.ts. One flag-red, errors only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readle/ui/theme.dart';

String? claudeish(Color c) {
  final hsl = HSLColor.fromColor(c);
  final (h, s, l) = (hsl.hue, hsl.saturation, hsl.lightness);
  if (s == 0) return null;
  if ((h >= 345 || h <= 32) && s >= 0.35 && l >= 0.5 && l <= 0.93) return 'coral/salmon/peach';
  if (h >= 5 && h <= 32 && s >= 0.35 && s <= 0.8 && l >= 0.38 && l < 0.5) return 'terracotta';
  if (h >= 300 && h < 345 && s >= 0.3 && l >= 0.45 && l <= 0.93) return 'pink';
  if (h >= 20 && h <= 42 && s >= 0.2 && l >= 0.85) return 'cream';
  return null;
}

void main() {
  test('the band check itself', () {
    expect(claudeish(const Color(0xFFF87171)), 'coral/salmon/peach');
    expect(claudeish(const Color(0xFFFBF8F3)), 'cream');
    expect(claudeish(const Color(0xFFB91C1C)), isNull, reason: 'the allowed flag-red');
  });

  for (final b in Brightness.values) {
    test('${b.name} theme: no Claude colour anywhere in it', () {
      final t = buildTheme(b);
      final p = t.extension<Palette>()!;
      final s = t.colorScheme;
      final colours = <String, Color>{
        'scaffold': t.scaffoldBackgroundColor,
        'appBar': t.appBarTheme.backgroundColor!,
        'surface2': p.surface2,
        'muted': p.muted,
        'line': p.line,
        'accentSoft': p.accentSoft,
        'saved': p.saved,
        'good': p.good,
        'goodSoft': p.goodSoft,
        'bad': p.bad,
        'badSoft': p.badSoft,
        'onBad': p.onBad,
        'danger': p.danger,
        'primary': s.primary,
        'secondary': s.secondary,
        'tertiary': s.tertiary,
        'error': s.error,
        'errorContainer': s.errorContainer,
        'surface': s.surface,
        'onSurface': s.onSurface,
        'badge': t.badgeTheme.backgroundColor!,
        for (final e in levelColors.entries) 'level ${e.key}': e.value,
      };
      final hits = {
        for (final e in colours.entries)
          if (claudeish(e.value) case final why?) e.key: '$why ${e.value}',
      };
      expect(hits, isEmpty);
    });
  }
}
