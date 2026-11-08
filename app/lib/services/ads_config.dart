// Ads are built in and switched off. `--dart-define=ADS_ENABLED=true` turns them on; the unit ids
// below stay empty until the hub supplies Readle's AdMob units (account pub-5964569110696877), and
// every ad call is a no-op while an id is empty. `--dart-define=ADS_TEST=true` swaps in Google's
// public test units to check consent → ATT → ads on a sandbox device; never in a release.

const adsEnabled = bool.fromEnvironment('ADS_ENABLED');
const adsUseTestUnits = bool.fromEnvironment('ADS_TEST');

class AdUnits {
  const AdUnits({this.native = '', this.interstitial = '', this.rewarded = ''});
  final String native;
  final String interstitial;
  final String rewarded;
}

/// Readle's own units — fill in from the hub, then build with ADS_ENABLED=true.
const androidUnits = AdUnits();
const iosUnits = AdUnits();

/// Google's documented test units (https://developers.google.com/admob/android/test-ads).
const androidTestUnits = AdUnits(
  native: 'ca-app-pub-3940256099942544/2247696110',
  interstitial: 'ca-app-pub-3940256099942544/1033173712',
  rewarded: 'ca-app-pub-3940256099942544/5224354917',
);
const iosTestUnits = AdUnits(
  native: 'ca-app-pub-3940256099942544/3986624511',
  interstitial: 'ca-app-pub-3940256099942544/4411468910',
  rewarded: 'ca-app-pub-3940256099942544/1712485313',
);
