/// Links a story's words to dictionary keys at runtime, by exactly the rules
/// `tools/build_content.py` applies to the bundled stories. The builder writes its tables to
/// `assets/linker/linker.json`, and `test/linker_test.dart` checks that this class reproduces
/// every bundled story's links token for token, so the two cannot drift apart unnoticed.
///
/// Stories downloaded from the content CDN carry plain sentences only; this is what makes their
/// words tappable.
class Linker {
  Linker._(
    this._lex,
    this._index,
    this._aliases,
    List<String> adjEndings,
    List<String> nounEndings,
    this._notCompounds,
    this._posRank,
    this._nameTitles,
    this._pluralCues,
    this._sentenceStarts,
  ) : _endings = [...adjEndings, ...nounEndings];

  factory Linker.fromJson(Map<String, dynamic> j) {
    if (j['schema'] != 'readle/linker@2') throw FormatException('linker schema ${j['schema']}');
    return Linker._(
      {
        for (final e in (j['lex'] as Map<String, dynamic>).entries)
          e.key: ((e.value as List)[0] as String, (e.value as List)[1] as int, (e.value as List)[2] as String),
      },
      {for (final e in (j['index'] as Map<String, dynamic>).entries) e.key: (e.value as List).cast<String>()},
      (j['aliases'] as Map<String, dynamic>).cast<String, String>(),
      (j['adjEndings'] as List).cast<String>(),
      (j['nounEndings'] as List).cast<String>(),
      (j['notCompounds'] as List).cast<String>().toSet(),
      (j['posRank'] as Map<String, dynamic>).cast<String, int>(),
      (j['nameTitles'] as List).cast<String>().toSet(),
      (j['pluralCues'] as List).cast<String>().toSet(),
      j['sentenceStarts'] as String,
    );
  }

  final Map<String, (String, int, String)> _lex; // id → (part of speech, frequency rank, lowercase headword)
  final Map<String, List<String>> _index; // lowercase surface form → candidate ids
  final Map<String, String> _aliases; // inflected form → lemma
  final List<String> _endings;
  final Set<String> _notCompounds;

  /// A capitalised word right after these is a surname (Herr Klein), not the adjective.
  final Set<String> _nameTitles;

  /// Words before a plural noun: after them "Hängen" is der Hang, not the infinitive.
  final Set<String> _pluralCues;

  /// A word after any of these characters starts a sentence (direct speech, after a colon).
  final String _sentenceStarts;
  final Map<String, int> _posRank;

  /// The builder's TOKEN_RE (`[^\W\d_]+(?:-[^\W\d_]+)*`): runs of letters, hyphen-joined.
  static final tokenRe = RegExp(r'[\p{L}\p{Nl}\p{No}]+(?:-[\p{L}\p{Nl}\p{No}]+)*', unicode: true);

  /// Tokens in the bundled story format: text between words as plain strings, each word as
  /// `[word]` (no entry), `[word, key]`, or `[word, key, 1]` (linked through its head noun).
  List<Object> tokenise(String text) {
    final tokens = <Object>[];
    var pos = 0;
    var first = true;
    var prev = '';
    for (final m in tokenRe.allMatches(text)) {
      if (m.start > pos) tokens.add(text.substring(pos, m.start));
      final word = m.group(0)!;
      final gap = text.substring(pos, m.start);
      if (_sentenceStarts.split('').any(gap.contains)) first = true;
      final (id, compound) = resolve(word, sentenceInitial: first, prev: prev);
      first = false;
      prev = word;
      tokens.add(id == null ? [word] : (compound ? [word, id, 1] : [word, id]));
      pos = m.end;
    }
    if (pos < text.length) tokens.add(text.substring(pos));
    return tokens;
  }

