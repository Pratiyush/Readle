import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'content/cdn/content_client.dart';
import 'content/cdn/content_store.dart';
import 'content/cdn/fetcher.dart';
import 'content/cdn/manifest.dart' show contentCdnEnabled;
import 'content/cdn/network.dart';
import 'content/content_repository.dart';
import 'content/layered_repository.dart';
import 'services/ads.dart';
import 'services/ads_config.dart';
import 'services/error_log.dart';
import 'services/interstitial_policy.dart';
import 'services/reminders.dart';
import 'services/share.dart';
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
  // Stories installed from the content CDN sit on top of the bundled ones.
  final store = ContentStore(Directory('${(await getApplicationSupportDirectory()).path}/content'));
  final bundled = AssetContentRepository();
  final content = LayeredContentRepository(bundled: bundled, store: store);
  final bundledIds = <String>{};
  final updates = contentCdnEnabled
      ? ContentClient(
          fetcher: HttpFetcher(),
          store: store,
          prefs: prefs,
          bundledIds: bundledIds,
          autoUpdate: () => state.settings.autoUpdateOnWifi,
          unmetered: onUnmeteredNetwork,
          afterInstall: content.reload,
        )
      : null;
  final reminders = LocalReminders();
  runApp(
    ReadleApp(
      state: state,
      content: content,
      speech: DeviceSpeech(),
      player: AssetWordPlayer(),
      ads: ads,
      updates: updates,
      reminders: reminders,
      sharer: SystemSharer(),
    ),
  );
  // The daily reminder (off by default): with it on, every launch sets the next seven days again.
  DailyReminder(state: state, reminders: reminders).start();
  // Consent → ATT → SDK after the first frame; reading never waits for it.
  unawaited(ads.init().catchError((Object _) {}));
  // The daily content check (at most once per 24 h, silent offline) after the first frame too.
  if (updates != null) {
    unawaited(() async {
      bundledIds.addAll([for (final s in await bundled.library()) s.id]);
      await updates.check();
    }());
  }
}
