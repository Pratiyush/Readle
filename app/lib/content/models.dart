// The compiled content the app reads: the same JSON the web app ships (tools/build_content.py).

const levels = ['A1', 'A2', 'B1', 'B2'];

class StoryMeta {
  const StoryMeta({
    required this.id,
    required this.title,
    required this.level,
    required this.collection,
    required this.publishedAt,
    required this.image,
    this.thumb,
    required this.teaser,
    required this.teaserEn,
    required this.words,
    required this.minutes,
  });

  final String id;
  final String title;
  final String level;
  final String collection;
  final String publishedAt;
  final String? image;

  /// A 320 px copy of [image] for list cards; null for downloaded stories (they use [image]).
  final String? thumb;
  final String teaser;
  final String teaserEn;
  final int words;
  final int minutes;

  factory StoryMeta.fromJson(Map<String, dynamic> j) => StoryMeta(
    id: j['id'] as String,
    title: j['title'] as String,
    level: j['level'] as String,
    collection: j['collection'] as String,
    publishedAt: j['publishedAt'] as String,
    image: j['image'] as String?,
    thumb: j['thumb'] as String?,
    teaser: j['teaser'] as String,
    teaserEn: j['teaserEn'] as String,
    words: j['words'] as int,
    minutes: j['minutes'] as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'level': level,
    'collection': collection,
    'publishedAt': publishedAt,
    'image': image,
    'thumb': thumb,
    'teaser': teaser,
    'teaserEn': teaserEn,
    'words': words,
    'minutes': minutes,
  };
}

/// A run of plain text, or a word: optionally linked to a dictionary key, and flagged when the
/// link goes through the head of a compound (Haustür → Tür).
class Token {
  const Token.text(this.text) : isWord = false, key = null, compound = false;
  const Token.word(this.text, {this.key, this.compound = false}) : isWord = true;

  final String text;
  final bool isWord;
  final String? key;
  final bool compound;

  factory Token.fromJson(Object? j) {
    if (j is String) return Token.text(j);
    final l = j as List;
    return Token.word(l[0] as String, key: l.length > 1 ? l[1] as String : null, compound: l.length > 2 && l[2] == 1);
  }
}

class Sentence {
  const Sentence({required this.de, required this.en, required this.tokens});
  final String de;
  final String en;
  final List<Token> tokens;

  factory Sentence.fromJson(Map<String, dynamic> j) =>
      Sentence(de: j['de'] as String, en: j['en'] as String, tokens: [for (final t in j['t'] as List) Token.fromJson(t)]);
}

class Story {
  const Story({required this.meta, required this.sentences});
  final StoryMeta meta;
  final List<Sentence> sentences;

  String get id => meta.id;

  factory Story.fromJson(Map<String, dynamic> j) =>
      Story(meta: StoryMeta.fromJson(j), sentences: [for (final s in j['sentences'] as List) Sentence.fromJson(s as Map<String, dynamic>)]);
}

class DictEntry {
  const DictEntry({
    required this.headword,
    required this.pos,
    required this.en,
    this.gender,
    this.plural,
    this.ipa,
    this.cefr,
    this.exampleDe,
    this.exampleEn,
    this.audio,
  });

  final String headword;
  final String pos;
  final List<String> en;
  final String? gender; // der / die / das
  final String? plural;
  final String? ipa;
  final String? cefr;
  final String? exampleDe;
  final String? exampleEn;

  /// Recorded pronunciation, relative to the content root (`audio/de.geben.v.mp3`).
  final String? audio;

  /// "das Brot" for nouns, the bare headword otherwise.
  String get display => gender == null ? headword : '$gender $headword';
  String get gloss => en.first;

  factory DictEntry.fromJson(Map<String, dynamic> j) => DictEntry(
    headword: j['h'] as String,
    pos: j['p'] as String,
    en: [for (final g in j['en'] as List) g as String],
    gender: j['g'] as String?,
    plural: j['pl'] as String?,
    ipa: j['ipa'] as String?,
    cefr: j['cefr'] as String?,
    exampleDe: j['xd'] as String?,
    exampleEn: j['xe'] as String?,
    audio: j['au'] as String?,
  );
}

typedef Dictionary = Map<String, DictEntry>;
