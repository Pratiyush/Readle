import 'package:flutter/material.dart';

import '../content/models.dart';
import 'app_scope.dart';
import 'theme.dart';

const sessionSize = 20;

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final List<String> _queue;
  late final Future<Dictionary> _dict;
  int _index = 0;
  bool _flipped = false;
  int _right = 0;

  @override
  void initState() {
    super.initState();
    final scope = AppScope.read(context);
    final today = scope.state.today;
    // Snapshot the queue once: reviewing a card must not reshuffle the session.
    _queue = (scope.state.words.values.where((w) => w.card.isDue(today)).toList()
          ..sort((a, b) {
            final byBox = a.card.box.compareTo(b.card.box);
            return byBox != 0 ? byBox : a.card.due.compareTo(b.card.due);
          }))
        .take(sessionSize)
        .map((w) => w.key)
        .toList();
    _dict = scope.content.dictionary();
  }

  void _answer(String key, bool correct) {
    AppScope.read(context).state.reviewWord(key, correct: correct);
    setState(() {
      if (correct) _right++;
      _flipped = false;
      _index++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final palette = Palette.of(context);
    final current = _index < _queue.length ? scope.state.words[_queue[_index]] : null;

    if (current == null) {
      return Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 40),
            const Center(child: Text('✅', style: TextStyle(fontSize: 64))),
            Center(
              child: Text(_queue.isEmpty ? 'Nothing to review' : 'Session complete',
                  key: const Key('practice-done'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            ),
            if (_queue.isNotEmpty)
              Center(child: Text('$_right of ${_queue.length} remembered.', style: TextStyle(color: palette.muted))),
            const SizedBox(height: 24),
            FilledButton(key: const Key('back-to-words'), onPressed: () => Navigator.of(context).pop(), child: const Text('Back to words')),
          ]),
        ),
      );
    }

    return FutureBuilder<Dictionary>(
      future: _dict,
      builder: (context, snap) {
        final e = snap.data?[current.key];
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(tooltip: 'End practice', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            title: Text('${_index + 1} / ${_queue.length}', style: TextStyle(color: palette.muted, fontSize: 15)),
            centerTitle: true,
          ),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            Card(
              key: const Key('flashcard'),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(() => _flipped = true),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 260),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(e?.display ?? current.word,
                          key: const Key('fc-word'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 34, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (!_flipped)
                        Text('Do you remember it? Tap to reveal.', style: TextStyle(color: palette.muted))
                      else ...[
                        Text(e?.en.join(', ') ?? '(no dictionary entry)',
                            key: const Key('fc-gloss'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        if (e?.plural != null) Text('plural: die ${e!.plural}', style: TextStyle(color: palette.muted)),
                        const SizedBox(height: 12),
                        Text(current.context,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, color: palette.muted, fontSize: 16)),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
              onPressed: () => scope.sayWord(e, current.word),
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('Listen'),
            ),
            const SizedBox(height: 12),
            if (!_flipped)
              FilledButton(key: const Key('show-answer'), onPressed: () => setState(() => _flipped = true), child: const Text('Show answer'))
            else
              Row(children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('didnt-know'),
                    style: FilledButton.styleFrom(backgroundColor: palette.bad),
                    onPressed: () => _answer(current.key, false),
                    child: const Text("Didn't know"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('knew-it'),
                    style: FilledButton.styleFrom(backgroundColor: palette.good),
                    onPressed: () => _answer(current.key, true),
                    child: const Text('Knew it'),
                  ),
                ),
              ]),
          ]),
        );
      },
    );
  }
}
