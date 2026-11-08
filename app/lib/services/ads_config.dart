// Ads are built in and switched off: `--dart-define=ADS_ENABLED=true` turns them on.
// Release builds use Readle's own AdMob units; debug and profile builds always use Google's public
// test units, and `--dart-define=ADS_TEST=true` forces test units into a release build for QA.
// Every ad call is a no-op while a unit id is empty (iOS has no AdMob app yet).

const adsEnabled = bool.fromEnvironment('ADS_ENABLED');
const adsUseTestUnits = bool.fromEnvironment('ADS_TEST');

class AdUnits {
  const AdUnits({this.banner = '', this.interstitial = '', this.rewarded = ''});

  /// Inline adaptive banner in the library list.
  final String banner;

  /// After a finished story, capped by InterstitialPolicy (AdMob also caps it at 1 per 2 minutes).
  final String interstitial;

  /// For unlocking a live story early, once live content exists.
  final String rewarded;
}

/// Readle Android (hub German/docs/admob-ids.json, verified in the AdMob console 2026-11-08):
/// app ca-app-pub-5964569110696877~7982698610, set for release in android/app/build.gradle.kts.
const androidUnits = AdUnits(
  banner: 'ca-app-pub-5964569110696877/2730371930', // banner_library
  interstitial: 'ca-app-pub-5964569110696877/5164963588', // interstitial_story
  rewarded: 'ca-app-pub-5964569110696877/4865580680', // rewarded_unlock
);

/// No iOS AdMob app yet; it is created when the iOS build nears TestFlight.
const iosUnits = AdUnits();

/// Google's documented test units (developers.google.com/admob/{android,ios}/test-ads).
const androidTestUnits = AdUnits(
  banner: 'ca-app-pub-3940256099942544/9214589741',
  interstitial: 'ca-app-pub-3940256099942544/1033173712',
  rewarded: 'ca-app-pub-3940256099942544/5224354917',
);
const iosTestUnits = AdUnits(
  banner: 'ca-app-pub-3940256099942544/2435281174',
  interstitial: 'ca-app-pub-3940256099942544/4411468910',
  rewarded: 'ca-app-pub-3940256099942544/1712485313',
);

/// Readle's units only in a release build that isn't forced onto test units.
AdUnits unitsFor({required bool ios, required bool release, bool forceTest = adsUseTestUnits}) =>
    !release || forceTest ? (ios ? iosTestUnits : androidTestUnits) : (ios ? iosUnits : androidUnits);
