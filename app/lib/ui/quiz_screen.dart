import 'package:flutter/material.dart';

import '../content/models.dart';
import '../logic/quiz.dart';
import 'app_scope.dart';
import 'theme.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.storyId});
  final String storyId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<(Story, List<Question>)> _data;
  int _index = 0;
  int? _chosen;
  int _correct = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final content = AppScope.read(context).content;
    // A fresh seed per visit, so retaking the quiz isn't a memory test of the last attempt.
    final seed = '${widget.storyId}:${DateTime.now().microsecondsSinceEpoch}';
    _data = Future.wait([content.story(widget.storyId), content.dictionary()]).then((r) {
      final story = r[0] as Story;
      return (story, buildQuiz(story, r[1] as Dictionary, seed: seed));
    });
  }

  void _choose(Question q, int i, int total, String storyId) {
    if (_chosen != null) return;
    final right = i == q.answer;
    setState(() {
      _chosen = i;
      if (right) _correct++;
    });
    if (_index == total - 1) AppScope.read(context).state.recordQuiz(storyId, _correct / total);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(Story, List<Question>)>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text("Couldn't load the quiz.")),
        );
      }
      if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final (story, questions) = snap.data!;
      if (_index >= questions.length) return _results(context, story, questions.length);
      return _question(context, story, questions);
    },
  );

  Widget _question(BuildContext context, Story story, List<Question> questions) {
    final q = questions[_index];
    final palette = Palette.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Close quiz', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < questions.length; i++)
              Container(
                width: i == _index ? 22 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: i <= _index ? scheme.primary : palette.line, borderRadius: BorderRadius.circular(4)),
              ),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            q.kind == QuestionKind.word ? 'WHAT DOES THIS WORD MEAN?' : 'WHAT DOES THIS SENTENCE MEAN?',
            key: const Key('quiz-eyebrow'),
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            q.prompt,
            key: const Key('quiz-prompt'),
            style: TextStyle(
              fontFamily: serif,
              fontFamilyFallback: serifFallback,
              fontSize: q.kind == QuestionKind.word ? 34 : 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (q.context != null) ...[
            const SizedBox(height: 6),
            Text(
              '“${q.context}”',
              style: TextStyle(color: palette.muted, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 20),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Option(
                key: Key('option-$i'),
                text: q.options[i],
                state: _chosen == null
                    ? _OptionState.open
                    : i == q.answer
                    ? _OptionState.right
                    : i == _chosen
                    ? _OptionState.wrong
                    : _OptionState.dimmed,
                onTap: () => _choose(q, i, questions.length, story.id),
              ),
            ),
          if (_chosen != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _chosen == q.answer ? palette.goodSoft : palette.badSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _chosen == q.answer ? 'Richtig!' : 'Not quite.',
                      key: const Key('feedback'),
                      style: TextStyle(fontWeight: FontWeight.w800, color: _chosen == q.answer ? palette.good : palette.bad),
                    ),
                  ),
                  FilledButton(
                    key: const Key('continue'),
                    style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
                    onPressed: () => setState(() {
                      _chosen = null;
                      _index++;
                    }),
                    child: Text(_index == questions.length - 1 ? 'See results' : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _results(BuildContext context, Story story, int total) {
    final state = AppScope.of(context).state;
    final palette = Palette.of(context);
    final pct = total == 0 ? 100 : (100 * _correct / total).round();
    final (emoji, headline) = praise(pct);
    Widget stat(String value, String label) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              Text(label, style: TextStyle(color: palette.muted)),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Center(child: Text(emoji, style: const TextStyle(fontSize: 64))),
            const SizedBox(height: 8),
            Center(
              child: Text(
                headline,
                key: const Key('result-headline'),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text('You finished “${story.meta.title}”.', style: TextStyle(color: palette.muted)),
            ),
            const SizedBox(height: 20),
            Row(children: [stat('$pct%', 'quiz score'), const SizedBox(width: 12), stat('🔥 ${state.streakDays}', 'day streak')]),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('next-story'),
              onPressed: () async {
                // The natural break after a finished story: the only place an interstitial may show.
                await AppScope.read(context).ads.storyFinished();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Next story'),
            ),
            const SizedBox(height: 10),
            if (pct < 80)
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
                onPressed: () => setState(() {
                  _index = 0;
                  _correct = 0;
                  _chosen = null;
                }),
                child: const Text('Try the quiz again'),
              ),
          ],
        ),
      ),
    );
  }
}

enum _OptionState { open, right, wrong, dimmed }

class _Option extends StatelessWidget {
  const _Option({super.key, required this.text, required this.state, required this.onTap});
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final (bg, border) = switch (state) {
      _OptionState.right => (palette.goodSoft, palette.good),
      _OptionState.wrong => (palette.badSoft, palette.bad),
      _ => (Theme.of(context).colorScheme.surface, palette.line),
    };
    return Opacity(
      opacity: state == _OptionState.dimmed ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: state == _OptionState.open ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
