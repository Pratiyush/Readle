import 'package:flutter/material.dart';

import 'content/cdn/content_client.dart';
import 'content/content_repository.dart';
import 'services/ads.dart';
import 'services/speech.dart';
import 'services/word_player.dart';
import 'state/app_state.dart';
import 'ui/app_scope.dart';
import 'ui/library_screen.dart';
import 'ui/progress_screen.dart';
import 'ui/theme.dart';
import 'ui/words_screen.dart';

class ReadleApp extends StatelessWidget {
  const ReadleApp({super.key, required this.state, required this.content, required this.speech, required this.player, required this.ads, this.updates});

  final AppState state;
  final ContentRepository content;
  final Speech speech;
  final WordPlayer player;
  final Ads ads;
  final ContentClient? updates;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      content: content,
      speech: speech,
      player: player,
      ads: ads,
      updates: updates,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Readle',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: switch (state.settings.theme) {
            ThemeChoice.light => ThemeMode.light,
            ThemeChoice.dark => ThemeMode.dark,
            ThemeChoice.system => ThemeMode.system,
          },
          home: const Shell(),
        ),
      ),
    );
  }
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
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [LibraryScreen(), WordsScreen(), ProgressScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(key: Key('tab-stories'), icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories), label: 'Stories'),
          NavigationDestination(
            key: const Key('tab-words'),
            icon: Badge(isLabelVisible: due > 0, label: Text(due > 99 ? '99+' : '$due'), child: const Icon(Icons.style_outlined)),
            selectedIcon: Badge(isLabelVisible: due > 0, label: Text(due > 99 ? '99+' : '$due'), child: const Icon(Icons.style)),
            label: 'Words',
          ),
          const NavigationDestination(key: Key('tab-progress'), icon: Icon(Icons.local_fire_department_outlined), selectedIcon: Icon(Icons.local_fire_department), label: 'Progress'),
        ],
      ),
    );
  }
}
