# Readle: "make it better" log

One entry per loop of the hub's standing order (`German/docs/better-loop.md`):
measure → the 3 highest-value fixes → build → prove on a device → record. Newest first.

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
