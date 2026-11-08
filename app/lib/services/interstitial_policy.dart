/// When an interstitial may show (ad placement map, docs/review-2026-11-08.md): only at the natural
/// break after a finished story, at most one per [everyStories] stories, [minGap] apart and
/// [maxPerDay] a day, and never during the learner's first session.
class InterstitialPolicy {
  InterstitialPolicy({
    required this.firstSession,
    DateTime Function()? now,
    this.everyStories = 3,
    this.minGap = const Duration(minutes: 4),
    this.maxPerDay = 4,
  }) : _now = now ?? DateTime.now;

  final bool firstSession;
  final int everyStories;
  final Duration minGap;
  final int maxPerDay;
  final DateTime Function() _now;

  int _storiesSinceLast = 0;
  DateTime? _lastShown;
  DateTime? _lastRewarded;
  final _shownOn = <String, int>{};

  String _day(DateTime t) => '${t.year}-${t.month}-${t.day}';

  /// A story (and its quiz) was finished: may an interstitial show now?
  bool storyFinished() {
    _storiesSinceLast++;
    final now = _now();
    if (firstSession) return false;
    if (_storiesSinceLast < everyStories) return false;
    if (_lastShown != null && now.difference(_lastShown!) < minGap) return false;
    if (_lastRewarded != null && now.difference(_lastRewarded!) < const Duration(minutes: 5)) return false;
    if ((_shownOn[_day(now)] ?? 0) >= maxPerDay) return false;
    return true;
  }

  void shown() {
    final now = _now();
    _lastShown = now;
    _storiesSinceLast = 0;
    _shownOn[_day(now)] = (_shownOn[_day(now)] ?? 0) + 1;
  }

  void rewardedShown() => _lastRewarded = _now();
}
