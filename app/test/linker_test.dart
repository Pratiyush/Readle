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

  // A capitalised word mid-sentence is a noun first: a verb or preposition spelled the same way
  // used to win ("die Schienen" linked to scheinen, "in der Nähe" to nähen, "von den Wegen" to
  // the preposition wegen). Found in the German-quality pass of 10 Nov.
  test('a capitalised word mid-sentence links to the noun, not a look-alike verb', () {
    String? key(String sentence, String word) {
      for (final t in linker.tokenise(sentence)) {
        if (t is List && t.first == word) return t.length > 1 ? t[1] as String : null;
      }
      fail('$word not in $sentence');
    }

    expect(key('Bei Regen werden die Schienen rutschig.', 'Schienen'), 'readle.schiene.n');
    expect(key('Neben den Zelten stehen Buden.', 'Zelten'), 'de.zelt.n');
    expect(key('Auf den Hängen wächst Wein.', 'Hängen'), 'readle.hang.n');
    expect(key('Der Schnee verschwindet von den Wegen.', 'Wegen'), 'de.weg.n');
    expect(key('Wir wohnen in der Nähe.', 'Nähe'), 'readle.nähe.n');
    expect(key('Es entstand eine Bibel in zwei Bänden.', 'Bänden'), 'readle.band.n');
    expect(key('Der Duft von Kaffee mischt sich mit der Luft.', 'Duft'), 'readle.duft.n');
    expect(key('Den letzten Schluck trinken wir am Ausgang.', 'Schluck'), 'readle.schluck.n');
    expect(key('Er schließt es an einem festen Bügel an.', 'Bügel'), 'readle.bügel.n');
    // Still right: an infinitive used as a noun keeps its verb, "Band" alone stays the ribbon,
    // and a pronoun after a colon is a pronoun.
    expect(key('Dann gibt es ein Brot im Stehen.', 'Stehen'), 'de.stehen.v');
    expect(key('Aus der Tasche hängt ein rotes Band.', 'Band'), 'de.band.n');
    expect(key('Der Kellner antwortet: Weil Sie ruhig sind.', 'Weil'), 'de.weil.x');
    expect(key('Dieses kurze und kräftige Lüften hat einen Namen.', 'Lüften'), 'de.lüften.v');
    expect(key('Der Hund sagt: „Komm herein!“', 'Komm'), 'de.kommen.v');
    expect(key('So entstehen Wörter mit vier Teilen.', 'Teilen'), 'de.teil.n');
    expect(key('Zwei kleine Striche am Rand waren er und seine Schwester.', 'Striche'), 'readle.strich.n');
    expect(key('Der Begriff verlangt Zeit.', 'Begriff'), 'readle.begriff.n');
  });

  test('a surname after Herr or Frau is a name, not the adjective', () {
    String? key(String sentence, String word) =>
        linker.tokenise(sentence).whereType<List>().firstWhere((t) => t.first == word).skip(1).firstOrNull as String?;
    expect(key('Im Restaurant bestellt Herr Klein eine Suppe.', 'Klein'), isNull);
    expect(key('Frau Lang übersetzt jeden Satz.', 'Lang'), isNull);
    expect(key('Das Haus ist klein.', 'klein'), 'de.klein.a');
    expect(key('An einer Bude verkauft eine Frau Käse und Wurst.', 'Käse'), 'de.käse.n', reason: 'Frau here is a woman');
  });
}
