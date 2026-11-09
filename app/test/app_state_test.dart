import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:readle/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  var today = '2026-11-08';

  Future<AppState> fresh([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return AppState.load(await SharedPreferences.getInstance(), today: () => today);
  }

  setUp(() => today = '2026-11-08');

  test('reads progress saved by the web app (same schema)', () async {
    final web = {
      'version': 1,
      'read': {'brot': '2026-11-07'},
      'progress': {},
      'quiz': {'brot': 0.8},
      'words': {
        'de.geben.v': {
          'key': 'de.geben.v',
          'word': 'geben',
          'storyId': 'brot',
          'context': 'Es gibt…',
          'added': '2026-11-07',
          'card': {'box': 1, 'due': '2026-11-08'},
        },
      },
      'activeDays': ['2026-11-07'],
      'settings': {'level': 'A1', 'fontScale': 1.15, 'theme': 'dark', 'dailyGoal': 2, 'speechRate': 0.7},
    };
    final s = await fresh({AppState.storageKey: jsonEncode(web)});
    expect(s.read['brot'], '2026-11-07');
    expect(s.quiz['brot'], 0.8);
    expect(s.dueCount, 1);
    expect(s.streakDays, 1);
    expect((s.settings.level, s.settings.theme, s.settings.dailyGoal), ('A1', ThemeChoice.dark, 2));
  });

  test('corrupt storage starts fresh instead of crashing', () async {
    final s = await fresh({AppState.storageKey: '{not json'});
    expect(s.read, isEmpty);
  });

  test('finishing a story keeps the first day and persists', () async {
    final s = await fresh();
    s.finishStory('brot');
    today = '2026-11-09';
    s.finishStory('brot');
    expect(s.read['brot'], '2026-11-08');
    expect(s.activeDays, ['2026-11-08', '2026-11-09']);
    final again = await AppState.load(await SharedPreferences.getInstance(), today: () => today);
    expect(again.read['brot'], '2026-11-08');
  });

  test('saving, reviewing and removing a word', () async {
    final s = await fresh();
    s.toggleWord(key: 'de.haus.n', word: 'Haus', storyId: 'x', context: 'Das Haus ist alt.');
    expect(s.dueCount, 1);
    s.reviewWord('de.haus.n', correct: true);
    expect(s.words['de.haus.n']!.card.due, '2026-11-09');
    expect(s.dueCount, 0);
    s.toggleWord(key: 'de.haus.n', word: 'Haus', storyId: 'x', context: '');
    expect(s.words, isEmpty);
  });

  test('keeps the best quiz score; reset clears everything', () async {
    final s = await fresh();
    s.recordQuiz('x', 0.8);
    s.recordQuiz('x', 0.4);
    expect(s.quiz['x'], 0.8);
    s.reset();
    expect(s.quiz, isEmpty);
  });

  group('first-launch level question', () {
    test('a fresh install asks; an install from before the question does not', () async {
      expect((await fresh()).onboarded, isFalse);
      final old = await fresh({
        'readle.state.v1': jsonEncode({
          'version': 1,
          'settings': {'level': 'A2'},
        }),
      });
      expect(old.onboarded, isTrue);
      expect(old.settings.level, 'A2');
    });

    test('the answer sets the story level and is remembered', () async {
      final s = await fresh();
      s.finishOnboarding('B1');
      expect(s.settings.level, 'B1');
      final again = await AppState.load(await SharedPreferences.getInstance(), today: () => today);
      expect(again.onboarded, isTrue);
      expect(again.settings.level, 'B1');
    });
  });
}
