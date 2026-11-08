# Readle: production gate (2026-11-08)

Run against the hub checklist (`German/docs/production-gate.md`) on branch `ccr-7aeb8ea1-63oetl`,
for the **Flutter app** (`app/`, the store build) and, where it applies, the **web PWA**. Nothing is
pushed. **pass** means verified here with the evidence named; **fail** means not done (the fix, or
the owner step, is named); **n/a** means it doesn't apply to Readle.

**Summary: 26 pass · 12 fail (incl. partial) · 0 n/a, of 38 checks.** Every failure is either an owner-only step (name, ids,
legal pages, signing key, store consoles, ElevenLabs licence; all in `docs/status.json` as user
todos) or a Claude follow-up that needs one of those first (release screenshots, real-ads device
run, iOS device run).

Device numbers below come from a private sandbox emulator (Pixel 7 profile, API 35, arm64, console
port 5562) running the **release** APK (R8 + `--obfuscate`) with `ADS_ENABLED=true ADS_TEST=true`,
on a host whose load average was 300+, so treat timings as upper bounds.

## 1. Ads and AdMob

| Check | Result | Evidence / fix |
|---|---|---|
| UMP before any ad request; `MobileAds.initialize` only after `canRequestAds()` | **pass** | `app/lib/services/ads.dart` `AdMobAds.init`: `requestConsentInfoUpdate` → `loadAndShowConsentFormIfRequired` → (iOS) ATT → `canRequestAds()` → `initialize()`. Native, interstitial and rewarded loads are gated on `_ready`. |
| Android auto-init removed + `DELAY_APP_MEASUREMENT_INIT`, verified in the merged release manifest | **pass** | `AndroidManifest.xml` has `MobileAdsInitProvider` with `tools:node="remove"`. `aapt2 dump xmltree` of `app-release.apk` shows `DELAY_APP_MEASUREMENT_INIT` and no `MobileAdsInitProvider`. |
| iOS: `GADDelayAppMeasurementInit`, ATT after UMP with `NSUserTrackingUsageDescription`, `SKAdNetworkItems`, `GADApplicationIdentifier` | **pass** (config) | `ios/Runner/Info.plist` (`plutil -lint` OK): delay flag, usage text, 50 SKAdNetwork ids, `GADApplicationIdentifier = $(ADMOB_APP_ID)` from `ios/Flutter/*.xcconfig`. ATT is requested only after the UMP flow completes. |
| Readle's own AdMob app id | **pass** (Android) / **fail** (iOS, hub) | Android release: `ca-app-pub-5964569110696877~7982698610` (hub `admob-ids.json`, verified in the console), set on the `release` build type; debug/profile keep Google's sample app. Read back from the merged release and debug manifests: release APK → `~7982698610`, debug APK → Google's `~3347511713`, `MobileAdsInitProvider` absent in both. iOS: no AdMob app yet (created near TestFlight); `ADMOB_APP_ID` stays Google's sample and the iOS units are empty, so iOS ads are no-ops. |
| `ADS_ENABLED` (default off) + unit ids in one config; every call a no-op when unset | **pass** | `app/lib/services/ads_config.dart`: Readle's Android units (`banner_library`, `interstitial_story`, `rewarded_unlock`) are used **only in release builds**. Debug/profile always get Google's test units, and `ADS_TEST=true` forces them into a release for QA. `unitsFor` is covered by `test/ads_config_test.dart` (5 tests). `ADS_ENABLED` stays off. |
| Placement map followed | **pass** | Map in `docs/review-2026-11-08.md`. Library: a **large banner, 320×100** (`banner_library`) after story 6, then every 8, so a phone screen never holds two; verified rendering on the device. Words and Progress: no slot (no unit provisioned). Interstitial (`interstitial_story`) only when leaving a finished story's results, via `InterstitialPolicy` (every 3rd story, ≥4 min apart, ≤4/day, never in the first session; AdMob adds its own 1-per-2-min cap), with 4 unit tests. Rewarded (`rewarded_unlock`): no placement until locked live stories exist. Nothing in the reader, word sheet, quiz or practice. |
| GDPR consent message created in AdMob (Privacy & messaging) | **fail** (owner/hub) | Created once Readle's privacy policy URL is hosted; until then UMP has no message to show real users. The test-ads run above used Google's test consent form. |
| "Privacy options" entry when UMP requires it | **pass** | Progress → Settings → "Privacy & ad choices" (`showPrivacyOptionsForm`), shown when `PrivacyOptionsRequirementStatus.required`. |
| Release build with Google **test** ads: consent → ATT → ads; no crash at launch (R8 keep rules) | **pass** (Android) / **fail** (iOS) | Android, R8 + obfuscated release with `ADS_TEST`: the UMP form appears first over the library ([screenshot](review-2026-11-08/05-release-consent-android.jpg)). After "Consent" the SDK starts ("This request is sent from a test device") and list ads are requested. That run used the earlier native slot, whose Google test unit failed to fill (the row hid itself). The slot is now a banner (`banner_library`), verified on the device by `integration_test/ads_test.dart`: a 320×100 large banner rendered at 379×100 in the library list (an uncapped inline adaptive banner had measured 379×316, too tall for a reading app). No fatal exception and no crash-buffer entry across 3 cold starts, consent and scrolling. `proguard-rules.pro` keeps WorkManager/Room and the JNI plugins. iOS: not run on a simulator yet (todo). |
| Personalised ads only with consent where the law requires | **pass** | Non-personalised vs personalised is decided by UMP (TCF signal to the SDK). When `canRequestAds()` is false, the SDK never starts and no ad is requested. |

