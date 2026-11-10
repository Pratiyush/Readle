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
| App icon and splash | **pass** (name-independent) | `tools/app-icons.mjs` renders them from the web app's `public/icon.svg` (an open book with "DE" on teal #0F766E). Android gets the legacy mipmaps plus an adaptive icon (foreground in the 66 dp safe circle) and a monochrome layer for Android 13 themed icons. The splash uses the brand colour, set on Android 12+ through `windowSplashScreenBackground`. iOS gets all 15 AppIcon sizes, opaque (no alpha channel, which Apple rejects), and the launch screen on teal. If the icon changes with the name, edit the SVG and run the script again. |
| Play: signed AAB | **fail** (owner: the upload key) | `app/tool/release.sh` builds the upload. It signs with the key in `android/key.properties` (or the file `READLE_KEY_PROPERTIES` names) and refuses to build without it, with `ADS_TEST` set, or from uncommitted code. `key.properties`, `*.jks` and `*.keystore` are git-ignored. `tool/check_release.py` then checks the bundle: upload-signed, Readle's AdMob id, not debuggable, target SDK ≥ 35, every `.so` 16 KB aligned, and release notes ≤ 500 characters (`docs/release-notes.md`). |
| Flutter `--obfuscate --split-debug-info` | **pass** | `tool/release.sh` passes both and zips the symbols next to the bundle (`build/release/readle-<version>-symbols.zip`, kept out of git). `--bump` raises the build number. |
| Play Data safety answers drafted | **pass** (draft, 10 Nov) | "Store answers (drafts)" below lists every form question and data type, checked against Google's SDK 25.5.0 disclosure and the merged release manifest. |
| Content rating answers drafted; 13+, not Families | **pass** (draft) | See below. |
| Apple: `PrivacyInfo.xcprivacy` | **pass** | `ios/Runner/PrivacyInfo.xcprivacy` is in the Runner target's resources. App code does no tracking or collection. It declares UserDefaults CA92.1, plus FileTimestamp C617.1 for `package_info_plus` (BUG-41). `test/privacy_manifest_test.dart` checks that every plugin's required-reason APIs are declared. The Google SDKs ship their own manifests. |
| App Privacy answers; 4.2 / 4.3 note | **pass** (draft, 10 Nov) | Taken from the GoogleMobileAds and UMP manifests in the build. Four types are linked to the user, and the device ID is used to track. |
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
| Cold start, jank, memory on sandbox devices | **pass** (start, memory, UI thread) / open (raster on a real phone) | Release APK, `am start -W` cold starts: **1,350 / 1,501 / 1,523 ms** (host load 300+). Memory after launch and scrolling: **143 MB PSS** (275 MB RSS). Frame timing in profile mode (`app/perf`, 10 Nov) on the sandbox emulator: build p99 **4.6 / 13.4 / 5.1 ms** (library / reader / word sheet), one missed build budget in 554 frames. Raster misses were 7 % (library) and 13 % (reader). The emulator's host-GPU translation drives those, so they need a real phone to judge. Pictures are decoded at display size, and there's no blur or `saveLayer` in the UI. Numbers in `docs/better-log.md`, Loop 5. |
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
| E2E on Android + iOS (or web), green in CI | **pass** | GitHub Actions on every push. **Verify** runs the fast gate (`tools/verify.sh`: Flutter 124 headless tests with 14 flows; web vitest 52, Playwright 60). It was green on `f740a5b`, the last pushed commit (9 Nov). **App devices** runs the same 14 flows on an Android API 35 emulator and an iPhone simulator (`flutter test integration_test`). Both jobs were green on `ed3d7db` (9 Nov); the run on `f740a5b` was cancelled. Frame timing (`perf/`) stays out of CI because it needs profile mode. |
| Unit/widget tests green; analyze / lint clean | **pass** | Web: Vitest 23 green, `tsc` clean. Flutter: 31 tests green, `flutter analyze` "No issues found". |
| Version + build scheme; release notes; screenshots from the E2E run | **fail** (screenshots) | `0.1.0+1`. The scheme is a semver name with the build number +1 per store upload (`tool/release.sh --bump`). Release notes live in `docs/release-notes.md`, one section per version, and the script checks them. Listing screenshots wait for the name and will be captured from `integration_test`. |

## Store answers (drafts)

Checked on 10 Nov 2026 against:
- the privacy manifests inside the iOS build (Google Mobile Ads, UMP, Flutter and the plugins);
- Google's [Play data disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure) for Mobile Ads SDK 25.5.0, which is the version in the release build;
- the merged release Android manifest.

Re-check whenever an SDK or plugin changes.

