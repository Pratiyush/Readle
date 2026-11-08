import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'content/content_repository.dart';
import 'services/ads.dart';
import 'services/ads_config.dart';
import 'services/error_log.dart';
import 'services/interstitial_policy.dart';
import 'services/speech.dart';
import 'services/word_player.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  ErrorLog(prefs).install();
  final state = await AppState.load(prefs);
  final launches = (prefs.getInt('readle.launches') ?? 0) + 1;
  await prefs.setInt('readle.launches', launches);
  final Ads ads = adsEnabled ? AdMobAds(policy: InterstitialPolicy(firstSession: launches == 1)) : NoAds();
  runApp(ReadleApp(state: state, content: AssetContentRepository(), speech: DeviceSpeech(), player: AssetWordPlayer(), ads: ads));
  // Consent → ATT → SDK after the first frame; reading never waits for it.
  unawaited(ads.init().catchError((Object _) {}));
}
