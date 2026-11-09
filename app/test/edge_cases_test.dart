// Edge and boundary cases from German/docs/e2e-standard.md that the flows don't already cover
// (docs/test-plan.md maps every case to its test). The fast gate runs this in Europe/Berlin.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readle/content/cdn/content_client.dart';
import 'package:readle/content/content_repository.dart';
import 'package:readle/content/models.dart';
import 'package:readle/logic/quiz.dart' show praise;
import 'package:readle/logic/srs.dart';
import 'package:readle/state/app_state.dart';
import 'package:readle/ui/whole_words_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flows.dart';

/// The bundled library plus one newest story whose picture is missing from the bundle.
class _MissingPicture extends AssetContentRepository {
  @override
  Future<List<StoryMeta>> library() async {
    final real = await super.library();
    final first = real.first;
    return [
      StoryMeta(
        id: first.id,
        title: 'Ohne Bild',
        level: 'A1',
        collection: 'fiction',
        publishedAt: '2099-01-01',
        image: 'images/does-not-exist.webp',
        teaser: first.teaser,
        teaserEn: first.teaserEn,
        words: 0,
        minutes: 0,
      ),
      ...real.skip(1),
    ];
  }
}

void main() {
  group('time (run in Europe/Berlin)', () {
    test('DST switches: calendar days, never 23 or 25 hours', () {
      expect(addDays('2026-03-28', 1), '2026-03-29');
      expect(addDays('2026-03-29', 1), '2026-03-30'); // clocks go forward that night
      expect(addDays('2026-10-25', 1), '2026-10-26'); // clocks go back that night
      expect(addDays('2026-10-26', -1), '2026-10-25');
      expect(streak(['2026-03-28', '2026-03-29', '2026-03-30'], '2026-03-30'), 3);
      expect(streak(['2026-10-24', '2026-10-25', '2026-10-26'], '2026-10-26'), 3);
    });

    test('leap day and year end', () {
      expect(addDays('2028-02-28', 1), '2028-02-29');
      expect(addDays('2028-02-29', 1), '2028-03-01');
      expect(addDays('2027-02-28', 1), '2027-03-01');
      expect(addDays('2026-12-31', 1), '2027-01-01');
      expect(streak(['2028-02-28', '2028-02-29', '2028-03-01'], '2028-03-01'), 3);
    });

    test('midnight: 23:59:59 is still today, 00:00 is tomorrow', () {
      expect(dayKey(DateTime(2026, 11, 9, 23, 59, 59)), '2026-11-09');
      expect(dayKey(DateTime(2026, 11, 10)), '2026-11-10');
    });

    test('a review due today stays due after midnight; a missed day breaks the streak', () {
      expect(SrsCard(box: 1, due: '2026-11-09').isDue('2026-11-10'), isTrue);
      expect(streak(['2026-11-07', '2026-11-08'], '2026-11-10'), 0);
    });
  });

  group('numbers at the edges', () {
    test('quiz praise at 0, 49, 50, 79, 80 and 100 %', () {
      expect(
        [
          for (final p in [0, 49, 50, 79, 80, 100]) praise(p).$2,
        ],
        ['Weiter so!', 'Weiter so!', 'Nicht schlecht!', 'Nicht schlecht!', 'Gut gemacht!', 'Gut gemacht!'],
      );
    });

    test('a downloaded story of 0 or 1 words still reads as 1 min', () {
      for (final de in ['', 'Hallo.']) {
        final meta = ContentClient.storyMeta(
          {
            'id': 'de.story.x',
            'title': 'X',
            'cefr': 'A1',
            'collection': 'fiction',
            'published_at': '2099-01-01',
            'sentences': [
              {'de': de, 'en': ''},
            ],
          },
          'x',
          null,
        );
        expect(meta['minutes'], 1, reason: '"$de"');
      }
    });

    testWidgets('the Words badge: 99 due shows 99, 100 shows 99+', (tester) async {
      final h = await pumpApp(tester);
      for (var i = 0; i < 99; i++) {
        h.state.toggleWord(key: 'k$i', word: 'Wort$i', storyId: 'brot', context: 'x');
      }
      await tester.pumpAndSettle();
      expect(find.text('99'), findsWidgets);
      h.state.toggleWord(key: 'k99', word: 'Wort99', storyId: 'brot', context: 'x');
      await tester.pumpAndSettle();
      expect(find.text('99+'), findsWidgets);
    });
  });

  group('saved state', () {
    Future<AppState> load(String raw) async {
      SharedPreferences.setMockInitialValues({AppState.storageKey: raw});
      return AppState.load(await SharedPreferences.getInstance());
    }

    test('corrupt or truncated JSON starts fresh instead of crashing', () async {
      for (final raw in ['{not json', '{"read": {"brot": "2026-11-0', '[]', 'null']) {
        final s = await load(raw);
        expect(s.read, isEmpty, reason: raw);
        expect(s.settings.level, 'all', reason: raw);
      }
    });

    test('a field of the wrong type does not take the rest down with it', () async {
      final s = await load(
        jsonEncode({
          'read': {'brot': '2026-11-08'},
          'progress': {'brot': 'three', 'kaffee': 4},
          'words': {
            'de.geben.v': {
              'key': 'de.geben.v',
              'word': 'geben',
              'storyId': 'brot',
              'context': 'x',
              'added': '2026-11-08',
              'card': {'box': 1, 'due': '2026-11-09'},
            },
            'broken': 'not a word',
          },
          'activeDays': ['2026-11-08', 7],
          'settings': {'level': 'B1', 'fontScale': 'big'},
        }),
      );
      expect(s.read, {'brot': '2026-11-08'});
      expect(s.progress, {'kaffee': 4}, reason: 'only the bad entry is dropped');
      expect(s.words.keys, ['de.geben.v']);
      expect(s.activeDays, ['2026-11-08']);
      expect(s.settings.level, 'B1');
      expect(s.settings.fontScale, 1.0, reason: 'a bad setting falls back alone');
    });
  });

  group('audio and pictures', () {
    testWidgets('a clip that fails to play falls back to the device voice', (tester) async {
      final h = await pumpApp(tester, clipsWork: false);
      await openBrot(tester);
      await tapWord(tester, 'gibt');
      expect(h.player.played, isNotEmpty, reason: 'the clip was tried first');
      expect(h.speech.spoken, contains('geben'));
    });

    testWidgets('no German voice on the device: no Listen, no Listen from here', (tester) async {
      await pumpApp(tester, germanVoice: false);
      await openBrot(tester);
      await tester.tap(find.byKey(const Key('show-all-translations')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('listen')), findsNothing);
      expect(find.byTooltip('Listen from here'), findsNothing);
    });

    testWidgets('a story whose picture is missing still shows, without an error', (tester) async {
      await pumpApp(tester, content: _MissingPicture());
      await waitFor(tester, find.text('Ohne Bild', skipOffstage: false));
      expect(tester.takeException(), isNull);
    });
  });

  group('German text', () {
    testWidgets('a 45-letter compound at 320 px and 200 % text: no overflow, never below half size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const word = 'Donaudampfschifffahrtsgesellschaftskapitänsmütze';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 288, child: WholeWordsText('Die $word', style: TextStyle(fontSize: 30))),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.fontSize, greaterThanOrEqualTo(15));
    });
  });
}
