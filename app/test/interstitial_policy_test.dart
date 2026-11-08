import 'package:flutter_test/flutter_test.dart';
import 'package:readle/services/interstitial_policy.dart';

void main() {
  var now = DateTime(2026, 11, 8, 10);
  InterstitialPolicy policy({bool first = false}) => InterstitialPolicy(firstSession: first, now: () => now);

  test('never in the first session', () {
    final p = policy(first: true);
    expect([for (var i = 0; i < 6; i++) p.storyFinished()], everyElement(isFalse));
  });

  test('at most one per 3 finished stories', () {
    final p = policy();
    expect([p.storyFinished(), p.storyFinished(), p.storyFinished()], [false, false, true]);
    p.shown();
    now = now.add(const Duration(minutes: 10));
    expect([p.storyFinished(), p.storyFinished(), p.storyFinished()], [false, false, true]);
  });

  test('at least 4 minutes apart and 4 a day', () {
    final p = policy();
    for (var i = 0; i < 3; i++) {
      p.storyFinished();
    }
    p.shown();
    for (var i = 0; i < 3; i++) {
      p.storyFinished();
    }
    expect(p.storyFinished(), isFalse, reason: 'within 4 minutes');
    var shown = 1;
    for (var round = 0; round < 6; round++) {
      now = now.add(const Duration(minutes: 5));
      var ok = false;
      for (var i = 0; i < 3; i++) {
        ok = p.storyFinished();
      }
      if (ok) {
        p.shown();
        shown++;
      }
    }
    expect(shown, 4);
  });

  test('not within 5 minutes of a rewarded ad', () {
    final p = policy()..rewardedShown();
    p.storyFinished();
    p.storyFinished();
    expect(p.storyFinished(), isFalse);
  });
}