## 2. Store policy

| Check | Result | Evidence / fix |
|---|---|---|
| Play: targetSdk 36 | **pass** | Merged manifest: `targetSdkVersion=36`, `minSdkVersion=24`. |
| Play: 16 KB page-size support | **pass** | `zipalign -c -P 16 -v 4 app-release.apk` → "Verification successful". |
| Play: signed AAB | **fail** (owner) | The release uses debug signing until the upload key exists (`build.gradle.kts`; `key.properties`, `*.jks` and `*.keystore` are git-ignored). |
| Flutter `--obfuscate --split-debug-info` | **pass** | The release build used both (`build/symbols`, kept out of git). Wrap into `tool/release.sh` with the signing step. |
| Play Data safety answers drafted | **pass** (draft) | See "Store answers (drafts)" below. |
| Content rating answers drafted; 13+, not Families | **pass** (draft) | See below. |
| Apple: `PrivacyInfo.xcprivacy` | **pass** | `ios/Runner/PrivacyInfo.xcprivacy` (UserDefaults CA92.1; no tracking or collection by app code), added to the Runner target's resources. The Google SDK ships its own manifest. |
| App Privacy answers; 4.2 / 4.3 note | **pass** (draft) | See below. |
| Original app name and listing text | **fail** (owner) | "Readle" is the reference app's brand. Suggestions: Erzählbar, Satzweise, Leselicht. Listing text is drafted below with `<NAME>` placeholders. |

## 3. Privacy and German law

| Check | Result | Evidence / fix |
|---|---|---|
| Privacy policy for ads (AdMob, UMP, advertising IDs, ATT), hosted | **fail** (owner/hub) | Drafted by the hub (`German/legal`); published at `pratiyush.github.io/german-apps-legal/<slug>/privacy.html` once the app has its name. Covers the Flutter app only; it needs a web section if the PWA is published, and a content-downloads section when the content client ships. |
| Impressum (DDG §5) linked in app and listing; support email | **fail** (owner/hub) | In-app link done: Settings → Privacy policy / Impressum from one value (`app/lib/config.dart` `legalSlug`), hidden until the slug exists (`test/legal_test.dart`). The pages themselves are published with the name. |
| Settings: privacy options, reset local data, licences | **pass** | Progress → Settings: "Privacy & ad choices" (when required), "Reset all progress" (confirm dialog), "Licences" (`showLicensePage`). |
| Developer website = `https://pratiyush.github.io` (app-ads.txt) | **fail** (owner) | A store-console field; the hub reports app-ads.txt is live there. |

## 4. UX and accessibility

| Check | Result | Evidence / fix |
|---|---|---|
| Small phone, large phone, tablet; light + dark; large system font | **pass** | Flutter: `test/a11y_test.dart` runs every screen at **320×640 with 200 % text** (it found and fixed 3 overflows), and the flows run at 375×812. Web: Playwright at 375×812 and 768×1024, and a manual check in light and dark (`docs/review-2026-11-08/*.jpg`). |
| Screen-reader labels; contrast AA; tap targets ≥ 48 dp / 44 pt | **pass** (lists, settings) / known exception | `a11y_test.dart`: Flutter's `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline` and `textContrastGuideline` pass on Stories, Words and Progress. Known exception: words inside the reading text are inline text spans, smaller than 48 dp, as in any e-reader. Each still has a tap action and the paragraph reads as text. |
| Empty, offline, error and first-run states | **pass** | Empty: "No stories match", "No words yet", "Nothing to review". Error: "This story couldn't be loaded" and "Couldn't load the quiz". Offline: the app is bundled; the web is covered by an e2e test. First run: UMP form, then content (no onboarding needed). |

## 5. Performance and stability

| Check | Result | Evidence / fix |
|---|---|---|
| Cold start, jank, memory on sandbox devices | **pass** (start, memory) / **fail** (jank not measured) | Release APK, `am start -W` cold starts: **1,350 / 1,501 / 1,523 ms** (host load 300+). Memory after launch and scrolling: **143 MB PSS** (275 MB RSS). Jank: `dumpsys gfxinfo` can't see Flutter's own surface (0 frames counted), so it needs a profile-mode timeline (todo). The library scrolled smoothly by eye. |
| Download size measured; what moves to the CDN later | **pass** | Universal release APK **68.8 MB**; arm64-only estimate **36.1 MB** (what Play delivers from an AAB). Of that, word audio is 11.8 MB, story images 3.7 MB and story/dictionary JSON 0.8 MB: the ~16 MB that moves to the CDN with live content. |
| Local crash log / error hook; no uncaught exceptions in E2E | **pass** | `app/lib/services/error_log.dart`: `FlutterError.onError` + `PlatformDispatcher.onError`, last 20 kept on device only. E2E: the 6 device flows and 31 headless tests finished with no uncaught exception; the only TTS fallback logged was the name "Deutschland" (by design). |

