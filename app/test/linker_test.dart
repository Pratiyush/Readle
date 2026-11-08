// The runtime linker must link exactly like tools/build_content.py: every bundled story is
// re-linked from its plain sentences and compared token for token with the builder's output.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readle/content/linker.dart';

void main() {
  final linker = Linker.fromJson(jsonDecode(File('assets/linker/linker.json').readAsStringSync()) as Map<String, dynamic>);

  test('reproduces the builder\'s links in all 107 bundled stories', () {
    final files = Directory('assets/content/stories').listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    var stories = 0, tokens = 0;
    final diffs = <String>[];
    for (final file in files) {
      final story = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      stories++;
      for (final s in story['sentences'] as List) {
        final expected = jsonEncode(s['t']);
        final actual = jsonEncode(linker.tokenise(s['de'] as String));
        tokens += (s['t'] as List).whereType<List>().length;
        if (actual != expected && diffs.length < 5) diffs.add('${story['id']}: ${s['de']}\n  builder $expected\n  linker  $actual');
      }
    }
    expect(stories, 107);
    expect(tokens, greaterThan(10000));
    expect(diffs, isEmpty, reason: diffs.join('\n'));
  });

  test('inflected forms, nouns vs verbs, compounds and names', () {
    String? key(String w, {bool first = false}) => linker.resolve(w, sentenceInitial: first).$1;
    expect(key('gibt'), 'de.geben.v');
    expect(key('Brote'), 'de.brot.n');
    expect(linker.resolve('Haustür', sentenceInitial: false), ('de.tür.n', true));
    expect(key('Deutschland'), isNull);
    expect(linker.tokenise('Es gibt Brot.'), [
      ['Es', 'de.es.a'],
      ' ',
      ['gibt', 'de.geben.v'],
      ' ',
      ['Brot', 'de.brot.n'],
      '.',
    ]);
  });
}
