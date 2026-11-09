import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../state/app_state.dart';

/// How many days ahead the reminder is set. Each app open sets the next week again, so a learner
/// who stays away for a week stops hearing from the app: gentle, not a nag.
const reminderDays = 7;

/// The local times of the next [days] reminders at [minutes] after midnight: today too when the
/// time is still ahead and the learner hasn't read or practised yet ([doneToday]).
///
/// Each one is built from the calendar day in local time, so a DST night keeps 19:00 at 19:00
/// (23 or 25 hours apart) and a time inside the spring-forward gap moves to the next valid minute
/// of the same day.
List<DateTime> reminderTimes({required DateTime now, required int minutes, required bool doneToday, int days = reminderDays}) {
  final times = <DateTime>[];
  for (var d = 0; times.length < days; d++) {
    final at = DateTime(now.year, now.month, now.day + d, minutes ~/ 60, minutes % 60);
    if (d == 0 && (doneToday || !at.isAfter(now))) continue;
    times.add(at);
  }
  return times;
}

/// The platform side: permission, and a set of one-shot notifications.
abstract interface class Reminders {
  /// Asks for notification permission (Android 13+, iOS); true when reminders can show.
  Future<bool> requestPermission();

  /// Replaces every pending reminder with one at each of [at] (local times).
  Future<void> schedule(List<DateTime> at);

  Future<void> cancelAll();

  /// Whether the system lets the app show notifications now (the learner can block them later).
  Future<bool> enabled();

  /// The system's notification settings for the app.
  Future<void> openSettings();
}

/// Notifications through flutter_local_notifications. One-shot, inexact (no exact-alarm
/// permission), each set as a UTC instant computed from local time, so no time-zone database or
/// plugin is needed; travelling across zones is picked up at the next app open.
class LocalReminders implements Reminders {
  LocalReminders([FlutterLocalNotificationsPlugin? plugin]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _init;

  static const _firstId = 7000;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'readle.daily',
      'Daily reminder',
      channelDescription: 'One reminder a day to read, at the time you choose.',
      icon: 'ic_notification',
      visibility: NotificationVisibility.public, // nothing private in it: show it on the lock screen
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _ready() => _init ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      // Ask when the learner turns the reminder on, never at launch.
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ),
  );

  @override
  Future<bool> requestPermission() async {
    await _ready();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> schedule(List<DateTime> at) async {
    await _ready();
    await _plugin.cancelAll();
    for (final (i, t) in at.indexed) {
      await _plugin.zonedSchedule(
        id: _firstId + i,
        scheduledDate: tz.TZDateTime.from(t.toUtc(), tz.UTC),
        title: 'Zeit für eine Geschichte',
        body: 'A short German story is waiting.', // fits the collapsed lock-screen card (device pass, 9 Nov)
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _ready();
    await _plugin.cancelAll();
  }

  @override
  Future<bool> enabled() async {
    await _ready();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.areNotificationsEnabled() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return (await ios?.checkPermissions())?.isEnabled ?? false;
  }

  @override
  Future<void> openSettings() async {
    await _ready();
    await _plugin.openAppNotificationSettings();
  }
}

/// Records what would be scheduled. Used by tests and the on-device flows.
class RecordingReminders implements Reminders {
  RecordingReminders({this.granted = true});

  bool granted;
  List<DateTime> pending = [];
  int permissionAsks = 0, schedules = 0, cancels = 0, settingsOpened = 0;

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return granted;
  }

  @override
  Future<void> schedule(List<DateTime> at) async {
    schedules++;
    pending = [...at];
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
    pending = [];
  }

  @override
  Future<bool> enabled() async => granted;

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// Keeps the pending reminders in step with [AppState]: on/off, the time, and whether the learner
/// has already read or practised today (then today's reminder is skipped).
///
/// With the reminder off at launch it never touches the platform; turning it off cancels.
class DailyReminder {
  DailyReminder({required this.state, required this.reminders, DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppState state;
  final Reminders reminders;
  final DateTime Function() _now;

  Object? _built; // what the pending reminders were built from
  Future<void> _queue = Future.value();

  void start() {
    state.addListener(_sync);
    _sync();
  }

  void stop() => state.removeListener(_sync);

  void _sync() {
    final s = state.settings;
    final doneToday = state.activeDays.contains(state.today);
    final key = s.reminder ? (s.reminderMinutes, doneToday, state.today) : false;
    if (key == _built || (_built == null && key == false)) {
      _built = key;
      return;
    }
    _built = key;
    // One platform call at a time, in order: a quick off-on-off must end off.
    _queue = _queue
        .then(
          (_) => s.reminder
              ? reminders.schedule(reminderTimes(now: _now(), minutes: s.reminderMinutes, doneToday: doneToday))
              : reminders.cancelAll(),
        )
        .catchError((Object e) => debugPrint('reminder: $e'));
  }
}
