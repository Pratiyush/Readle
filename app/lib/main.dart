import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'content/content_repository.dart';
import 'services/speech.dart';
import 'services/word_player.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load(await SharedPreferences.getInstance());
  runApp(ReadleApp(state: state, content: AssetContentRepository(), speech: DeviceSpeech(), player: AssetWordPlayer()));
}
