// The finished-story share card: what it says, from the story and the quiz.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readle/content/models.dart';
import 'package:readle/l10n/app_localizations.dart';
import 'package:readle/ui/share_card.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  final story = Story.fromJson({
    'id': 'brot',
    'title': 'Brot ist hier wichtig',
    'level': 'A1',
    'collection': 'culture',
    'publishedAt': '2026-01-01',
    'teaser': '',
    'teaserEn': '',
    'words': 40,
    'minutes': 1,
    'sentences': [
      {'de': 'In Deutschland ist Brot sehr wichtig.', 'en': 'Bread is very important in Germany.', 't': []},
    ],
  });

  test('a good quiz is part of the brag; a weak one is left off the card', () {
    final good = finishedStoryCard(l, story, pct: 80, streak: 5);
    expect((good.title, good.level, good.streak, good.score), ('Brot ist hier wichtig', 'A1', '🔥 5 day streak', '80% on the quiz'));
    expect(good.quote, 'In Deutschland ist Brot sehr wichtig.');
    expect(finishedStoryCard(l, story, pct: 79, streak: 5).score, isNull);
    expect(finishedStoryCard(l, story, pct: 20, streak: 1).streak, '🔥 1 day streak');
  });

  testWidgets('the card shows no score chip without a score', (tester) async {
    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: ShareCard(finishedStoryCard(l, story, pct: 20, streak: 1))),
    );
    expect(find.textContaining('on the quiz'), findsNothing);
    expect(find.text('🔥 1 day streak'), findsOneWidget);
  });
}
