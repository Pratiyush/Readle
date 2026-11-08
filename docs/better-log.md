# Readle: "make it better" log

One entry per loop of the hub's standing order (`German/docs/better-loop.md`):
measure → the 3 highest-value fixes → build → prove on a device → record. Newest first.

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
