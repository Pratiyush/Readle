import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/srs.dart';

class SavedWord {
  const SavedWord({
    required this.key,
    required this.word,
    required this.storyId,
    required this.context,
    required this.added,
    required this.card,
  });

  /// Dictionary key, or `free:<word>` for a word without an entry.
  final String key;
  final String word;
  final String storyId;
  final String context;
  final String added;
  final SrsCard card;

  SavedWord withCard(SrsCard c) => SavedWord(key: key, word: word, storyId: storyId, context: context, added: added, card: c);

  Map<String, Object> toJson() => {'key': key, 'word': word, 'storyId': storyId, 'context': context, 'added': added, 'card': card.toJson()};

  factory SavedWord.fromJson(Map<String, dynamic> j) => SavedWord(
    key: j['key'] as String,
    word: j['word'] as String,
    storyId: j['storyId'] as String,
    context: j['context'] as String,
    added: j['added'] as String,
    card: SrsCard.fromJson(j['card'] as Map<String, dynamic>),
  );
}

enum ThemeChoice { system, light, dark }

class Settings {
  const Settings({
    this.level = 'all',
    this.fontScale = 1,
    this.theme = ThemeChoice.system,
    this.dailyGoal = 1,
    this.speechRate = 0.9,
    this.autoPlayWords = true,
    this.reminder = false,
    this.reminderMinutes = defaultReminderMinutes,
  });

  static const defaultReminderMinutes = 19 * 60;

  final String level; // 'all' or a CEFR level
  final double fontScale;
  final ThemeChoice theme;
  final int dailyGoal; // stories per day
  final double speechRate; // web units: 0.7 slow, 0.9 normal, 1.05 fast
  final bool autoPlayWords; // say a word when it is tapped
  final bool reminder; // the daily reminder: off until the learner turns it on
  final int reminderMinutes; // its time of day, minutes after midnight (0..1439)

  Settings copyWith({
    String? level,
    double? fontScale,
    ThemeChoice? theme,
    int? dailyGoal,
    double? speechRate,
    bool? autoPlayWords,
    bool? reminder,
    int? reminderMinutes,
  }) => Settings(
    level: level ?? this.level,
    fontScale: fontScale ?? this.fontScale,
    theme: theme ?? this.theme,
    dailyGoal: dailyGoal ?? this.dailyGoal,
    speechRate: speechRate ?? this.speechRate,
    autoPlayWords: autoPlayWords ?? this.autoPlayWords,
    reminder: reminder ?? this.reminder,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
  );

  Map<String, Object> toJson() => {
    'level': level,
    'fontScale': fontScale,
    'theme': theme.name,
    'dailyGoal': dailyGoal,
    'speechRate': speechRate,
    'autoPlayWords': autoPlayWords,
    'reminder': reminder,
    'reminderMinutes': reminderMinutes,
  };

  factory Settings.fromJson(Map<String, dynamic> j) {
    const d = Settings();
    T? as<T>(Object? v) => v is T ? v : null; // a value of the wrong type falls back, alone
    return Settings(
      level: as<String>(j['level']) ?? d.level,
      fontScale: as<num>(j['fontScale'])?.toDouble() ?? d.fontScale,
      theme: ThemeChoice.values.asNameMap()[j['theme']] ?? d.theme,
      dailyGoal: as<num>(j['dailyGoal'])?.toInt() ?? d.dailyGoal,
      speechRate: as<num>(j['speechRate'])?.toDouble() ?? d.speechRate,
      autoPlayWords: as<bool>(j['autoPlayWords']) ?? d.autoPlayWords,
      reminder: as<bool>(j['reminder']) ?? d.reminder,
      reminderMinutes: switch (j['reminderMinutes']) {
        final int m when m >= 0 && m < 24 * 60 => m,
        _ => d.reminderMinutes,
      },
    );
  }
}

/// Everything the learner has done, persisted as one JSON document in the same schema as the web
/// app's `readle.state.v1`, so progress could move between the two.
class AppState extends ChangeNotifier {
  AppState._(this._prefs, this._today);

  static const storageKey = 'readle.state.v1';

  final SharedPreferences _prefs;
  final String Function() _today;

  Map<String, String> read = {}; // storyId → day first finished
  Map<String, int> progress = {}; // storyId → furthest sentence reached
  Map<String, double> quiz = {}; // storyId → best score 0..1
  Map<String, SavedWord> words = {};
  List<String> activeDays = []; // sorted, unique
  Settings settings = const Settings();
  String? lastStory; // the story opened most recently, for "Continue reading"
  bool wordTipSeen = false; // the first-run "tap any word" cue has done its job
  bool onboarded = false; // the first-launch level question is answered

  String get today => _today();

