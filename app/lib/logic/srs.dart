// Dates as local calendar days (YYYY-MM-DD) and Leitner spaced repetition — ports of the web app's
// src/lib/dates.ts and src/lib/srs.ts, kept identical so saved progress means the same thing.

String dayKey([DateTime? d]) {
  final t = d ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}';
}

DateTime _parse(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String addDays(String key, int n) {
  final d = _parse(key);
  return dayKey(DateTime(d.year, d.month, d.day + n));
}

/// Leitner boxes: days until a card in each box is due again.
const intervals = [0, 1, 3, 7, 14, 30, 60];
const masteredBox = 5;

class SrsCard {
  const SrsCard({required this.box, required this.due});
  final int box;
  final String due;

  factory SrsCard.fresh(String today) => SrsCard(box: 0, due: today);

  SrsCard review({required bool correct, required String today}) {
    final next = correct ? (box + 1).clamp(0, intervals.length - 1) : 0;
    return SrsCard(box: next, due: addDays(today, correct ? intervals[next] : 0));
  }

  bool isDue(String today) => due.compareTo(today) <= 0;
  bool get mastered => box >= masteredBox;

  Map<String, Object> toJson() => {'box': box, 'due': due};
  factory SrsCard.fromJson(Map<String, dynamic> j) => SrsCard(box: j['box'] as int, due: j['due'] as String);
}

/// Consecutive active days ending today, or yesterday if today isn't done yet.
int streak(Iterable<String> activeDays, String today) {
  final days = activeDays.toSet();
  var cursor = days.contains(today) ? today : addDays(today, -1);
  var n = 0;
  while (days.contains(cursor)) {
    n++;
    cursor = addDays(cursor, -1);
  }
  return n;
}
