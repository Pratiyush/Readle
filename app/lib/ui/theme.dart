import 'package:flutter/material.dart';

/// Colours shared with the web app (src/styles.css), so both read as one product.
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.surface2,
    required this.muted,
    required this.line,
    required this.accentSoft,
    required this.saved,
    required this.good,
    required this.goodSoft,
    required this.bad,
    required this.badSoft,
    required this.onBad,
    required this.danger,
  });

  /// [bad] is "not quite" (a wrong answer, "Didn't know"): gold, never salmon or coral (owner rule:
  /// no Claude colours). [danger] is the one deep flag-red, for destructive actions only, always
  /// as a fill with white text: a red light enough to read as text on dark is pink.
  final Color surface2, muted, line, accentSoft, saved, good, goodSoft, bad, badSoft, onBad, danger;

  static const light = Palette(
    surface2: Color(0xFFF0F4F2),
    muted: Color(0xFF6B6F76),
    line: Color(0xFFDCE4E1),
    accentSoft: Color(0xFFD8EFEC),
    saved: Color(0xFFFFF1BF),
    good: Color(0xFF15803D),
    goodSoft: Color(0xFFDCFCE7),
    bad: Color(0xFF7A5B00),
    badSoft: Color(0xFFFEF3C7),
    onBad: Colors.white,
    danger: Color(0xFFB91C1C),
  );

  static const dark = Palette(
    surface2: Color(0xFF262B30),
    muted: Color(0xFF9AA0A6),
    line: Color(0xFF30363C),
    accentSoft: Color(0xFF123B37),
    saved: Color(0xFF4A3D12),
    good: Color(0xFF4ADE80),
    goodSoft: Color(0xFF14321F),
    bad: Color(0xFFFACC15),
    badSoft: Color(0xFF3B2F04),
    onBad: Color(0xFF1F1A03),
    danger: Color(0xFFB91C1C),
  );

  static Palette of(BuildContext context) => Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < 0.5 ? this : (other as Palette? ?? this);
}

const levelColors = {
  'A1': Color(0xFF15803D),
  'A2': Color(0xFF0F766E),
  'B1': Color(0xFF2563EB),
  'B2': Color(0xFF7C3AED),
  'C1': Color(0xFF475569),
};

/// The story text face: a book serif where the platform has one.
const serif = 'Georgia';
const serifFallback = ['Iowan Old Style', 'Palatino', 'Noto Serif', 'serif'];

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final accent = dark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E);
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E), brightness: b).copyWith(
    primary: accent,
    onPrimary: dark ? const Color(0xFF0B1F1D) : Colors.white,
    surface: dark ? const Color(0xFF1D2125) : Colors.white,
    onSurface: dark ? const Color(0xFFE9E6E1) : const Color(0xFF1F2328),
    // Material's default error colours are pinks and salmons: pin the one flag-red in both themes,
    // and give error containers a neutral panel with red text.
    error: const Color(0xFFB91C1C),
    onError: Colors.white,
    errorContainer: dark ? const Color(0xFF262B30) : const Color(0xFFF0F4F2),
    onErrorContainer: dark ? Colors.white : const Color(0xFFB91C1C),
  );
  const paper = Color(0xFFF6F8F7); // faint teal-grey, not Claude's cream
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF14171A) : paper,
    extensions: [dark ? Palette.dark : Palette.light],
    appBarTheme: AppBarTheme(backgroundColor: dark ? const Color(0xFF14171A) : paper, surfaceTintColor: Colors.transparent, elevation: 0),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    // The due-words badge is news, not an error: accent, not red.
    badgeTheme: BadgeThemeData(backgroundColor: accent, textColor: scheme.onPrimary),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class LevelBadge extends StatelessWidget {
  const LevelBadge(this.level, {super.key});
  final String level;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: levelColors[level] ?? Colors.grey, borderRadius: BorderRadius.circular(6)),
    child: Text(
      level,
      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}
