import 'package:flutter_test/flutter_test.dart';
import 'package:readle/services/ads_config.dart';

const google = 'ca-app-pub-3940256099942544/';
const readle = 'ca-app-pub-5964569110696877/';

void main() {
  test('debug and profile builds only ever use Google test units', () {
    for (final ios in [false, true]) {
      final u = unitsFor(ios: ios, release: false, forceTest: false);
      expect([u.banner, u.interstitial, u.rewarded], everyElement(startsWith(google)));
    }
  });

  test("an Android release uses Readle's units from the hub's admob-ids.json", () {
    final u = unitsFor(ios: false, release: true, forceTest: false);
    expect(u.banner, '${readle}2730371930');
    expect(u.interstitial, '${readle}5164963588');
    expect(u.rewarded, '${readle}4865580680');
  });

  test('an iOS release has no units yet, so every ad call is a no-op', () {
    final u = unitsFor(ios: true, release: true, forceTest: false);
    expect([u.banner, u.interstitial, u.rewarded], everyElement(isEmpty));
  });

  test('ADS_TEST forces test units into a release build', () {
    final u = unitsFor(ios: false, release: true, forceTest: true);
    expect(u.banner, startsWith(google));
  });

  test('ads stay off unless ADS_ENABLED is defined', () => expect(adsEnabled, isFalse));
}
