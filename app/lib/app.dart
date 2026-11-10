import 'package:flutter/material.dart';

import 'content/cdn/content_client.dart';
import 'l10n/app_localizations.dart';
import 'content/content_repository.dart';
import 'services/ads.dart';
import 'services/reminders.dart';
import 'services/speech.dart';
import 'services/word_player.dart';
import 'state/app_state.dart';
import 'ui/app_scope.dart';
import 'ui/library_screen.dart';
import 'ui/onboarding_screen.dart';
import 'ui/progress_screen.dart';
import 'ui/theme.dart';
import 'ui/words_screen.dart';

/// The largest system text scale the app follows.
const maxTextScale = 2.0;

class ReadleApp extends StatelessWidget {
  const ReadleApp({
    super.key,
    required this.state,
    required this.content,
    required this.speech,
    required this.player,
    required this.ads,
    this.updates,
    this.reminders,
  });

  final AppState state;
  final ContentRepository content;
  final Speech speech;
  final WordPlayer player;
  final Ads ads;
  final ContentClient? updates;
  final Reminders? reminders;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      content: content,
      speech: speech,
      player: player,
      ads: ads,
      updates: updates,
      reminders: reminders,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Readle',
          debugShowCheckedModeBanner: false,
          // UI strings: lib/l10n/app_en.arb (English only for now).
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: switch (state.settings.theme) {
            ThemeChoice.light => ThemeMode.light,
            ThemeChoice.dark => ThemeMode.dark,
            ThemeChoice.system => ThemeMode.system,
          },
          // System text up to 200 % (WCAG 1.4.4). iOS accessibility sizes reach about 310 %, which
          // splits headings mid-word and clips cards; the story text has its own size on top.
          builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: maxTextScale, child: child!),
          home: const _Root(),
        ),
      ),
    );
  }
}

/// The level question on first launch, then the app.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => AppScope.of(context).state.onboarded ? const Shell() : const OnboardingScreen();
}

/// Three tabs in an IndexedStack, so each keeps its scroll position and filters while you read.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final due = AppScope.of(context).state.dueCount;
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const LibraryScreen(),
          const WordsScreen(),
          ProgressScreen(visible: _tab == 2),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            key: const Key('tab-stories'),
            icon: const Icon(Icons.auto_stories_outlined),
            selectedIcon: const Icon(Icons.auto_stories),
            label: l.tabStories,
          ),
          NavigationDestination(
            key: const Key('tab-words'),
            icon: Badge(isLabelVisible: due > 0, label: Text(due > 99 ? '99+' : '$due'), child: const Icon(Icons.style_outlined)),
            selectedIcon: Badge(isLabelVisible: due > 0, label: Text(due > 99 ? '99+' : '$due'), child: const Icon(Icons.style)),
            label: l.tabWords,
          ),
          NavigationDestination(
            key: const Key('tab-progress'),
            icon: const Icon(Icons.local_fire_department_outlined),
            selectedIcon: const Icon(Icons.local_fire_department),
            label: l.tabProgress,
          ),
        ],
      ),
    );
  }
}
