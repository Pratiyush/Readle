import 'package:flutter_test/flutter_test.dart';
import 'package:readle/logic/srs.dart';

void main() {
  group('dates', () {
    test('addDays crosses months and years', () {
      expect(addDays('2026-12-31', 1), '2027-01-01');
      expect(addDays('2026-03-01', -1), '2026-02-28');
    });
    test('dayKey is the local calendar day', () {
      expect(dayKey(DateTime(2026, 11, 8, 23, 59)), '2026-11-08');
    });
  });

  group('streak', () {
    test('counts consecutive days ending today', () => expect(streak(['2026-10-15', '2026-10-16', '2026-10-17'], '2026-10-17'), 3));
    test("keeps yesterday's streak alive", () => expect(streak(['2026-10-15', '2026-10-16'], '2026-10-17'), 2));
    test('resets after a missed day', () => expect(streak(['2026-10-14', '2026-10-15'], '2026-10-17'), 0));
  });

  group('Leitner boxes', () {
    test('a right answer moves the card up and schedules it out', () {
      var c = SrsCard.fresh('2026-11-08');
      c = c.review(correct: true, today: '2026-11-08');
      expect((c.box, c.due), (1, '2026-11-09'));
      c = c.review(correct: true, today: '2026-11-09');
      expect((c.box, c.due), (2, '2026-11-12'));
    });
    test('a wrong answer sends it back to box 0, due today', () {
      final c = const SrsCard(box: 4, due: '2026-11-08').review(correct: false, today: '2026-11-08');
      expect((c.box, c.due), (0, '2026-11-08'));
    });
    test('the top box holds at 60 days and counts as mastered', () {
      final c = const SrsCard(box: 6, due: '2026-11-08').review(correct: true, today: '2026-11-08');
      expect((c.box, c.due, c.mastered), (6, '2027-01-07', true));
    });
  });
}
