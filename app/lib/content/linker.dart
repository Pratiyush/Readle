/// Links a story's words to dictionary keys at runtime, by exactly the rules
/// `tools/build_content.py` applies to the bundled stories. The builder writes its tables to
/// `assets/linker/linker.json`, and `test/linker_test.dart` checks that this class reproduces
/// every bundled story's links token for token, so the two cannot drift apart unnoticed.
///
/// Stories downloaded from the content CDN carry plain sentences only; this is what makes their
/// words tappable.
class Linker {
  Linker._(this._lex, this._index, this._aliases, List<String> adjEndings, List<String> nounEndings, this._notCompounds, this._posRank)
    : _endings = [...adjEndings, ...nounEndings];

  factory Linker.fromJson(Map<String, dynamic> j) {
    if (j['schema'] != 'readle/linker@1') throw FormatException('linker schema ${j['schema']}');
    return Linker._(
      {for (final e in (j['lex'] as Map<String, dynamic>).entries) e.key: ((e.value as List)[0] as String, (e.value as List)[1] as int)},
      {for (final e in (j['index'] as Map<String, dynamic>).entries) e.key: (e.value as List).cast<String>()},
      (j['aliases'] as Map<String, dynamic>).cast<String, String>(),
      (j['adjEndings'] as List).cast<String>(),
      (j['nounEndings'] as List).cast<String>(),
      (j['notCompounds'] as List).cast<String>().toSet(),
      (j['posRank'] as Map<String, dynamic>).cast<String, int>(),
    );
  }

  final Map<String, (String, int)> _lex; // id → (part of speech, frequency rank)
  final Map<String, List<String>> _index; // lowercase surface form → candidate ids
  final Map<String, String> _aliases; // inflected form → lemma
  final List<String> _endings;
  final Set<String> _notCompounds;
  final Map<String, int> _posRank;

  /// The builder's TOKEN_RE (`[^\W\d_]+(?:-[^\W\d_]+)*`): runs of letters, hyphen-joined.
  static final tokenRe = RegExp(r'[\p{L}\p{Nl}\p{No}]+(?:-[\p{L}\p{Nl}\p{No}]+)*', unicode: true);

  /// Tokens in the bundled story format: text between words as plain strings, each word as
  /// `[word]` (no entry), `[word, key]`, or `[word, key, 1]` (linked through its head noun).
  List<Object> tokenise(String text) {
    final tokens = <Object>[];
    var pos = 0;
    var first = true;
    for (final m in tokenRe.allMatches(text)) {
      if (m.start > pos) tokens.add(text.substring(pos, m.start));
      final word = m.group(0)!;
      final (id, compound) = resolve(word, sentenceInitial: first);
      first = false;
      tokens.add(id == null ? [word] : (compound ? [word, id, 1] : [word, id]));
      pos = m.end;
    }
    if (pos < text.length) tokens.add(text.substring(pos));
    return tokens;
  }

  /// The dictionary key for [word] and whether it was reached through a compound's head noun.
  (String?, bool) resolve(String word, {required bool sentenceInitial}) {
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
    for (final cand in candidates) {
      var ids = _index[cand] ?? const <String>[];
      // German nouns are always capitalised: "weg" is never "Weg".
      if (!upperFirst) {
        ids = [
          for (final id in ids)
            if (_lex[id]?.$1 != 'noun') id,
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
      final (pos, rank) = _lex[id] ?? ('other', 99999);
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
