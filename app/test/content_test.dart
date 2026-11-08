import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readle/content/content_repository.dart';
import 'package:readle/content/models.dart';
import 'package:readle/logic/quiz.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = AssetContentRepository(bundle: rootBundle, decodeInIsolate: false);
  late List<StoryMeta> library;
  late Dictionary dict;
  late List<Story> stories;

  setUpAll(() async {
    library = await repo.library();
    dict = await repo.dictionary();
    stories = await Future.wait(library.map((m) => repo.story(m.id)));
  });

  test('has stories at every level', () {
    expect(library.length, greaterThan(50));
    for (final l in levels) {
      expect(library.any((s) => s.level == l), isTrue, reason: l);
    }
  });

  test('tokens reassemble each sentence and link only to real entries', () {
    for (final story in stories) {
      for (final s in story.sentences) {
        expect(s.tokens.map((t) => t.text).join(), s.de, reason: story.id);
        for (final t in s.tokens.where((t) => t.key != null)) {
          expect(dict.containsKey(t.key), isTrue, reason: '${story.id}: ${t.key}');
        }
      }
    }
  });

  test('every story yields a solvable quiz with same-part-of-speech distractors', () {
    final posOf = <String, Set<String>>{};
    for (final e in dict.values) {
      (posOf[e.gloss] ??= {}).add(e.pos);
    }
    for (final story in stories) {
      final qs = buildQuiz(story, dict);
      expect(qs.length, greaterThanOrEqualTo(3), reason: story.id);
      for (final q in qs) {
        expect(q.answer, inInclusiveRange(0, q.options.length - 1));
        expect(q.options.toSet().length, q.options.length, reason: story.id);
        if (q.kind == QuestionKind.word) {
          final shared = q.options.map((o) => posOf[o]!).reduce((a, b) => a.intersection(b));
          expect(shared, isNotEmpty, reason: '${story.id}: ${q.prompt} → ${q.options}');
        }
      }
    }
  });

  test('a seed reproduces the same quiz', () {
    final a = buildQuiz(stories.first, dict, seed: 'x');
    final b = buildQuiz(stories.first, dict, seed: 'x');
    expect(a.map((q) => q.options), b.map((q) => q.options));
  });

  test('names are not linked through a compound tail', () async {
    final brot = await repo.story('brot');
    final deutschland = brot.sentences.first.tokens.firstWhere((t) => t.text == 'Deutschland');
    expect(deutschland.key, isNull);
  });
}
