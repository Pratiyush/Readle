import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
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

  /// A native ad styled as a list row, or null when there is none to show.
  Widget? nativeRow();

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
  Widget? nativeRow() => null;
  @override
  Future<void> storyFinished() async {}
}

class AdMobAds extends Ads {
  AdMobAds({required this.policy, AdUnits? units})
      : units = units ?? (adsUseTestUnits ? (Platform.isIOS ? iosTestUnits : androidTestUnits) : (Platform.isIOS ? iosUnits : androidUnits));

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
  Widget? nativeRow() => !_ready || units.native.isEmpty ? null : _NativeRow(unitId: units.native);
}

/// A small native template, labelled by the SDK's ad badge, that hides itself if nothing loads.
class _NativeRow extends StatefulWidget {
  const _NativeRow({required this.unitId});
  final String unitId;

  @override
  State<_NativeRow> createState() => _NativeRowState();
}

class _NativeRowState extends State<_NativeRow> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = NativeAd(
      adUnitId: widget.unitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(templateType: TemplateType.small),
      listener: NativeAdListener(
        onAdLoaded: (_) => mounted ? setState(() => _loaded = true) : null,
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
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
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    // Clear space around the slot keeps it away from the story cards' tap targets.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 90, maxHeight: 120), child: AdWidget(ad: ad)),
    );
  }
}
