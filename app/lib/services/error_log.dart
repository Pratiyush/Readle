import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small local crash log: the last [keep] uncaught errors, kept on the device (nothing is sent
/// anywhere). Settings can show it to attach to a support mail later.
class ErrorLog {
  ErrorLog(this._prefs);

  static const key = 'readle.errors';
  static const keep = 20;
  final SharedPreferences _prefs;

  List<Map<String, dynamic>> get entries =>
      [for (final e in _prefs.getStringList(key) ?? const <String>[]) jsonDecode(e) as Map<String, dynamic>];

  void record(Object error, StackTrace? stack, {String source = 'app'}) {
    final line = jsonEncode({
      'at': DateTime.now().toIso8601String(),
      'source': source,
      'error': error.toString(),
      'stack': stack?.toString().split('\n').take(8).join('\n'),
    });
    final list = [...?_prefs.getStringList(key), line];
    _prefs.setStringList(key, list.length > keep ? list.sublist(list.length - keep) : list);
  }

  /// Route framework and platform errors here as well as to the console.
  void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exception, details.stack, source: 'flutter');
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, source: 'platform');
      debugPrint('Uncaught: $error');
      return true;
    };
  }
}
