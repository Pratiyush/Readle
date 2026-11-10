# Readle: "make it better" log

One entry per loop of the hub's standing order (`German/docs/better-loop.md`):
measure → the 3 highest-value fixes → build → prove on a device → record. Newest first.

## Loop 5 (2026-11-10): sharing, haptics, release shell, frame timing measured

The hub's todo order came first: store privacy answers, i18n plumbing, the release shell and the
growth item. Then the better loop: gate failures (CI, jank), then feel (haptics). Proof device:
private sandbox emulator `claude-readle` (API 35), profile and debug builds, deleted after. Heavy
lock held 03:12–03:27.

| # | Area (loop step) | Before | After | Proof |
|---|---|---|---|---|
| 1 | Growth | Nothing to share | **Share** on the quiz result: a 1080 × 1350 card with the story picture, German title, level, streak and first sentence, plus the score at 80 % or more, sent to the system share sheet with one line of text (Play link on Android) | Device: the Android share sheet ("Sharing image", text with the link); the card pulled from the app cache, rendered with the real emoji font (`loop5-android-share-card.jpg`, `loop5-android-share-sheet.jpg`); flow + `share_card_test` |
| 2 | Feel | No haptics anywhere | Light tap on a right answer, medium on a quiz finished at ≥ 80 %, click on "Knew it"; wrong answers silent | `haptics_test` (platform channel) |
| 3 | Gate: icon | Flutter's default icon | Book-and-"DE" icon from the web app: legacy, adaptive, monochrome; 15 opaque iOS sizes; splash on teal | Device: launcher dock and the Android 15 splash (`loop5-android-icon-dock.jpg`, `loop5-android-splash.jpg`) |
| 4 | Gate: jank | Not measured (gfxinfo can't see Flutter frames) | Measured in profile mode (`app/perf`, `flutter drive --profile --no-dds`), see below | `build/perf/*.json` |
| 5 | Gate: release | Debug-signed, no script | `tool/release.sh` + `tool/check_release.py`: upload-key signing, obfuscation, symbols zip, signer, AdMob id, target SDK, 16 KB pages, stripping, R8 mapping, notes | A full run with a throwaway key: every check passed. The bundle and key were deleted after, so a test-signed bundle can never reach Play |
| 6 | Gate: iOS privacy | `package_info_plus` reads file dates that no manifest declares (ITMS-91053) | Runner declares FileTimestamp C617.1; a test scans every plugin | `privacy_manifest_test` (BUG-41) |

**Frame timing** (profile mode, sandbox emulator, ads off):

| Scenario | Frames | Build avg / p90 / p99 / worst (ms) | Build misses | Raster avg / p90 / p99 / worst (ms) | Raster misses |
|---|---|---|---|---|---|
| Library scroll (4 flings each way) | 353 | 1.0 / 2.6 / 4.6 / 8.2 | 0 | 5.7 / 10.7 / 17.9 / 26.2 | 25 (7 %) |
| Reader open + scroll (longest story) | 181 | 1.7 / 4.7 / 13.4 / 17.4 | 1 | 6.6 / 16.3 / 20.5 / 48.9 | 23 (13 %) |
| Word sheet (3 opens) | 20 | 1.8 / 3.6 / 5.1 / 5.1 | 0 | 8.0 / 6.8 / 71.1 / 71.1 | 1 |

The UI thread has plenty of headroom: one missed build budget in 554 frames. The raster misses
come from the emulator's GPU, which translates to the host's. App-side causes were ruled out:
every picture is decoded at display size (`ResizeImage` at all four call sites), and there is no
blur, `saveLayer` clip or shader mask. The worst frames are first opens, typical of shader
warm-up. The raster side needs a real phone before anything changes. Not optimised blind.

**Found on the device:** a share card saying "20 % on the quiz" is nothing to brag about, so the
score now shows only at 80 % or more (`share_card_test`).

**Tests:** Flutter 129 headless (+1 live), Vitest 52, Playwright 60; fast gate 33–56 s.

**Next:** raster timing on a real phone; the iOS simulator pass (UMP form and ATT prompt in a
release-like build); UI languages once the owner answers the localization question.

## Loop 4 (2026-11-09): a daily reminder that stays gentle, new stories on Wi-Fi

Daily habit was the better-loop step left open: a learner needs a reason to come back tomorrow, and
a reminder is the standard one. Gentle by design: nothing until the learner turns it on, one a day,
none once they have read or practised that day, and quiet after a week away. Proof device: private
sandbox emulator `claude-readle` (API 35, CET clock), debug and release builds, deleted after; heavy
lock held 15:37–15:57.

| # | Area (loop step) | Before | After | Proof |
|---|---|---|---|---|
| 1 | Daily habit | No reason to return but the streak | **Settings → Daily reminder** (off by default; permission asked only when turned on; time picker, 19:00 default). Seven one-shot reminders kept in step with the state (`DailyReminder`), today's skipped once you read or practise | `reminder_test` (DST 23 h / 25 h, spring-forward gap, 23:59 → 00:00, year end, leap day, bad stored times), flow 12; device: "Don't allow" → switch stays off with the hint, second ask → Allow → `dumpsys alarm` shows 9–15 Nov 19:00; time set to 15:49 → posted **15:49:04** with the screen locked, shown on the [lock screen](better-log/loop4-android-lockscreen-reminder.jpg) (public visibility, book icon), tap → unlock → Readle opens, next reminder tomorrow |
| 2 | Release safety | — | R8 keeps the plugin (Gson) and the icon resource (`res/raw/keep.xml`) | Release APK on the same emulator: time set → seven alarms → posted 15:57:21 (inexact), icon resolved, no crash |
| 3 | Feel: listening | Unknown whether "Listen from here" survives a screen lock | It does: reading continues with the screen off and the reader is idle and correct on unlock | Device: progress 2 → 3 → 6 → 7 over 25 s locked, German voice (de-DE) utterances completing; on unlock "Listen" (not Stop), no Flutter errors |
| 4 | Notifications blocked later | The switch would say on while nothing arrives | Settings re-checks on open / resume and offers "Notifications are off for Readle" → system page | `reminder_test` |
| 5 | Content client (flag off) | Updates only on a tap; "app too old" was text only | Opt-in **Download new stories on Wi-Fi** (never on mobile data; failure keeps the offer); "Update app" → Play listing | `content_client_test` Wi-Fi group, flows 13–14 |
| 6 | Gate | — | Settings shows the version; **Contact support** mails the owner with the version in the subject | `legal_test` |

**Found on the device:** the body "…About three minutes." was cut off on the collapsed lock-screen
card, and not every story is three minutes; it now reads "A short German story is waiting." (the
screenshot shows the old text). **Bug found by the work:** BUG-40 (a failed asset load raised a
second, uncaught error), fixed test-first.

**Tests:** Flutter 117 headless (+1 live), Vitest 52, Playwright 60; fast gate 76 s at load ~55.

**Next:** frame timing in profile mode; for further reminder checks, a test-only hook or a moved
emulator clock rather than waiting on the real one (hub, 9 Nov).

## Loop 3 (2026-11-09, overnight): every open bug, the first launch, a safe content client

The hub's order: fix the open bugs by severity (code-only first while the heavy lock is busy), a
level setting with onboarding, the Android pass when the lock frees, and the content client behind
a `CONTENT_CDN_ENABLED` flag that defaults off.

| # | Area (loop step) | Before | After | Proof |
|---|---|---|---|---|
| 1 | Open bugs (web) | 9 low web bugs open: Listen without a German voice, no PNG icons, notch, no saved position, practice blanking, praise at 20 %, sheet not modal, hidden chip, two tabs overwrite | All 9 fixed (`bf08376`); only BUG-26 (130 clips, Lernle's pipeline) stays open | Playwright 54 green (was 40), Vitest 39: one test per bug |
| 2 | Web parity | Continue reading and the first-run tip were app-only | Both on the web, plus "Listen from here" | `e2e/reading.spec.ts`; [tip](better-log/loop3-web-tip.png), [continue card](better-log/loop3-web-continue.png) at 375 px |
| 3 | First 5 minutes: level | The app opened on a random story of all levels; "All levels" could hand a beginner B2 on day one | First launch asks once: A1–B2, or a pinned **"Not sure? Start at A1"** (every level in order, as in Tobo). "All levels, A1 → B2" now goes in sequence: the story of the day comes from the lowest level with unread stories | Onboarding flow (headless + Android device), sequence unit tests in both apps, 320×640 at 200 % dark: guidelines met. The first build put "Not sure?" below the fold on a 375×812 phone (BUG-32); the flow's on-screen assertion caught it |
| 4 | Content client | Always on; any manifest path was followed, slugs became file names unchecked | Behind `CONTENT_CDN_ENABLED` (default off: no request, no Settings check). Paths must stay on the CDN host, hashes must be sha256, slugs `[a-z0-9-]`, release fetches HTTPS only (BUG-33, BUG-34) | Unit tests: off-host manifest makes no request, traversal slug writes nothing. Live smoke test: A1 images, 6,000+ clip paths, every slug pass |

**Tests:** Flutter 69 headless green + 1 live test (skipped by default), `flutter analyze` clean;
Playwright 54, Vitest 39.

**Android device pass (the one loop 2 couldn't finish), sandbox emulator under host load 20–47
and swap 50/51 GB: all 11 flows green**, in two runs. The first stopped after 7 when the host ran
out of memory; a retry recorded logcat and showed only the emulator's low-memory killer clearing
system processes, no Readle crash. **The banner with Google test ads passed.** A cold start in
dark mode, font scale 2.0 and airplane mode launched in 3.4 s, offline:
[onboarding](better-log/loop3-android-onboarding-dark-font2-offline.jpg) with "Not sure?" pinned
on screen, then the [library](better-log/loop3-android-library-dark-font2-offline.jpg) with an A1
story of the day after tapping it.

## Loop 2 (2026-11-08): test hard, then new stories from the CDN

The hub's order for this loop: test hard first (first run, a whole story, tap-to-translate with
clips, the banner with test ads, offline, large fonts, dark mode) on the web, Android and iOS. Log
every bug the moment it's found (`docs/status.json` → `bugs[]`, backfilled with the 26 found
earlier), fix in priority order with a test for each, then build the content client.

| # | Area (loop step) | Before | After | Proof |
|---|---|---|---|---|
| 1 | Offline (BUG-27, web) | A word clip heard online fell back to the device voice offline: audio elements fetch byte ranges (206), which the service worker never cached | The worker fetches the whole clip once (200), keeps it, and answers every later request with it | `e2e/offline-audio.spec.ts` drives a **real** audio element: `NotSupportedError` before, plays after |
| 2 | Feel: contrast (BUG-28, all) | A1/A2 level chips: white on green/teal at 3.3:1 and 3.7:1 (AA needs 4.5:1) | `#15803d` / `#0f766e`: 5.0:1 and 5.5:1, web and app | `e2e/a11y.spec.ts` checks every level chip; new Flutter test: dark theme meets the contrast guideline on every tab, the reader and the word sheet |
| 3 | Large text (BUG-29, web) | At 200% text, single long German words in card titles widened the page to 422 px on a 375 px phone, so every screen scrolled sideways | Titles are `lang="de"` and hyphenate | `e2e/a11y.spec.ts`: no sideways scroll on 4 screens at 200% |
| 4 | First 5 minutes: level | The level filter lived only in the library chips | **Story level** in Settings too (All, A1 beginner … B2 upper intermediate), the same value; the list and story of the day follow it. Long names wrap instead of overflowing (they overflowed by 84 px at first) | Settings flow sets and resets it (headless + iOS) |
| 5 | German quality: reading time (BUG-15) | All 107 stories said "1 min" (native 120 wpm) | A learner's 60 wpm: 40 stories 1 min, 55 stories 2 min, 12 stories 3 min | Content rebuild; only `minutes` changed |
| 6 | Speed (BUG-10) | List cards loaded the 1536 px hero into a 92 px slot: 3.8 MB on the web, a full-size decode per card in the app | 320 px thumbnails, 580 KB for 105 | Playwright: every card loads a thumb; app content test: thumbs < ¼ of hero bytes |
| 7 | Daily habit: new stories | Only the 107 bundled stories, ever | **Content client**: one manifest check a day, a "📚 N new stories" card only when the CDN has stories the app lacks, download on tap, verified and swapped in atomically. Downloaded stories are tappable: the app links their words with a Dart port of the builder's resolver | Golden test: all 107 bundled stories re-linked with 0 differences over 10,870 words. Unit tests (24 h + 304, hash refusal, rollback, `min_client`, offline), a UI flow (offer → install → read → tap a word only `lexicon.json` knows), E2E over HTTP through `content/tools/serve`, live smoke test (verifies the live A1 pack, >95% of its words linked) |
| 8 | Feel: largest text on iOS (BUG-30, BUG-31) | At iOS's largest accessibility size (~310%) the heading split as "Storie/s", the story-of-the-day title was clipped, chips were cut off; at 200% "Sonntagsruhe" broke as "Sonntags / ruhe" | System text followed up to 200% (WCAG 1.4.4; story text keeps its own size), the daily card grows with its text, chip rows scale, titles shrink just enough to keep every word whole | iOS simulator before/after: [largest text, dark](better-log/loop2-ios-largest-text.jpg); a 310% test asserts nothing is clipped or split; WholeWordsText widget tests |

**Devices.** Android sandbox emulator: the host's load average ran 150–510 (other sessions'
emulators). The first flow passed, then the system server died (`Service package: not found`) and
the run stopped, so the Android pass carries over to a quiet host (todo). **iOS simulator (the
app's first iOS run, private iPhone 17 Pro, iOS 26.5): all 9 flows green**, including the new
CDN flow, and **the library banner with Google test ads rendered at 370×100**
(`integration_test/ads_test.dart`).

**Checked and fine:** dark mode on the web (contrast audit of every visible text), the reader at
200% text, reading a whole story through the quiz (Playwright), offline library and stories.

**Tests:** Playwright 40 green (was 32), Flutter 57 headless green + 1 live test (skipped by
default), `flutter analyze` clean, iOS 9 flows + banner on the simulator.

## Loop 1 (2026-11-08): reading a story picks up where you left it

Readle's identity is stories, so this loop targets the two moments that decide whether a reader
comes back: the first story (does the learner discover tap-a-word?) and the return visit (can they
carry on in one tap?). Proof device: private sandbox emulator (Pixel 7 profile, API 35, port 5562),
debug build with `ADS_ENABLED=true` (debug builds always use Google's test units).

| # | Area (loop step) | Before | After | Proof |
|---|---|---|---|---|
| 1 | Daily habit, reading | The library always opened on the story of the day; leaving a story halfway lost your place (`progress` was saved but never used) | A **Continue reading** card above the story of the day for the last story you opened and haven't finished; the reader reopens at the point you reached. Scrolling records progress, and finished stories are never offered again. | Flow `continue reading: card, then back to the same place` (headless + device): card appears, reopened scroll offset > 0, card gone once finished. Not screenshotted: under host load 80–200 the system's ANR dialogs ate the adb back-press, so the flow test is the proof. |
| 2 | First 5 minutes | The only hint was a grey line ("Tap any word…") that first-time readers skim past | A first-run cue ("👆 Tap any word to hear it and see what it means…") in the accent colour until the learner's first word tap, then the quiet line as before. Persisted, so it never comes back. | Flow `first run: the tap-a-word tip until the first tap` (headless + device). Device screenshot: [first-run tip](better-log/loop1-first-run-tip.jpg). |
| 3 | Gate: privacy policy / Impressum links | Settings had no link to either | **Privacy policy** and **Impressum** tiles in Settings, from one value (`app/lib/config.dart` `legalSlug`, or `--dart-define=LEGAL_SLUG=…`). Hidden while the slug is empty, so no build links to a page that doesn't exist yet. | `test/legal_test.dart`: URL shape, both tiles shown with a slug, none without, no slug baked in. |
| 4 | Ads that don't hurt | The inline library banner hadn't been seen on a device | Verified: `integration_test/ads_test.dart` (debug build, Google test units, SDK started through a test-only hook) scrolls the library and waits for the banner. Found and fixed: the **uncapped inline adaptive banner rendered 379×316**, as tall as 2½ story cards. A capped adaptive request (max 120) was rejected (code 1), so the slot is now a fixed **large banner, 320×100**: rendered **379×100** on the device and asserted ≤120. | `flutter test integration_test/ads_test.dart -d emulator-5562`: banner rendered at 379×316 (before) → 379×100 (after), test green. |

**Tests:** Flutter 41 green headless (`flutter analyze` clean); device flows 8/8 on the sandbox (incl. the two new flows), plus the banner test; web unchanged this loop (Vitest 23,
Playwright 32 green at the start of the loop).

**Next loop candidates:** the same Continue-reading card and first-run cue for the web PWA; a gentle
daily reminder notification (off by default); sentence-level replay ("listen from here"); iOS
simulator run; frame timing in profile mode.
