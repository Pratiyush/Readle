import 'package:flutter/material.dart';

import '../content/models.dart';
import 'app_scope.dart';
import 'theme.dart';

Future<void> showWordSheet(
  BuildContext context, {
  required String word,
  required String? dictKey,
  required DictEntry? entry,
  required bool compound,
  required Sentence sentence,
  required String storyId,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) => _WordSheet(
        word: word,
        saveKey: dictKey ?? 'free:${word.toLowerCase()}',
        entry: entry,
        compound: compound,
        sentence: sentence,
        storyId: storyId,
      ),
    );

class _WordSheet extends StatefulWidget {
  const _WordSheet({
    required this.word,
    required this.saveKey,
    required this.entry,
    required this.compound,
    required this.sentence,
    required this.storyId,
  });

  final String word;
  final String saveKey;
  final DictEntry? entry;
  final bool compound;
  final Sentence sentence;
  final String storyId;

  @override
  State<_WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<_WordSheet> {
  late final AppScope _scope;

  String get word => widget.word;
  String get saveKey => widget.saveKey;
  DictEntry? get entry => widget.entry;
  bool get compound => widget.compound;
  Sentence get sentence => widget.sentence;
  String get storyId => widget.storyId;

  @override
  void initState() {
    super.initState();
    _scope = AppScope.read(context);
    // Tapping a word says it, like a dictionary pen; the setting turns that off.
    if (_scope.state.settings.autoPlayWords) _scope.sayWord(entry, word);
  }

  @override
  void dispose() {
    _scope.player.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final state = scope.state;
    final palette = Palette.of(context);
    final e = entry;
    final saved = state.isSaved(saveKey);
    final bold = const TextStyle(fontWeight: FontWeight.w700);

    Widget note(List<InlineSpan> spans) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: palette.surface2, borderRadius: BorderRadius.circular(10)),
          child: Text.rich(TextSpan(children: spans)),
        );

    Widget box(List<Widget> children, {String? eyebrow}) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: palette.line), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (eyebrow != null)
              Text(eyebrow, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ...children,
          ]),
        );

    return SingleChildScrollView(
      key: const Key('word-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: Text(e?.display ?? word,
                key: const Key('headword'),
                style: const TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 28, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'Pronounce',
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: () => scope.sayWord(e, word),
          ),
          IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        ]),
        if (e != null)
          Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (e.ipa != null) Text('/${e.ipa}/', style: TextStyle(color: palette.muted)),
            Text(e.pos, style: TextStyle(color: palette.muted)),
            if (e.plural != null) Text('· plural: die ${e.plural}', style: TextStyle(color: palette.muted)),
            if (e.cefr != null) LevelBadge(e.cefr!),
          ]),
        if (e == null)
          note([const TextSpan(text: 'No dictionary entry for this word (often a name). The sentence translation below should help.')])
        else ...[
          if (compound)
            note([
              TextSpan(text: word, style: bold),
              const TextSpan(text: ' is a compound — this is the meaning of its last part, '),
              TextSpan(text: e.headword, style: bold),
              const TextSpan(text: '.'),
            ])
          else if (word.toLowerCase() != e.headword.toLowerCase())
            note([
              TextSpan(text: word, style: bold),
              const TextSpan(text: ' is a form of '),
              TextSpan(text: e.headword, style: bold),
              const TextSpan(text: '.'),
            ]),
          const SizedBox(height: 10),
          for (final g in e.en)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('•  $g', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          if (e.exampleDe != null)
            box([
              Text(e.exampleDe!, style: const TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 16)),
              if (e.exampleEn != null) Text(e.exampleEn!, style: TextStyle(color: palette.muted)),
            ]),
        ],
        box(eyebrow: 'IN THIS STORY', [
          const SizedBox(height: 4),
          Text(sentence.de, style: const TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 16)),
          Text(sentence.en, style: TextStyle(color: palette.muted)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: saved
              ? OutlinedButton(
                  key: const Key('save-word'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
                  onPressed: () => state.toggleWord(key: saveKey, word: e?.headword ?? word, storyId: storyId, context: sentence.de),
                  child: const Text('✓ Saved to your words'),
                )
              : FilledButton(
                  key: const Key('save-word'),
                  onPressed: () => state.toggleWord(key: saveKey, word: e?.headword ?? word, storyId: storyId, context: sentence.de),
                  child: const Text('＋ Save to my words'),
                ),
        ),
      ]),
    );
  }
}