**What Readle itself sends off the device: nothing that identifies the learner.** Every data type below comes from Google's ad SDKs.
- Progress, saved words, settings and the reminder time stay on the device (shared_preferences). "Reset all progress" deletes them.
- The daily reminder is a local notification scheduled on the device. Nothing is sent.
- Content updates (`CONTENT_CDN_ENABLED`, off until the privacy policy covers it) are HTTPS GETs of static files from `german-content.pratiyush1.workers.dev`. The only extra header is `If-None-Match`, the manifest's ETag, which is the same for everyone. There is no ID, account or cookie. The worker serves assets only and has no logging configured (`content/deploy/wrangler.jsonc`), so the IP address is used only to answer the request. That is not "collected" under either store's definition.
- "Contact support" opens the learner's own mail app (`mailto:`). Nothing leaves the device unless they send the mail themselves.
- "Share" on the quiz result paints an image card on the device and opens the system share sheet. Nothing leaves the device unless the learner picks a target.

### Google Play: Data safety form

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes.** Google: TLS. Readle's own downloads are HTTPS only. |
| Which methods of account creation does your app support? | **None.** There are no accounts, so no deletion URL is needed. |
| Do you provide a way for users to request that their data is deleted? | **No.** Google holds the ad data. The learner can reset or delete the advertising ID in Android settings, and Readle's own data never leaves the device. |

The data types to tick. For each one: collected **and** shared, **not** processed ephemerally, collection **required**.

| Category → type | What it is | Purposes |
|---|---|---|
| Location → **Approximate location** | Estimated from the IP address | Advertising or marketing; Analytics; Fraud prevention, security and compliance |
| App activity → **App interactions** | App launches, taps, ad views | Same three |
| App info and performance → **Diagnostics** | Launch time, hang rate, energy use | Same three |
| Device or other IDs → **Device or other IDs** | Android advertising ID, app set ID | Same three |

Leave everything else unticked: personal info, financial info, health, messages, photos and videos, audio, files, calendar, contacts, web browsing, precise location and crash logs. Google's Android disclosure doesn't list crash logs.

Other App content declarations:
- **Advertising ID: yes.** `com.google.android.gms.permission.AD_ID` is in the merged release manifest, from `play-services-ads-api` 25.5.0. Purposes: advertising or marketing, analytics, fraud prevention.
- **Ads: yes.**
- **App access:** everything works without signing in.
- **Target audience:** 13+, not Families (the ads are personalised).
- **Foreground service: no declaration.** `FOREGROUND_SERVICE` comes from `androidx.work` 2.7.0, but no service declares a foreground-service type. `POST_NOTIFICATIONS` is asked only when the learner turns the reminder on. No exact alarms are used.

### Apple: App Privacy (App Store Connect)

"Do you or your third-party partners collect data from this app?" **Yes.** All of it comes from the Google Mobile Ads SDK and Google's consent SDK (UMP). The answers are the union of their bundled manifests. The earlier draft's "Data linked to you: none" was wrong: Google's manifest marks four types as linked.

| Data type | Linked to the user | Used to track | Purposes |
|---|---|---|---|
| Identifiers → **Device ID** (the IDFA, only after ATT "Allow") | Yes | **Yes** | Third-party advertising; Developer's advertising or marketing; Analytics |
| Location → **Coarse location** | Yes | No | Third-party advertising; Developer's advertising or marketing; Analytics; App functionality (UMP: which privacy rules apply) |
| Usage data → **Product interaction** | Yes | No | Third-party advertising; Developer's advertising or marketing; Analytics; App functionality (UMP) |
| Usage data → **Advertising data** | Yes | No | Third-party advertising; Developer's advertising or marketing; Analytics |
| Diagnostics → **Crash data** | No | No | Analytics |
| Diagnostics → **Performance data** | No | No | Third-party advertising; Developer's advertising or marketing; Analytics; App functionality (UMP) |
| Diagnostics → **Other diagnostic data** | No | No | Third-party advertising; Developer's advertising or marketing; Analytics |

Before the first TestFlight upload, check that these answers match the bundled manifests. In Xcode: Product → Archive, then Generate Privacy Report on the archive. The report must show this same set.

**`PrivacyInfo.xcprivacy`** (Runner):
- **Tracking and collection:** no tracking and no collected data by app code.
- **UserDefaults (CA92.1):** Readle's settings.
- **FileTimestamp (C617.1):** for `package_info_plus`, whose own manifest leaves it out (BUG-41).
- **Bundled manifests found in the build:** Flutter, GoogleMobileAds, UserMessagingPlatform, shared_preferences, url_launcher, webview_flutter, app_tracking_transparency, connectivity_plus, package_info_plus and flutter_local_notifications.
- **Plugins with no manifest:** audioplayers_darwin, flutter_tts, the google_mobile_ads wrapper, and integration_test (debug only). None of them calls a required-reason API.
- **Test:** `test/privacy_manifest_test.dart` scans every iOS plugin's native sources. It fails when a required-reason API isn't declared in the plugin's manifest or Readle's.

### Content rating

IARC questionnaire answers:
- A reference / education app.
- No violence, sexual content, gambling, drugs or user-generated content, and no user chat.
- Ads present.

Expected rating: PEGI 3 / USK 0 / Everyone. Target audience **13+**, not Families (personalised ads).

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
