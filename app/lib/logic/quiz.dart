import 'dart:math';

import '../content/models.dart';

enum QuestionKind { word, sentence }

class Question {
  const Question({required this.kind, required this.prompt, this.context, required this.options, required this.answer});
  final QuestionKind kind;
  final String prompt;
  final String? context;
  final List<String> options;
  final int answer;
}

const _contentPos = {'noun', 'verb', 'adjective', 'adverb'};
const _cefr = ['A1', 'A2', 'B1', 'B2', 'C1'];

/// A stable integer seed from a string (FNV-1a), so a story's quiz can be reproduced in tests.
int seedOf(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

List<T> _shuffled<T>(Iterable<T> xs, Random rand) => xs.toList()..shuffle(rand);

({List<String> options, int answer}) _withDistractors(String correct, Iterable<String> pool, Random rand) {
  final others = _shuffled(pool.where((p) => p != correct).toSet(), rand).take(3);
  final options = _shuffled([correct, ...others], rand);
  return (options: options, answer: options.indexOf(correct));
}

/// Up to three vocabulary questions (rarer content words first, distractors of the same part of
/// speech so the article can't give the answer away) and two "which translation" questions.
List<Question> buildQuiz(Story story, Dictionary dict, {String? seed}) {
  final rand = Random(seedOf(seed ?? story.id));
  final questions = <Question>[];

  final seen = <String, String>{}; // dictionary key → sentence it appears in
  for (final s in story.sentences) {
    for (final t in s.tokens) {
      final key = t.key;
      if (!t.isWord || key == null || t.compound || seen.containsKey(key)) continue;
      final e = dict[key];
      if (e != null && _contentPos.contains(e.pos) && e.headword.length > 3) seen[key] = s.de;
    }
  }
  final keys = seen.keys.toList();
  final ranked = _shuffled(keys, rand)..sort((a, b) => _cefr.indexOf(dict[b]!.cefr ?? '').compareTo(_cefr.indexOf(dict[a]!.cefr ?? '')));
  final pool = dict.values.where((e) => _contentPos.contains(e.pos)).toList();

  for (final key in ranked.take(3)) {
    final e = dict[key]!;
    final candidates = [
      ...keys.map((k) => dict[k]!).where((x) => x.pos == e.pos),
      ...pool.where((x) => x.pos == e.pos).take(200),
    ].map((x) => x.gloss);
    final q = _withDistractors(e.gloss, candidates, rand);
    if (q.options.length < 2) continue;
    questions.add(Question(kind: QuestionKind.word, prompt: e.display, context: seen[key], options: q.options, answer: q.answer));
  }

  if (story.sentences.length >= 4) {
    final picks = _shuffled(List.generate(story.sentences.length, (i) => i), rand).take(2);
    for (final i in picks) {
      final s = story.sentences[i];
      final q = _withDistractors(s.en, story.sentences.map((x) => x.en), rand);
      questions.add(Question(kind: QuestionKind.sentence, prompt: s.de, options: q.options, answer: q.answer));
    }
  }
  return questions;
}

/// Praise that matches the score ("Gut gemacht! 🎉" at 20 % read as a joke). Same tiers as the web.
(String, String) praise(int pct) => switch (pct) {
  >= 80 => ('🎉', 'Gut gemacht!'),
  >= 50 => ('👍', 'Nicht schlecht!'),
  _ => ('📖', 'Weiter so!'),
};
