import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';
import 'interstitial_policy.dart';

/// Advertising, behind ADS_ENABLED. Order on start: UMP consent → (iOS) ATT → Mobile Ads SDK, and
/// no ad request before UMP says `canRequestAds`. Nothing here ever blocks or breaks reading.
abstract class Ads extends ChangeNotifier {
  Future<void> init();

  /// UMP says the user must be able to reopen the consent choices (Settings shows the entry).
  bool get privacyOptionsRequired;
  Future<void> showPrivacyOptions();

  /// An inline adaptive banner for the library list, or null when there is none to show.
  Widget? listBanner();

  /// The learner finished a story and is leaving its results: maybe show a capped interstitial.
  Future<void> storyFinished();
}

class NoAds extends Ads {
  @override
  Future<void> init() async {}
  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  Widget? listBanner() => null;
  @override
  Future<void> storyFinished() async {}
}

class AdMobAds extends Ads {
  AdMobAds({required this.policy, AdUnits? units}) : units = units ?? unitsFor(ios: Platform.isIOS, release: kReleaseMode);

  final AdUnits units;
  final InterstitialPolicy policy;
  bool _ready = false;
  bool _privacyRequired = false;
  InterstitialAd? _interstitial;

  @override
  Future<void> init() async {
    final consent = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) => consent.complete()),
      (_) => consent.complete(), // offline or misconfigured: fall through to canRequestAds
    );
    await consent.future;
    _privacyRequired = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;

    // ATT after UMP (Apple: no tracking prompt while the consent form is up).
    if (Platform.isIOS &&
        await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.notDetermined) {
      await AppTrackingTransparency.requestTrackingAuthorization();
    }

    if (!await ConsentInformation.instance.canRequestAds()) {
      notifyListeners();
      return;
    }
    await MobileAds.instance.initialize();
    _ready = true;
    _loadInterstitial();
    notifyListeners();
  }

  @override
  bool get privacyOptionsRequired => _privacyRequired;

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) => done.complete());
    await done.future;
  }

  void _loadInterstitial() {
    if (!_ready || units.interstitial.isEmpty) return;
    InterstitialAd.load(
      adUnitId: units.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  @override
  Future<void> storyFinished() async {
    if (!policy.storyFinished()) return;
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        closed.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        closed.complete();
      },
    );
    policy.shown();
    await ad.show();
    await closed.future;
    _loadInterstitial();
  }

  @override
  Widget? listBanner() => !_ready || units.banner.isEmpty ? null : _InlineBanner(unitId: units.banner);
}

/// An inline adaptive banner sized to the list's width; it takes no space until an ad loads.
class _InlineBanner extends StatefulWidget {
  const _InlineBanner({required this.unitId});
  final String unitId;

  @override
  State<_InlineBanner> createState() => _InlineBannerState();
}

class _InlineBannerState extends State<_InlineBanner> {
  BannerAd? _ad;
  AdSize? _size;
  int? _width;

  void _load(int width) {
    _width = width;
    _ad?.dispose();
    _size = null;
    _ad = BannerAd(
      adUnitId: widget.unitId,
      request: const AdRequest(),
      size: AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(width),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          final size = await (ad as BannerAd).getPlatformAdSize();
          if (mounted && size != null) setState(() => _size = size);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (identical(ad, _ad)) _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth.truncate();
        if (width != _width) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _load(width) : null);
        final ad = _ad, size = _size;
        if (ad == null || size == null) return const SizedBox.shrink();
        // Clear space around the slot keeps it away from the story cards' tap targets.
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SizedBox(width: size.width.toDouble(), height: size.height.toDouble(), child: AdWidget(ad: ad)),
        );
      });
}