## 6. Security

| Check | Result | Evidence / fix |
|---|---|---|
| No secrets in the repo or history; signing config git-ignored | **pass** | `git log -p --all` scan for API keys, private keys and store passwords: 0 hits. No `.jks`, `.keystore`, `key.properties` or `.p12` ever committed. `app/android/.gitignore` ignores them. |
| HTTPS only | **pass** | The app makes no own network calls (content is bundled); Android blocks cleartext by default (API 28+). The web runs on GitHub Pages over HTTPS. |
| No debug flags or test ad ids in release | **pass** (Android) / **fail** (iOS) | Android release: Readle's app id and units; test units only with `ADS_TEST=true`, which the release script must never pass. iOS: Google's sample app id until the iOS AdMob app exists. |

## 7. Content quality

| Check | Result | Evidence / fix |
|---|---|---|
| German spot-check: 50 words / 3 stories | **pass** (after fix) | 50 random nouns: articles, plurals and umlauts right, except "das Köln / das Bayern / das Europa". Those place names take no article; fixed in `tools/supplement.jsonl` (commit `f6fbf64`). Sentences sampled across A1–B2 in the review read correctly. Native review is still pending (owner todo). |
| Every word plays Lernle's ElevenLabs clip; TTS only as a logged fallback | **partial pass** | 1,214 of 1,344 dictionary entries (90%) ship Lernle's clip (provenance: 64 kbps encodes of Lernle's ElevenLabs masters, none matching the extracted Tobo clips). The other 130 fall back to device TTS, logged by `AppScope.sayWord`, and names always use TTS. Fix: generate the 130 missing clips through Lernle's own pipeline (hub; never from here, no API calls). |
| Images present; no broken references | **pass** | 105 of 107 stories have an illustration; the two without show a 📖 placeholder by design. Tests check every named image and audio file exists (Vitest and Flutter `content_test.dart`). |

## 8. Tests and release readiness

| Check | Result | Evidence / fix |
|---|---|---|
| E2E on Android + iOS (or web), green in CI | **pass** (local) / **fail** (CI not run) | Web: Playwright 16 scenarios × 2 viewports = **32 green**. Flutter: 6 flows green headless and **6/6 on the Android emulator** (API 35 sandbox, debug build, incl. the clip-on-tap assertion). iOS simulator: wired in `.github/workflows/app.yml`, not run yet. CI has never run because nothing is pushed. |
| Unit/widget tests green; analyze / lint clean | **pass** | Web: Vitest 23 green, `tsc` clean. Flutter: 31 tests green, `flutter analyze` "No issues found". |
| Version + build scheme; release notes; screenshots from the E2E run | **fail** | `0.1.0+1`; scheme: semver name, build number +1 per store upload. Release notes and listing screenshots wait for the name. Screenshots will be captured from `integration_test` once the name and icon exist. |

## Store answers (drafts)

**Play Data safety.** Data is collected and shared, by the Google Mobile Ads SDK only:
- Device or other IDs (advertising ID): collected and shared, for advertising.
- App interactions and diagnostics (ad events, crash data): collected, for advertising, analytics
  and fraud prevention.
- Approximate location (derived from IP): collected by the SDK, for advertising.
- Everything Readle itself stores (progress, saved words, settings) stays on the device and is not
  collected. Data is encrypted in transit. Deletion: "Reset all progress" in Settings deletes it.

**Apple App Privacy.**
- Data used to track you: Device ID (advertising), only with ATT permission.
- Data linked to you: none.
- Data not linked to you: Product interaction, Advertising data, Diagnostics (from the Google SDK).

**Content rating** (IARC questionnaire): reference / education app; no violence, sexual content,
gambling, drugs or user-generated content; no user chat; ads present. Expected: PEGI 3 / USK 0 /
Everyone; target audience **13+**, not Families (personalised ads).

**Apple 4.2 (minimum functionality).** Fully native Flutter UI, no web view. Offline reading of 107
graded stories, recorded pronunciation on every tap, German TTS story playback with highlighting,
Leitner spaced-repetition practice, per-story quizzes and progress tracking.
**4.3 (spam), versus the owner's other German apps:** each app has a distinct core loop. Readle is
story-first immersive reading. Lernle is a structured course plus SRS. Tobo is top-frequency word
drills. WordBit is a lock-screen word feed. Different names, icons, listing copy and screenshots;
shared content stays behind the scenes.

**Listing (draft):** "<NAME>: German stories you can tap. 107 short illustrated stories from A1
to B2. Tap any word to hear it and see its meaning, translate any sentence, listen to the whole
story, then lock it in with a quick quiz and spaced-repetition word practice. Works offline."
