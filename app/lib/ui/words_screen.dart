import 'package:flutter/material.dart';

import '../content/models.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'app_scope.dart';
import 'practice_screen.dart';
import 'theme.dart';

enum WordFilter { all, due, learning, mastered }

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  WordFilter _filter = WordFilter.all;
  late Future<Dictionary> _dict;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dict = AppScope.read(context).content.dictionary();
  }

  bool _matches(SavedWord w, String today) => switch (_filter) {
    WordFilter.all => true,
    WordFilter.due => w.card.isDue(today),
    WordFilter.learning => !w.card.mastered,
    WordFilter.mastered => w.card.mastered,
  };

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final state = scope.state;
    final palette = Palette.of(context);
    final l = AppLocalizations.of(context);
    final today = state.today;
    final due = state.dueCount;
    final total = state.words.length;
    final list = state.words.values.where((w) => _matches(w, today)).toList()
      ..sort((a, b) {
        final byAdded = b.added.compareTo(a.added);
        return byAdded != 0 ? byAdded : a.word.toLowerCase().compareTo(b.word.toLowerCase());
      });

    return SafeArea(
      bottom: false,
      child: FutureBuilder<Dictionary>(
        future: _dict,
        builder: (context, snap) {
          final dict = snap.data ?? const {};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l.wordsEyebrow,
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, letterSpacing: 1, fontSize: 12),
              ),
              Text(l.wordsTitle, style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  // Text above, button below: holds at any width and at large system text sizes.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        due > 0 ? l.wordsDue(due) : (total > 0 ? l.wordsAllCaughtUp : l.wordsNone),
                        key: const Key('words-summary'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(total > 0 ? l.wordsSavedSummary(total) : l.wordsEmptyHint, style: TextStyle(color: palette.muted, fontSize: 13)),
                      if (due > 0) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const Key('practice'),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PracticeScreen())),
                          child: Text(l.wordsPractice),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (total > 0)
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in WordFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8, top: 8),
                          child: FilterChip(
                            label: Text(switch (f) {
                              WordFilter.all => l.wordFilterAll,
                              WordFilter.due => l.wordFilterDue,
                              WordFilter.learning => l.wordFilterLearning,
                              WordFilter.mastered => l.wordFilterMastered,
                            }),
                            selected: _filter == f,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
              for (final w in list) _WordRow(word: w, entry: dict[w.key]),
            ],
          );
        },
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.word, required this.entry});
  final SavedWord word;
  final DictEntry? entry;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final palette = Palette.of(context);
    final l = AppLocalizations.of(context);
    final e = entry;
    return Padding(
      key: Key('word-${word.key}'),
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: l.wordsPronounce(word.word),
                icon: const Icon(Icons.volume_up_rounded),
                onPressed: () => scope.sayWord(e, word.word),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e?.display ?? word.word, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(e == null ? '—' : e.en.take(2).join(', '), style: TextStyle(color: palette.muted)),
                  ],
                ),
              ),
              Tooltip(
                message: l.wordsStrength(word.card.box),
                child: Row(
                  children: [
                    for (var n = 1; n <= 5; n++)
                      Container(
                        width: 6,
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: word.card.box >= n ? Theme.of(context).colorScheme.primary : palette.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.wordsRemove(word.word),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => scope.state.toggleWord(key: word.key, word: word.word, storyId: word.storyId, context: word.context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
