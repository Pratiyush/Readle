// The daily reminder: off by default, one a day at the learner's time, skipped once they have
// read or practised today, quiet after a week away. Runs in Europe/Berlin (tools/verify.sh), so
// the DST cases below are real clock changes.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:readle/services/reminders.dart';
import 'package:readle/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

String fmt(DateTime t) =>
    '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

void main() {
  group('reminderTimes', () {
    const seven = 19 * 60;

    test('before the time, nothing done yet: today and the next six days', () {
      final t = reminderTimes(now: DateTime(2026, 11, 9, 8), minutes: seven, doneToday: false);
      expect(t.map(fmt), ['11-09 19:00', '11-10 19:00', '11-11 19:00', '11-12 19:00', '11-13 19:00', '11-14 19:00', '11-15 19:00']);
    });

    test('already read today: starts tomorrow, still seven', () {
      final t = reminderTimes(now: DateTime(2026, 11, 9, 8), minutes: seven, doneToday: true);
      expect(t.first.day, 10);
      expect(t, hasLength(reminderDays));
    });

    test('exactly at the time, and one minute before', () {
      expect(reminderTimes(now: DateTime(2026, 11, 9, 19), minutes: seven, doneToday: false).first.day, 10);
      expect(reminderTimes(now: DateTime(2026, 11, 9, 18, 59), minutes: seven, doneToday: false).first.day, 9);
    });

    test('midnight: 23:59 with a 00:00 reminder fires in one minute, tomorrow', () {
      final t = reminderTimes(now: DateTime(2026, 11, 9, 23, 59), minutes: 0, doneToday: false);
      expect(fmt(t.first), '11-10 00:00');
    });

    test('DST nights keep the wall-clock time, one reminder per calendar day', () {
      final autumn = reminderTimes(now: DateTime(2026, 10, 23, 8), minutes: seven, doneToday: false);
      expect(autumn.map(fmt).take(4), ['10-23 19:00', '10-24 19:00', '10-25 19:00', '10-26 19:00']);
      expect(autumn[2].difference(autumn[1]), const Duration(hours: 25), reason: 'clocks go back on 25 Oct');
      final spring = reminderTimes(now: DateTime(2026, 3, 27, 8), minutes: seven, doneToday: false);
      expect(spring[2].difference(spring[1]), const Duration(hours: 23), reason: 'clocks go forward on 29 Mar');
      expect(spring.map((t) => t.hour).toSet(), {19});
    });

    test('a time inside the spring-forward gap still fires once that day', () {
      final t = reminderTimes(now: DateTime(2026, 3, 28, 8), minutes: 2 * 60 + 30, doneToday: true);
      expect(t.first.day, 29);
      expect(t.map((x) => '${x.month}-${x.day}').toSet(), hasLength(reminderDays), reason: 'seven different days');
    });

    test('year end and leap day', () {
      expect(reminderTimes(now: DateTime(2026, 12, 30, 20), minutes: seven, doneToday: false).take(3).map(fmt), [
        '12-31 19:00',
        '01-01 19:00',
        '01-02 19:00',
      ]);
      expect(reminderTimes(now: DateTime(2028, 2, 28, 20), minutes: seven, doneToday: false).first.day, 29);
    });
  });

  group('settings', () {
    test('off by default, at 19:00', () {
      const s = Settings();
      expect(s.reminder, isFalse);
      expect(s.reminderMinutes, 19 * 60);
    });

    test('a stored time out of range or of the wrong type falls back to 19:00, alone', () {
      for (final bad in [-1, 1440, '19:00', 600.5, null]) {
        final s = Settings.fromJson({'reminder': true, 'reminderMinutes': bad, 'level': 'B1'});
        expect(s.reminderMinutes, 19 * 60, reason: '$bad');
        expect(s.reminder, isTrue);
        expect(s.level, 'B1');
      }
      expect(Settings.fromJson({'reminderMinutes': 0}).reminderMinutes, 0);
      expect(Settings.fromJson({'reminderMinutes': 1439}).reminderMinutes, 1439);
      expect(Settings.fromJson({'reminder': 'yes'}).reminder, isFalse);
    });

    test('round-trips through the saved state', () {
      final s = Settings.fromJson(
        jsonDecode(jsonEncode(const Settings(reminder: true, reminderMinutes: 450).toJson())) as Map<String, dynamic>,
      );
      expect((s.reminder, s.reminderMinutes), (true, 450));
    });
  });

  group('DailyReminder', () {
    late AppState state;
    late RecordingReminders platform;
    var now = DateTime(2026, 11, 9, 8);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      now = DateTime(2026, 11, 9, 8);
      state = await AppState.load(await SharedPreferences.getInstance(), today: () => '2026-11-09');
      platform = RecordingReminders();
      DailyReminder(state: state, reminders: platform, now: () => now).start();
      await pumpEventQueue();
    });

    test('off by default: no platform call at all, permission never asked', () {
      expect(platform.pending, isEmpty);
      expect((platform.permissionAsks, platform.schedules, platform.cancels), (0, 0, 0));
    });

    test('on: seven reminders from today; reading today moves them to tomorrow; off: none left', () async {
      state.updateSettings(state.settings.copyWith(reminder: true));
      await pumpEventQueue();
      expect(platform.pending.first, DateTime(2026, 11, 9, 19));
      expect(platform.pending, hasLength(7));

      state.finishStory('brot');
      await pumpEventQueue();
      expect(platform.pending.first, DateTime(2026, 11, 10, 19), reason: 'no nudge after you have read');

      state.updateSettings(state.settings.copyWith(reminderMinutes: 7 * 60 + 30));
      await pumpEventQueue();
      expect(platform.pending.first, DateTime(2026, 11, 10, 7, 30));

      state.updateSettings(state.settings.copyWith(reminder: false));
      await pumpEventQueue();
      expect(platform.pending, isEmpty);
    });

    test('changes that do not move the reminder do not reschedule it', () async {
      state.updateSettings(state.settings.copyWith(reminder: true));
      await pumpEventQueue();
      final before = platform.schedules;
      state.toggleWord(key: 'k', word: 'Wort', storyId: 'brot', context: 'x');
      state.updateSettings(state.settings.copyWith(theme: ThemeChoice.dark));
      state.setProgress('brot', 3);
      await pumpEventQueue();
      expect(platform.schedules, before);
    });

    test('reset turns the reminder off and clears it', () async {
      state.updateSettings(state.settings.copyWith(reminder: true));
      await pumpEventQueue();
      state.reset();
      await pumpEventQueue();
      expect(state.settings.reminder, isFalse);
      expect(platform.pending, isEmpty);
    });
  });
}
