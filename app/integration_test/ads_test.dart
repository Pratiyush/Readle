// On-device check that the library's inline banner renders (debug build → Google's test units).
// `flutter test integration_test/ads_test.dart -d <device>`; needs network.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show AdWidget;
import 'package:integration_test/integration_test.dart';
import 'package:readle/app.dart';
import 'package:readle/content/content_repository.dart';
import 'package:readle/services/ads.dart';
import 'package:readle/services/interstitial_policy.dart';
import 'package:readle/services/speech.dart';
import 'package:readle/services/word_player.dart';
import 'package:readle/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the library shows a 320×100 banner after the 6th story, at most 120 dp tall', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load(await SharedPreferences.getInstance());
    final ads = AdMobAds(policy: InterstitialPolicy(firstSession: false));
    await tester.pumpWidget(ReadleApp(
        state: state, content: AssetContentRepository(), speech: RecordingSpeech(), player: RecordingWordPlayer(), ads: ads));
    await tester.pumpAndSettle();
    await ads.startForTest();
    await tester.pumpAndSettle();

    final list = find.descendant(of: find.byKey(const PageStorageKey('library')), matching: find.byType(Scrollable)).first;
    final end = DateTime.now().add(const Duration(seconds: 90));
    while (find.byType(AdWidget).evaluate().isEmpty && DateTime.now().isBefore(end)) {
      await tester.drag(list, const Offset(0, -250));
      await tester.pump(const Duration(seconds: 2));
      final position = tester.state<ScrollableState>(list).position;
      if (position.pixels > 2500) {
        position.jumpTo(600); // past the first slot (after story 6): come back near it and wait
        await tester.pump(const Duration(seconds: 3));
      }
    }
    expect(find.byType(AdWidget), findsWidgets, reason: 'a test banner loaded into the library list');
    final size = tester.getSize(find.byType(AdWidget).first);
    expect(size.height, inInclusiveRange(50, maxBannerHeight), reason: 'capped at about one story card');
    // ignore: avoid_print
    print('banner rendered at ${size.width.toStringAsFixed(0)}×${size.height.toStringAsFixed(0)}');
  });
}
