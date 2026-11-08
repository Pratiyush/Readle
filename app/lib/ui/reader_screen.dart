import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../content/models.dart';
import 'app_scope.dart';
import 'quiz_screen.dart';
import 'theme.dart';
import 'word_sheet.dart';

const _scales = [0.9, 1.0, 1.15, 1.3, 1.5];

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.storyId});
  final String storyId;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<(Story, Dictionary)> _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final content = AppScope.read(context).content;
    _data = Future.wait([content.story(widget.storyId), content.dictionary()])
        .then((r) => (r[0] as Story, r[1] as Dictionary));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(Story, Dictionary)>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text("This story couldn't be loaded."),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to stories')),
                ]),
              ),
            );
          }
          if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return _ReaderView(story: snap.data!.$1, dict: snap.data!.$2);
        },
      );
}

class _ReaderView extends StatefulWidget {
  const _ReaderView({required this.story, required this.dict});
  final Story story;
  final Dictionary dict;

  @override
  State<_ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<_ReaderView> {
  final _scroll = ScrollController();
  final _shown = <int>{};
  bool _allShown = false;
  int? _playing;
  int _playToken = 0;
  double _progress = 0;
  bool _canSpeak = false;
  late final AppScope _scope;

  // One recognizer per word token and per ⇄, made once and disposed with the screen.
  late final List<List<TapGestureRecognizer?>> _wordTaps;
  late final List<TapGestureRecognizer> _translateTaps;

  Story get story => widget.story;

  @override
  void initState() {
    super.initState();
    _scope = AppScope.read(context);
    _wordTaps = [
      for (final s in story.sentences)
        [for (final t in s.tokens) t.isWord ? (TapGestureRecognizer()..onTap = () => _openWord(t, s)) : null],
    ];
    _translateTaps = [
      for (var i = 0; i < story.sentences.length; i++) TapGestureRecognizer()..onTap = () => _toggle(i),
    ];
    _scroll.addListener(() {
      final max = _scroll.position.maxScrollExtent;
      final p = max > 0 ? (_scroll.offset / max).clamp(0.0, 1.0) : 1.0;
      if ((p - _progress).abs() > 0.01) setState(() => _progress = p);
    });
    _scope.speech.available().then((ok) {
      if (mounted) setState(() => _canSpeak = ok);
    });
  }

  @override
  void dispose() {
    // Leaving must silence the reader: bump the token first, since stopping completes the
    // pending utterance and the loop would otherwise go on to the next sentence.
    _playToken++;
    _scope.speech.stop();
    for (final row in _wordTaps) {
      for (final r in row) {
        r?.dispose();
      }
    }
    for (final r in _translateTaps) {
      r.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _toggle(int i) => setState(() => _shown.contains(i) ? _shown.remove(i) : _shown.add(i));

  void _openWord(Token t, Sentence s) {
    if (_playing != null) _stop(); // the word's own audio replaces the story reading
    final key = t.key;
    showWordSheet(
      context,
      word: t.text,
      dictKey: key,
      entry: key == null ? null : widget.dict[key],
      compound: t.compound,
      sentence: s,
      storyId: story.id,
    );
  }

  Future<void> _play(int from) async {
    final speech = _scope.speech;
    await speech.stop();
    final token = ++_playToken;
    for (var i = from; i < story.sentences.length; i++) {
      if (!mounted || token != _playToken) return;
      setState(() => _playing = i);
      _scope.state.setProgress(story.id, i);
      _follow(i);
      await speech.speak(story.sentences[i].de, rate: _scope.state.settings.speechRate);
    }
    if (mounted && token == _playToken) setState(() => _playing = null);
  }

  void _stop() {
    _playToken++;
    _scope.speech.stop();
    setState(() => _playing = null);
  }

  /// Keep the sentence being read roughly in view.
  void _follow(int i) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final target = (max * i / story.sentences.length).clamp(0.0, max);
    if ((target - _scroll.offset).abs() > 120) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  void _cycleFont() {
    final settings = _scope.state.settings;
    final i = _scales.indexOf(settings.fontScale);
    _scope.state.updateSettings(settings.copyWith(fontScale: _scales[(i + 1) % _scales.length]));
  }

  void _finish() {
    _stop();
    _scope.state
      ..finishStory(story.id)
      ..setProgress(story.id, story.sentences.length - 1);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => QuizScreen(storyId: story.id)));
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final state = scope.state;
    final palette = Palette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final image = scope.content.image(story.meta.image);
    final isRead = state.read.containsKey(story.id);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('reader-back'),
          tooltip: 'Back to stories',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_canSpeak)
            IconButton(
              key: const Key('listen'),
              tooltip: _playing == null ? 'Listen' : 'Stop',
              icon: Icon(_playing == null ? Icons.play_arrow_rounded : Icons.stop_rounded),
              onPressed: () => _playing == null ? _play(0) : _stop(),
            ),
          TextButton(
            key: const Key('show-all-translations'),
            onPressed: () => setState(() => _allShown = !_allShown),
            style: TextButton.styleFrom(
              backgroundColor: _allShown ? palette.accentSoft : null,
              foregroundColor: scheme.onSurface,
            ),
            child: const Text('EN', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          TextButton(
            key: const Key('text-size'),
            onPressed: _cycleFont,
            style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
            child: const Text('Aa', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(value: _progress, minHeight: 3, backgroundColor: Colors.transparent),
        ),
      ),
      body: ListView(
        key: const Key('reader-list'),
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (image != null) Image(image: ResizeImage(image, width: 1200), height: 200, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    LevelBadge(story.meta.level),
                    const SizedBox(width: 8),
                    Text('${story.meta.minutes} min read · ${story.meta.words} words', style: TextStyle(color: palette.muted, fontSize: 13)),
                  ]),
                  const SizedBox(height: 8),
                  Text(story.meta.title,
                      style: const TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 30, fontWeight: FontWeight.w700, height: 1.15)),
                  const SizedBox(height: 6),
                  Text('Tap any word for its meaning. Tap ⇄ for a sentence translation.', style: TextStyle(color: palette.muted, fontSize: 13)),
                  const SizedBox(height: 14),
                  ..._storyText(context, state.words.keys.toSet(), state.settings.fontScale),
                  const SizedBox(height: 28),
                  FilledButton(key: const Key('finish'), onPressed: _finish, child: Text(isRead ? 'Take the quiz again' : 'Finish & take the quiz')),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Back to stories'),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The story as flowing paragraphs: sentences run on inline, and a shown translation breaks the
  /// flow with a block under its sentence. Plain text spans keep punctuation with its word.
  List<Widget> _storyText(BuildContext context, Set<String> saved, double scale) {
    final palette = Palette.of(context);
    final base = TextStyle(
      fontFamily: serif,
      fontFamilyFallback: serifFallback,
      fontSize: 20 * scale,
      height: 1.85,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final out = <Widget>[];
    var run = <InlineSpan>[];

    void flush() {
      if (run.isEmpty) return;
      out.add(Text.rich(TextSpan(style: base, children: run), key: ValueKey('para-${out.length}')));
      run = [];
    }

    for (var i = 0; i < story.sentences.length; i++) {
      final s = story.sentences[i];
      final spans = <InlineSpan>[];
      for (var j = 0; j < s.tokens.length; j++) {
        final t = s.tokens[j];
        if (!t.isWord) {
          spans.add(TextSpan(text: t.text));
          continue;
        }
        final isSaved = (t.key != null && saved.contains(t.key)) || saved.contains('free:${t.text.toLowerCase()}');
        spans.add(TextSpan(
          text: t.text,
          recognizer: _wordTaps[i][j],
          style: isSaved ? TextStyle(backgroundColor: palette.saved) : null,
        ));
      }
      spans.add(const TextSpan(text: ' '));
      spans.add(TextSpan(
        text: '⇄',
        recognizer: _translateTaps[i],
        semanticsLabel: 'Translate sentence ${i + 1}',
        style: TextStyle(color: palette.muted, fontSize: 15 * scale, fontFamily: null),
      ));
      spans.add(const TextSpan(text: ' '));
      run.add(TextSpan(style: _playing == i ? TextStyle(backgroundColor: palette.accentSoft) : null, children: spans));

      if (_allShown || _shown.contains(i)) {
        flush();
        out.add(Container(
          key: Key('translation-$i'),
          width: double.infinity,
          margin: const EdgeInsets.only(top: 2, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3)),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
          ),
          child: Text(s.en, style: TextStyle(color: palette.muted, fontSize: 15 * scale, height: 1.45)),
        ));
      }
    }
    flush();
    return out;
  }
}
