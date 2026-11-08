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

  Map<String, Object> toJson() =>
      {'key': key, 'word': word, 'storyId': storyId, 'context': context, 'added': added, 'card': card.toJson()};

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
  });

  final String level; // 'all' or a CEFR level
  final double fontScale;
  final ThemeChoice theme;
  final int dailyGoal; // stories per day
  final double speechRate; // web units: 0.7 slow, 0.9 normal, 1.05 fast

  Settings copyWith({String? level, double? fontScale, ThemeChoice? theme, int? dailyGoal, double? speechRate}) => Settings(
        level: level ?? this.level,
        fontScale: fontScale ?? this.fontScale,
        theme: theme ?? this.theme,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        speechRate: speechRate ?? this.speechRate,
      );

  Map<String, Object> toJson() =>
      {'level': level, 'fontScale': fontScale, 'theme': theme.name, 'dailyGoal': dailyGoal, 'speechRate': speechRate};

  factory Settings.fromJson(Map<String, dynamic> j) {
    const d = Settings();
    return Settings(
      level: j['level'] as String? ?? d.level,
      fontScale: (j['fontScale'] as num?)?.toDouble() ?? d.fontScale,
      theme: ThemeChoice.values.asNameMap()[j['theme']] ?? d.theme,
      dailyGoal: j['dailyGoal'] as int? ?? d.dailyGoal,
      speechRate: (j['speechRate'] as num?)?.toDouble() ?? d.speechRate,
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
    read = {for (final e in (j['read'] as Map? ?? {}).entries) e.key as String: e.value as String};
    progress = {for (final e in (j['progress'] as Map? ?? {}).entries) e.key as String: e.value as int};
    quiz = {for (final e in (j['quiz'] as Map? ?? {}).entries) e.key as String: (e.value as num).toDouble()};
    words = {
      for (final e in (j['words'] as Map? ?? {}).entries) e.key as String: SavedWord.fromJson(e.value as Map<String, dynamic>),
    };
    activeDays = [for (final d in j['activeDays'] as List? ?? []) d as String];
    settings = Settings.fromJson(j['settings'] as Map<String, dynamic>? ?? {});
  }

  Map<String, Object> toJson() => {
        'version': 1,
        'read': read,
        'progress': progress,
        'quiz': quiz,
        'words': {for (final e in words.entries) e.key: e.value.toJson()},
        'activeDays': activeDays,
        'settings': settings.toJson(),
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

  // ── actions ──
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
    _commit();
  }
}
