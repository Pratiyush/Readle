import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../content/cdn/content_client.dart';
import '../content/models.dart';
import '../l10n/app_localizations.dart';
import '../logic/srs.dart';
import '../state/app_state.dart';
import 'app_scope.dart';
import 'theme.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, this.visible = true});

  /// The tab is on screen. Settings checks the notification permission each time it shows (and
  /// when the app comes back), since the learner can block notifications in system settings.
  final bool visible;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String? _version; // "0.1.0 (7)": shown in Settings and put in the support mail's subject

  bool _notificationsBlocked = false; // the reminder is on, but the system won't show it
  late final AppLifecycleListener _lifecycle;

  @override
  void didUpdateWidget(ProgressScreen old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _checkNotifications();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _checkNotifications() async {
    if (!mounted || !widget.visible) return;
    final scope = AppScope.read(context);
    final reminders = scope.reminders;
    final blocked = reminders != null && scope.state.settings.reminder && !await reminders.enabled();
    if (mounted && blocked != _notificationsBlocked) setState(() => _notificationsBlocked = blocked);
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _checkNotifications);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNotifications());
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = '${i.version} (${i.buildNumber})');
    }, onError: (Object _) {});
  }

  late Future<List<StoryMeta>> _library;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _library = AppScope.read(context).content.library();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final state = scope.state;
    final palette = Palette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final today = state.today;
    final goal = state.settings.dailyGoal;
    final readToday = state.readToday;
    final active = state.activeDays.toSet();
    final mastered = state.words.values.where((w) => w.card.mastered).length;
    final week = [for (var i = -6; i <= 0; i++) addDays(today, i)];
    final l = AppLocalizations.of(context);
    final weekdays = MaterialLocalizations.of(context).narrowWeekdays; // Sunday first: S M T W T F S

    Widget panel(List<Widget> children) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
    Widget stat(String value, String label, Key key) => Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: palette.muted)),
          ],
        ),
      ),
    );
    Widget setting<T>(String label, T value, Map<T, String> options, ValueChanged<T> onChanged, Key key) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // The choice sits beside its label, or under it when both don't fit (long level names,
      // large text); a choice wider than the row is cut with an ellipsis instead of overflowing.
      child: LayoutBuilder(
        builder: (context, c) => Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.maxWidth),
              child: IntrinsicWidth(
                child: DropdownButton<T>(
                  key: key,
                  value: value,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [
                    for (final o in options.entries)
                      DropdownMenuItem(
                        value: o.key,
                        child: Text(o.value, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => v == null ? null : onChanged(v),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('progress-list'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l.progressEyebrow,
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, letterSpacing: 1, fontSize: 12),
          ),
          Text(l.progressTitle, style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          panel([
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: (readToday / goal).clamp(0, 1).toDouble(),
                        strokeWidth: 7,
                        backgroundColor: palette.line,
                      ),
                      Center(
                        child: Text('${readToday.clamp(0, goal)}/$goal', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        readToday >= goal ? l.progressGoalReached : l.progressTodaysGoal,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        l.progressGoalText(goal),
                        key: const Key('goal-text'),
                        style: TextStyle(color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in week)
                  Column(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active.contains(d) ? palette.accentSoft : palette.surface2,
                          shape: BoxShape.circle,
                        ),
                        child: Text(active.contains(d) ? '🔥' : ''),
                      ),
                      const SizedBox(height: 4),
                      Text(weekdays[DateTime.parse(d).weekday % 7], style: TextStyle(color: palette.muted, fontSize: 12)),
                    ],
                  ),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          // Two rows that size to their content (a fixed-ratio grid clipped the labels).
          Row(
            children: [
              Expanded(child: stat('🔥 ${state.streakDays}', l.statDayStreak(state.streakDays), const Key('stat-streak'))),
              const SizedBox(width: 12),
              Expanded(child: stat('${state.read.length}', l.statStoriesRead(state.read.length), const Key('stat-read'))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: stat('${state.words.length}', l.statWordsSaved(state.words.length), const Key('stat-saved'))),
              const SizedBox(width: 12),
              Expanded(child: stat('$mastered', l.statWordsMastered(mastered), const Key('stat-mastered'))),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<StoryMeta>>(
            future: _library,
            builder: (context, snap) {
              final lib = snap.data ?? const [];
              return panel([
                Text(l.progressByLevel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (final l in levels)
                  Builder(
                    builder: (context) {
                      final all = lib.where((s) => s.level == l).toList();
                      final done = all.where((s) => state.read.containsKey(s.id)).length;
                      return Padding(
                        key: Key('level-$l'),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            SizedBox(width: 34, child: LevelBadge(l)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: all.isEmpty ? 0 : done / all.length,
                                  minHeight: 8,
                                  backgroundColor: palette.line,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('$done/${all.length}', style: TextStyle(color: palette.muted)),
                          ],
                        ),
                      );
                    },
                  ),
              ]);
            },
          ),
          const SizedBox(height: 12),
          panel([
            Text(l.settingsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            setting<String>(
              l.settingsStoryLevel,
              state.settings.level,
              {
                'all': l.settingsLevelAll,
                'A1': l.settingsLevelA1,
                'A2': l.settingsLevelA2,
                'B1': l.settingsLevelB1,
                'B2': l.settingsLevelB2,
              },
              (v) => state.updateSettings(state.settings.copyWith(level: v)),
              const Key('story-level'),
            ),
            setting<int>(
              l.settingsDailyGoal,
              goal,
              {
                for (final n in const [1, 2, 3, 5]) n: l.settingsDailyGoalOption(n),
              },
              (v) => state.updateSettings(state.settings.copyWith(dailyGoal: v)),
              const Key('daily-goal'),
            ),
            setting<ThemeChoice>(
              l.settingsTheme,
              state.settings.theme,
              {ThemeChoice.system: l.themeSystem, ThemeChoice.light: l.themeLight, ThemeChoice.dark: l.themeDark},
              (v) => state.updateSettings(state.settings.copyWith(theme: v)),
              const Key('theme'),
            ),
            setting<double>(
              l.settingsSpeechSpeed,
              state.settings.speechRate,
              {0.7: l.speechSlow, 0.9: l.speechNormal, 1.05: l.speechFast},
              (v) => state.updateSettings(state.settings.copyWith(speechRate: v)),
              const Key('speech-speed'),
            ),
            SwitchListTile(
              key: const Key('auto-play'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsSayWords),
              value: state.settings.autoPlayWords,
              onChanged: (v) => state.updateSettings(state.settings.copyWith(autoPlayWords: v)),
            ),
            if (scope.reminders case final reminders?) ...[
              SwitchListTile(
                key: const Key('reminder'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.settingsReminder),
                subtitle: Text(l.settingsReminderDetail),
                value: state.settings.reminder,
                onChanged: (on) async {
                  // Permission is asked here, when the learner wants the reminder, never at launch.
                  if (on && !await reminders.requestPermission()) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(key: const Key('reminder-denied'), content: Text(l.settingsNotificationsDenied)));
                    return;
                  }
                  state.updateSettings(state.settings.copyWith(reminder: on));
                  if (on) setState(() => _notificationsBlocked = false); // just allowed
                },
              ),
              if (state.settings.reminder && _notificationsBlocked)
                ListTile(
                  key: const Key('reminder-blocked'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: Text(l.settingsNotificationsBlocked),
                  subtitle: Text(l.settingsNotificationsBlockedDetail),
                  onTap: reminders.openSettings,
                ),
              if (state.settings.reminder)
                ListTile(
                  key: const Key('reminder-time'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.settingsReminderTime),
                  trailing: Text(
                    _timeOf(state.settings.reminderMinutes).format(context),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _timeOf(state.settings.reminderMinutes));
                    if (picked != null) state.updateSettings(state.settings.copyWith(reminderMinutes: picked.hour * 60 + picked.minute));
                  },
                ),
            ],
            if (scope.ads.privacyOptionsRequired)
              ListTile(
                key: const Key('privacy-options'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.settingsPrivacyChoices),
                trailing: const Icon(Icons.chevron_right),
                onTap: scope.ads.showPrivacyOptions,
              ),
            if (scope.updates != null) ...[
              _ContentCheckTile(updates: scope.updates!),
              SwitchListTile(
                key: const Key('auto-update-wifi'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.settingsAutoUpdate),
                subtitle: Text(l.settingsAutoUpdateDetail),
                value: state.settings.autoUpdateOnWifi,
                onChanged: (v) => state.updateSettings(state.settings.copyWith(autoUpdateOnWifi: v)),
              ),
            ],
            ...legalTiles(context),
            ListTile(
              key: const Key('licences'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsLicences),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(context: context, applicationName: 'Readle', applicationVersion: _version),
            ),
            ListTile(
              key: const Key('support'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsSupport),
              subtitle: const Text(supportEmail),
              trailing: const Icon(Icons.mail_outline),
              onTap: () => launchUrl(supportMail(_version ?? '')),
            ),
            ListTile(
              key: const Key('version'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsVersion),
              trailing: Text(_version ?? '…'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('reset'),
              style: FilledButton.styleFrom(backgroundColor: palette.danger, foregroundColor: Colors.white),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l.settingsResetQuestion),
                    content: Text(l.settingsResetDetail),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.settingsCancel)),
                      TextButton(
                        key: const Key('confirm-reset'),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l.settingsDelete),
                      ),
                    ],
                  ),
                );
                if (ok == true) state.reset();
              },
              child: Text(l.settingsReset),
            ),
          ]),
          const SizedBox(height: 16),
          Text(
            l.progressCredits,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Privacy policy and Impressum (DDG §5), both from the one slug in config.dart; hidden while it is
/// empty so no build links to a page that doesn't exist yet.
List<Widget> legalTiles(BuildContext context, {String slug = legalSlug}) => [
  for (final (key, label, page) in [
    (const Key('privacy-policy'), AppLocalizations.of(context).settingsPrivacyPolicy, 'privacy'),
    // l10n: German on purpose (Impressum is the German legal notice's own name, DDG §5)
    (const Key('impressum'), 'Impressum', 'impressum'),
  ])
    if (legalPage(page, slug: slug) case final url?)
      ListTile(
        key: key,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => launchUrl(url, mode: LaunchMode.externalApplication),
      ),
];

TimeOfDay _timeOf(int minutes) => TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

/// Settings → New stories: the daily check runs on its own; this runs it now.
class _ContentCheckTile extends StatelessWidget {
  const _ContentCheckTile({required this.updates});
  final ContentClient updates;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final subtitle = switch (updates.kind) {
      UpdateKind.available => l.contentCheckAvailable(updates.newStories),
      UpdateKind.appTooOld => l.contentCheckAppTooOld,
      UpdateKind.none => l.contentCheckNone,
    };
    return ListTile(
      key: const Key('content-check'),
      leading: const Icon(Icons.auto_stories_outlined),
      title: Text(l.contentCheckTitle),
      subtitle: Text(subtitle),
      trailing: updates.busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
      onTap: () async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        await updates.check(force: true);
        if (updates.kind == UpdateKind.none) {
          messenger?.showSnackBar(SnackBar(content: Text(l.contentCheckUpToDate)));
        }
      },
    );
  }
}
