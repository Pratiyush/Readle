import 'package:flutter_test/flutter_test.dart';
import 'package:readle/content/models.dart';
import 'package:readle/ui/library_screen.dart';

StoryMeta story(String id, String level) => StoryMeta(
    id: id, title: id, level: level, collection: 'fiction', publishedAt: '2026-11-01', image: null,
    teaser: '', teaserEn: '', words: 50, minutes: 1);

void main() {
  final lib = [story('b2', 'B2'), story('a2a', 'A2'), story('a1a', 'A1'), story('a1b', 'A1'), story('b1', 'B1')];

  test('all levels go in sequence: A1 first, then A2 once A1 is read', () {
    for (final day in ['2026-11-09', '2026-11-10', '2026-11-11', '2026-11-12']) {
      expect(storyOfTheDay(lib, 'all', {}, day)!.level, 'A1');
    }
    expect(storyOfTheDay(lib, 'all', {'a1a': 'd', 'a1b': 'd'}, '2026-11-09')!.id, 'a2a');
    expect(storyOfTheDay(lib, 'all', {'a1a': 'd', 'a1b': 'd', 'a2a': 'd'}, '2026-11-09')!.id, 'b1');
  });

  test('a chosen level stays within it', () {
    expect(storyOfTheDay(lib, 'B2', {}, '2026-11-09')!.id, 'b2');
  });

  test('offers a read story again once everything is read', () {
    expect(storyOfTheDay(lib, 'all', {for (final s in lib) s.id: 'd'}, '2026-11-09'), isNotNull);
  });
}