  static Future<AppState> load(SharedPreferences prefs, {String Function()? today}) async {
    final s = AppState._(prefs, today ?? dayKey);
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      try {
        s._fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // corrupt data: start fresh rather than crash
      }
    }
    return s;
  }

  void _fromJson(Map<String, dynamic> j) {
    // Field by field and entry by entry: one value of the wrong type (an older or newer build, a
    // hand-edited backup) must not drop everything after it, which the next save makes permanent.
    read = _entries(j['read'], (v) => v as String);
    progress = _entries(j['progress'], (v) => (v as num).toInt());
    quiz = _entries(j['quiz'], (v) => (v as num).toDouble());
    words = _entries(j['words'], (v) => SavedWord.fromJson(v as Map<String, dynamic>));
    activeDays = [
      for (final d in j['activeDays'] is List ? j['activeDays'] as List : const [])
        if (d is String) d,
    ];
    settings = j['settings'] is Map<String, dynamic> ? Settings.fromJson(j['settings'] as Map<String, dynamic>) : const Settings();
    lastStory = j['lastStory'] is String ? j['lastStory'] as String : null;
    wordTipSeen = j['wordTipSeen'] is bool ? j['wordTipSeen'] as bool : false;
    // Installs from before the level question have already been using the app.
    onboarded = j['onboarded'] is bool ? j['onboarded'] as bool : true;
  }

  /// The entries of a JSON object that parse; a bad entry is skipped, not the whole map.
  static Map<String, T> _entries<T>(Object? raw, T Function(Object? v) parse) {
    final out = <String, T>{};
    if (raw is! Map) return out;
    for (final e in raw.entries) {
      try {
        out[e.key as String] = parse(e.value);
      } catch (_) {
        // skip this entry only
      }
    }
    return out;
  }

  Map<String, Object> toJson() => {
    'version': 1,
    'read': read,
    'progress': progress,
    'quiz': quiz,
    'words': {for (final e in words.entries) e.key: e.value.toJson()},
    'activeDays': activeDays,
    'settings': settings.toJson(),
    'lastStory': ?lastStory,
    'wordTipSeen': wordTipSeen,
    'onboarded': onboarded,
  };

  void _commit() {
    _prefs.setString(storageKey, jsonEncode(toJson()));
    notifyListeners();
  }

  void _markActive() {
    final t = today;
    if (!activeDays.contains(t)) activeDays = [...activeDays, t]..sort();
  }

  // ── derived ──
  int get streakDays => streak(activeDays, today);
  int get readToday => read.values.where((d) => d == today).length;
  int get dueCount => words.values.where((w) => w.card.isDue(today)).length;
  bool isSaved(String key) => words.containsKey(key);

  /// The story to offer as "Continue reading": opened last, started, not finished.
  String? get continueStory {
    final id = lastStory;
    return id != null && !read.containsKey(id) && (progress[id] ?? 0) > 0 ? id : null;
  }

  // ── actions ──
  void openStory(String storyId) {
    if (lastStory == storyId) return;
    lastStory = storyId;
    _commit();
  }

  void markWordTipSeen() {
    if (wordTipSeen) return;
    wordTipSeen = true;
    _commit();
  }

  void finishStory(String storyId) {
    read = {...read, storyId: read[storyId] ?? today};
    _markActive();
    _commit();
  }

  void setProgress(String storyId, int sentence) {
    if ((progress[storyId] ?? -1) >= sentence) return;
    progress = {...progress, storyId: sentence};
    _commit();
  }

  void recordQuiz(String storyId, double score) {
    final best = quiz[storyId] ?? 0;
    quiz = {...quiz, storyId: score > best ? score : best};
    _commit();
  }

  void toggleWord({required String key, required String word, required String storyId, required String context}) {
    if (words.containsKey(key)) {
      words = {...words}..remove(key);
    } else {
      words = {
        ...words,
        key: SavedWord(key: key, word: word, storyId: storyId, context: context, added: today, card: SrsCard.fresh(today)),
      };
    }
    _commit();
  }

  void reviewWord(String key, {required bool correct}) {
    final w = words[key];
    if (w == null) return;
    words = {...words, key: w.withCard(w.card.review(correct: correct, today: today))};
    _markActive();
    _commit();
  }

  /// The first-launch answer: a CEFR level, or 'all' for every level in sequence.
  void finishOnboarding(String level) {
    settings = settings.copyWith(level: level);
    onboarded = true;
    _commit();
  }

  void updateSettings(Settings next) {
    settings = next;
    _commit();
  }

  void reset() {
    read = {};
    progress = {};
    quiz = {};
    words = {};
    activeDays = [];
    settings = const Settings();
    lastStory = null;
    wordTipSeen = false;
    _commit();
  }
}