  /// The dictionary key for [word] and whether it was reached through a compound's head noun.
  (String?, bool) resolve(String word, {required bool sentenceInitial, String prev = ''}) {
    final low = word.toLowerCase();
    final upperFirst = _isUpper(word);
    final capitalised = upperFirst && !sentenceInitial;
    final candidates = [low];
    final alias = _aliases[low];
    if (alias != null) candidates.add(alias);
    for (final end in _endings) {
      if (low.endsWith(end) && low.length - end.length >= 3) candidates.add(low.substring(0, low.length - end.length));
    }
    // comparatives: schöner → schön, größer → groß
    if (low.endsWith('er') && low.length > 5) {
      candidates.add(low.substring(0, low.length - 2).replaceAll('ä', 'a').replaceAll('ö', 'o').replaceAll('ü', 'u'));
    }
    // past participles of weak verbs: gemacht → machen
    if (low.startsWith('ge') && low.endsWith('t') && low.length > 5) {
      candidates.add('${low.substring(2, low.length - 1)}en');
    }
    if (capitalised) {
      // Capitalised mid-sentence: a noun from any candidate form wins over a look-alike verb or
      // preposition (die Schienen ≠ schienen of scheinen, von den Wegen ≠ wegen), except an
      // infinitive used as a noun (das Lüften), unless a plural cue comes first.
      final infinitive =
          !_pluralCues.contains(prev.toLowerCase()) &&
          (_index[low] ?? const <String>[]).any((id) => _lex[id]?.$1 == 'verb' && _lex[id]?.$3 == low);
      if (!infinitive) {
        for (final cand in candidates) {
          final nouns = [
            for (final id in _index[cand] ?? const <String>[])
              if (_lex[id]?.$1 == 'noun') id,
          ];
          if (nouns.isNotEmpty) return (_pick(nouns, true), false);
        }
      }
      if (_nameTitles.contains(prev.toLowerCase())) return (null, false); // a surname: Herr Klein
    }
    for (final cand in candidates) {
      var ids = _index[cand] ?? const <String>[];
      // German nouns are always capitalised: "weg" is never "Weg".
      if (!upperFirst) {
        ids = [
          for (final id in ids)
            if (_lex[id]?.$1 != 'noun') id,
        ];
      }
      if (capitalised) {
        // No noun: a verb only as its own infinitive used as a noun (das Essen, im Stehen).
        ids = [
          for (final id in ids)
            if (_lex[id]?.$1 != 'verb' || _lex[id]?.$3 == low) id,
        ];
      }
      if (ids.isNotEmpty) return (_pick(ids, capitalised), false);
    }
    // compound nouns: resolve the head (Haustür → Tür)
    if (upperFirst && low.length > 6 && !_notCompounds.contains(low)) {
      for (var i = 3; i < low.length - 2; i++) {
        if (!_isModifier(low.substring(0, i))) continue;
        final tail = low.substring(i);
        final ids = _index[tail] ?? _index[_aliases[tail] ?? ''];
        if (ids == null) continue;
        final nouns = [
          for (final id in ids)
            if (_lex[id]?.$1 == 'noun') id,
        ];
        if (nouns.isNotEmpty) return (_pick(nouns, true), true);
      }
    }
    return (null, false);
  }

  /// Python's `min` over (pos mismatch, POS rank, frequency rank); the first wins a tie.
  String _pick(List<String> ids, bool capitalised) {
    (int, int, int) score(String id) {
      final (pos, rank, _) = _lex[id] ?? ('other', 99999, '');
      return ((pos == 'noun') == capitalised ? 0 : 1, _posRank[pos] ?? 3, rank);
    }

    var best = ids.first;
    var bestScore = score(best);
    for (final id in ids.skip(1)) {
      final s = score(id);
      if (s.$1 < bestScore.$1 || (s.$1 == bestScore.$1 && (s.$2 < bestScore.$2 || (s.$2 == bestScore.$2 && s.$3 < bestScore.$3)))) {
        best = id;
        bestScore = s;
      }
    }
    return best;
  }

  /// The front part of a compound must itself be a word (Haus-tür, Küchen-tisch, Königs-haus).
  bool _isModifier(String head) {
    final forms = {head, '${head}e', '${head}en'};
    for (final link in const ['s', 'es', 'n', 'en', 'e', 'er']) {
      if (head.endsWith(link) && head.length - link.length >= 3) forms.add(head.substring(0, head.length - link.length));
    }
    return forms.any(_index.containsKey);
  }

  /// Python's `word[:1].isupper()`.
  static bool _isUpper(String word) {
    if (word.isEmpty) return false;
    final c = String.fromCharCode(word.runes.first);
    return c != c.toLowerCase() && c == c.toUpperCase();
  }
}
