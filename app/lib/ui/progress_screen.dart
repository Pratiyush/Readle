import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../content/cdn/content_client.dart';
import '../content/models.dart';
import '../logic/srs.dart';
import '../state/app_state.dart';
import 'app_scope.dart';
import 'theme.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
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
    final week = [for (var i = -6; i <= 0; i++) addDays(today, i)];
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    Widget panel(List<Widget> children) => Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
        );
    Widget stat(String value, String label, Key key) => Card(
          key: key,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Text(label, style: TextStyle(color: palette.muted)),
            ]),
          ),
        );
    Widget setting<T>(String label, T value, Map<T, String> options, ValueChanged<T> onChanged, Key key) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            DropdownButton<T>(
              key: key,
              value: value,
              underline: const SizedBox(),
              items: [for (final o in options.entries) DropdownMenuItem(value: o.key, child: Text(o.value))],
              onChanged: (v) => v == null ? null : onChanged(v),
            ),
          ]),
        );

    return SafeArea(
      bottom: false,
      child: ListView(key: const Key('progress-list'), padding: const EdgeInsets.all(16), children: [
        Text('YOUR PROGRESS', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, letterSpacing: 1, fontSize: 12)),
        Text('Progress', style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        panel([
          Row(children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(fit: StackFit.expand, children: [
                CircularProgressIndicator(value: (readToday / goal).clamp(0, 1).toDouble(), strokeWidth: 7, backgroundColor: palette.line),
                Center(child: Text('${readToday.clamp(0, goal)}/$goal', style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(readToday >= goal ? 'Daily goal reached! 🎉' : "Today's goal", style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('Read $goal ${goal == 1 ? 'story' : 'stories'} a day.', key: const Key('goal-text'), style: TextStyle(color: palette.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (final d in week)
              Column(children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: active.contains(d) ? palette.accentSoft : palette.surface2, shape: BoxShape.circle),
                  child: Text(active.contains(d) ? '🔥' : ''),
                ),
                const SizedBox(height: 4),
                Text(weekdays[DateTime.parse(d).weekday - 1], style: TextStyle(color: palette.muted, fontSize: 12)),
              ]),
          ]),
        ]),
        const SizedBox(height: 12),
        // Two rows that size to their content (a fixed-ratio grid clipped the labels).
        Row(children: [
          Expanded(child: stat('🔥 ${state.streakDays}', 'day streak', const Key('stat-streak'))),
          const SizedBox(width: 12),
          Expanded(child: stat('${state.read.length}', 'stories read', const Key('stat-read'))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: stat('${state.words.length}', 'words saved', const Key('stat-saved'))),
          const SizedBox(width: 12),
          Expanded(child: stat('${state.words.values.where((w) => w.card.mastered).length}', 'words mastered', const Key('stat-mastered'))),
        ]),
        const SizedBox(height: 12),
        FutureBuilder<List<StoryMeta>>(
          future: _library,
          builder: (context, snap) {
            final lib = snap.data ?? const [];
            return panel([
              const Text('Stories by level', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final l in levels)
                Builder(builder: (context) {
                  final all = lib.where((s) => s.level == l).toList();
                  final done = all.where((s) => state.read.containsKey(s.id)).length;
                  return Padding(
                    key: Key('level-$l'),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      SizedBox(width: 34, child: LevelBadge(l)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                              value: all.isEmpty ? 0 : done / all.length, minHeight: 8, backgroundColor: palette.line),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$done/${all.length}', style: TextStyle(color: palette.muted)),
                    ]),
                  );
                }),
            ]);
          },
        ),
        const SizedBox(height: 12),
        panel([
          const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          setting<int>('Daily goal', goal, {1: '1 story', 2: '2 stories', 3: '3 stories', 5: '5 stories'},
              (v) => state.updateSettings(state.settings.copyWith(dailyGoal: v)), const Key('daily-goal')),
          setting<ThemeChoice>('Theme', state.settings.theme,
              {ThemeChoice.system: 'System', ThemeChoice.light: 'Light', ThemeChoice.dark: 'Dark'},
              (v) => state.updateSettings(state.settings.copyWith(theme: v)), const Key('theme')),
          setting<double>('Speech speed', state.settings.speechRate, {0.7: 'Slow', 0.9: 'Normal', 1.05: 'Fast'},
              (v) => state.updateSettings(state.settings.copyWith(speechRate: v)), const Key('speech-speed')),
          SwitchListTile(
            key: const Key('auto-play'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Say words when tapped'),
            value: state.settings.autoPlayWords,
            onChanged: (v) => state.updateSettings(state.settings.copyWith(autoPlayWords: v)),
          ),
          if (scope.ads.privacyOptionsRequired)
            ListTile(
              key: const Key('privacy-options'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Privacy & ad choices'),
              trailing: const Icon(Icons.chevron_right),
              onTap: scope.ads.showPrivacyOptions,
            ),
          if (scope.updates != null) _ContentCheckTile(updates: scope.updates!),
          ...legalTiles(),
          ListTile(
            key: const Key('licences'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Licences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(context: context, applicationName: 'Readle'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('reset'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48), shape: const StadiumBorder(), foregroundColor: palette.bad),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset all progress?'),
                  content: const Text("This deletes your streak, finished stories and saved words. It can't be undone."),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    TextButton(key: const Key('confirm-reset'), onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true) state.reset();
            },
            child: const Text('Reset all progress'),
          ),
        ]),
        const SizedBox(height: 16),
        Text('Stories and dictionary from the Lernle project. German text is machine-assisted and awaiting native review.',
            textAlign: TextAlign.center, style: TextStyle(color: palette.muted, fontSize: 12)),
        const SizedBox(height: 16),
      ]),
    );
  }
}

/// Privacy policy and Impressum (DDG §5), both from the one slug in config.dart; hidden while it is
/// empty so no build links to a page that doesn't exist yet.
List<Widget> legalTiles({String slug = legalSlug}) => [
      for (final (key, label, page) in [
        (const Key('privacy-policy'), 'Privacy policy', 'privacy'),
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

/// Settings → New stories: the daily check runs on its own; this runs it now.
class _ContentCheckTile extends StatelessWidget {
  const _ContentCheckTile({required this.updates});
  final ContentClient updates;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (updates.kind) {
      UpdateKind.available => updates.newStories == 1 ? '1 new story: download it from Stories' : '${updates.newStories} new stories: download them from Stories',
      UpdateKind.appTooOld => 'Update the app to get new stories',
      UpdateKind.none => 'Checked once a day when you open the app',
    };
    return ListTile(
      key: const Key('content-check'),
      leading: const Icon(Icons.auto_stories_outlined),
      title: const Text('New stories'),
      subtitle: Text(subtitle),
      trailing: updates.busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
      onTap: () async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        await updates.check(force: true);
        if (updates.kind == UpdateKind.none) {
          messenger?.showSnackBar(const SnackBar(content: Text('You have every story. Check again tomorrow.')));
        }
      },
    );
  }
}

