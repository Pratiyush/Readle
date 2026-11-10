import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readle/l10n/app_localizations.dart';
import 'package:readle/ui/word_sheet.dart' show boldWords;

/// UI strings live in lib/l10n/app_en.arb (gen-l10n). These tests keep it that way: every message
/// says where it appears, and no screen grows a new hardcoded English string.
void main() {
  test('every message in app_en.arb has a camelCase key and an @key description of where it appears', () {
    final arb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    final keys = [
      for (final k in arb.keys)
        if (!k.startsWith('@')) k,
    ];
    expect(keys, isNotEmpty);
    final problems = [
      for (final k in keys)
        if (!RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(k))
          '$k: not camelCase'
        else if (arb['@$k'] case {'description': final String d} when d.trim().isNotEmpty)
          ...[]
        else
          '$k: no @$k description',
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('no hardcoded user-facing strings in lib/ui (German on purpose is marked)', () {
    final files = [...Directory('lib/ui').listSync().whereType<File>().where((f) => f.path.endsWith('.dart')), File('lib/app.dart')]
      ..sort((a, b) => a.path.compareTo(b.path));
    final problems = [for (final f in files) ...hardcodedStrings(f.path, f.readAsStringSync())];
    expect(problems, isEmpty, reason: 'Move these to lib/l10n/app_en.arb, or mark German on purpose:\n${problems.join('\n')}');
  });

  test('English counts and placeholders read exactly as the old hardcoded strings did', () {
    final l = lookupAppLocalizations(const Locale('en'));
    expect([l.wordsDue(1), l.wordsDue(3)], ['1 word to review', '3 words to review']);
    expect([l.progressGoalText(1), l.progressGoalText(2)], ['Read 1 story a day.', 'Read 2 stories a day.']);
    expect(
      [
        for (final n in [1, 2, 5]) l.settingsDailyGoalOption(n),
      ],
      ['1 story', '2 stories', '5 stories'],
    );
    expect([l.updateBannerNewStories(1), l.updateBannerNewStories(4)], ['📚 1 new story to read', '📚 4 new stories to read']);
    expect(
      [l.contentCheckAvailable(1), l.contentCheckAvailable(2)],
      ['1 new story: download it from Stories', '2 new stories: download them from Stories'],
    );
    expect([l.statDayStreak(1), l.statDayStreak(9), l.statStoriesRead(1)], ['day streak', 'day streak', 'stories read']);
    expect(l.readerStoryMeta(4, 180), '4 min read · 180 words');
    expect(l.storyCardMeta(3, l.collectionFiction), '3 min · Fiction');
    expect(l.pluralDie('Brote'), 'plural: die Brote');
    expect(l.quizFinished('Das Brot'), 'You finished “Das Brot”.');
  });

  test('word-sheet notes keep both German words bold, in the order the message puts them', () {
    final l = lookupAppLocalizations(const Locale('en'));
    const bold = TextStyle(fontWeight: FontWeight.w700);
    String plain(List<InlineSpan> spans) => spans.map((s) => (s as TextSpan).text).join();
    List<String?> bolded(List<InlineSpan> spans) => [
      for (final s in spans.cast<TextSpan>())
        if (s.style == bold) s.text,
    ];
    final compound = boldWords(l.wordSheetCompound, 'Brotkorb', 'Korb', bold);
    expect(plain(compound), 'Brotkorb is a compound — this is the meaning of its last part, Korb.');
    expect(bolded(compound), ['Brotkorb', 'Korb']);
    final form = boldWords(l.wordSheetFormOf, 'ging', 'gehen', bold);
    expect(plain(form), 'ging is a form of gehen.');
    expect(bolded(form), ['ging', 'gehen']);
    expect(bolded(boldWords((a, b) => '$b ← $a', 'ging', 'gehen', bold)), ['gehen', 'ging']);
  });

  test('the guard catches the patterns it is meant to, and lets the allowed ones through', () {
    const src = '''
Text('Hello')
Text(n == 1 ? 'one story' : '\$n stories')
IconButton(tooltip: 'Close')
SnackBar(content: Text("Couldn't load."))
Text('\${a}/\$b · 🔥 99+')
Text(l.title)
Text(
  // l10n: German on purpose
  'Willkommen!',
)
Text('Richtig!') // l10n: German on purpose
label: Chip(key: Key('not-checked'), label: Text(name))
// Text('in a comment')
''';
    expect(hardcodedStrings('x.dart', src).map((p) => p.split(': ').first), ['x.dart:1', 'x.dart:2', 'x.dart:2', 'x.dart:3', 'x.dart:4']);
  });
}

/// Places where a string is shown or read out: Text's first argument (also under label:, title:,
/// SnackBar content:) and the named String arguments widgets display or announce.
final _sites = RegExp(r'\bText\(|\b(?:tooltip|message|label|semanticsLabel|hintText|eyebrow|text):\s*');
final _letter = RegExp(r'\p{L}', unicode: true);
const _germanOnPurpose = '// l10n: German on purpose';

/// `file:line: literal` for each string literal with letters at a [_sites] place, unless it is a
/// Key, or the same or previous line says `// l10n: German on purpose`. Strings that are only
/// punctuation, digits, emoji or interpolation pass.
List<String> hardcodedStrings(String path, String src) {
  final lines = src.split('\n');
  int lineOf(int offset) => '\n'.allMatches(src.substring(0, offset)).length;
  final seen = <int>{};
  final out = <String>[];
  for (final m in _sites.allMatches(src)) {
    final lineStart = src.lastIndexOf('\n', m.start) + 1;
    if (src.substring(lineStart, m.start).contains('//')) continue; // in a comment
    final literals = <(int, String)>[];
    _scan(src, m.end, literals);
    for (final (offset, text) in literals) {
      if (!seen.add(offset) || !_letter.hasMatch(text)) continue;
      if (RegExp(r'Key\(\s*$').hasMatch(src.substring(offset < 30 ? 0 : offset - 30, offset))) continue;
      final line = lineOf(offset);
      if (lines[line].contains(_germanOnPurpose) || (line > 0 && lines[line - 1].contains(_germanOnPurpose))) continue;
      out.add('$path:${line + 1}: ${lines[line].trim()}');
    }
  }
  return out;
}

bool _isIdent(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

/// Walks one expression from [i]: an argument (up to `,` or `)` at depth 0) or, when [braced], an
/// interpolation body (up to its `}`). Adds every string literal met to [out]; returns the end.
int _scan(String src, int i, List<(int, String)> out, {bool braced = false}) {
  var depth = 0;
  while (i < src.length) {
    final c = src[i];
    if (src.startsWith('//', i)) {
      final nl = src.indexOf('\n', i);
      i = nl < 0 ? src.length : nl;
      continue;
    }
    final rawStart = c == 'r' && i + 1 < src.length && (src[i + 1] == "'" || src[i + 1] == '"') && (i == 0 || !_isIdent(src[i - 1]));
    if (c == "'" || c == '"' || rawStart) {
      i = _string(src, i, out);
      continue;
    }
    if ('([{'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c)) {
      if (depth == 0) return braced ? i + 1 : i;
      depth--;
    } else if (c == ',' && depth == 0 && !braced) {
      return i;
    }
    i++;
  }
  return i;
}

/// Reads the literal at [i], adds (offset, its text without interpolations) and any literals inside
/// its interpolations to [out], and returns the offset after its closing quote.
int _string(String src, int i, List<(int, String)> out) {
  final start = i;
  final raw = src[i] == 'r';
  if (raw) i++;
  final q = src[i];
  final close = src.startsWith(q * 3, i) ? q * 3 : q;
  i += close.length;
  final text = StringBuffer();
  while (i < src.length && !src.startsWith(close, i)) {
    final c = src[i];
    if (!raw && c == r'\' && i + 1 < src.length) {
      final n = src[i + 1];
      if (n == 'u') {
        i += 2;
        i = i < src.length && src[i] == '{' ? src.indexOf('}', i) + 1 : i + 4;
      } else if (n == 'x') {
        i += 4;
      } else {
        text.write('\'"\$\\'.contains(n) ? n : ' ');
        i += 2;
      }
      continue;
    }
    if (!raw && c == r'$' && i + 1 < src.length) {
      if (src[i + 1] == '{') {
        i = _scan(src, i + 2, out, braced: true);
      } else {
        i++;
        while (i < src.length && _isIdent(src[i]) && src[i] != r'$') {
          i++;
        }
      }
      continue;
    }
    text.write(c);
    i++;
  }
  out.add((start, text.toString()));
  return i + close.length;
}
