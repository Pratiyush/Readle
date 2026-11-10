# Readle: test plan

Standard: `German/docs/e2e-standard.md`. Two tiers, one command each:

| Tier | Command | Budget | What |
|---|---|---|---|
| **Fast gate** | `tools/verify.sh` (app and web in parallel, Europe/Berlin) | ≤ 3 min | `dart format`, `flutter analyze`, `flutter test` (unit, widget, the headless flows with fakes); `tsc`, Vitest, production build, Playwright (phone 375 px + tablet 768 px). CI runs it on every push (`.github/workflows/verify.yml`). |
| **Device tier** | `flutter test integration_test -d <device>` under `../tools/heavy-lock.sh` | ≤ 15 min | the same flows on an emulator / simulator, plus the banner with Google test ads (`integration_test/ads_test.dart`). CI: `.github/workflows/app.yml`. |

Every fix lands with a test that failed before it. Fast-gate runtime is recorded in `docs/status.json` → `metrics`.

## End-to-end flows

App (`app/test/flows.dart`, run headless by `test/widget_test.dart` and on devices by `integration_test/app_test.dart`):

1. First launch: pick a level, or "Not sure? Start at A1" (every level in sequence)
2. Library search, filters and the story of the day
3. Tap a word, save it, sentence translations, names left unglossed
4. Listen reads every sentence and stops when you leave
5. Listen from here: one sentence, then on to the end
6. Finish a story, quiz, progress
7. Practice saved words with spaced repetition
8. Settings: dark theme, story level, reset
9. Continue reading: card, then back to the same place
10. First run: the tap-a-word tip until the first tap
11. New stories from the CDN: offer, install, read a downloaded story's words
12. Daily reminder: off by default, permission asked only when turned on (denied → stays off), a new time, off
13. New stories on Wi-Fi: allowed in Settings (off by default), installed by the next daily check without a tap, shown in the library already on screen
14. A CDN that needs a newer app: the library says so, "Update app" opens the Play listing, installed stories keep working

Web (`e2e/*.spec.ts`): library, reader, reading (Continue reading, tip, Listen from here, German-voice gate), practice and quiz, offline (library, stories, recorded clips), a11y (contrast, 200 % text, modal sheet, chips), PWA icons, edges.

## Edge and boundary matrix

✓ = covered (test named), N/A = doesn't apply (why).

### Data
| Case | App | Web |
|---|---|---|
| Empty list (no story matches) | ✓ flow 2 (`zzzz` search) | ✓ `edges.spec` (Unread when all read), `library.spec` |
| One item / the last item (every story read) | ✓ `story_of_the_day_test` (offers a read story again) | ✓ `edges.spec` every story read; `screens.test` |
| Max size (all 107 stories, 1,344 entries) | ✓ `content_test`, `linker_test` golden (10,870 tokens) | ✓ `content.test`, `library.spec` (107 cards) |
| A bundled file that fails to load once | ✓ `edge_cases_test` (caller gets the error, nothing else escapes, the retry loads: BUG-40) | N/A |
| Haptics on success: light tap on a right quiz answer, medium on a quiz finished at ≥ 80 %, selection click on "Knew it"; a wrong answer is silent | ✓ `haptics_test` (records `HapticFeedback.vibrate` on the platform channel) | device: felt on the sandbox |
| Share a finished story: a 1080 × 1350 PNG card (picture, German title, level, streak, score, first sentence) and a line of text to the share sheet | ✓ flow `finish a story, quiz, progress` (RecordingSharer: PNG signature, size from IHDR, German title in the text) | device: Android share sheet |
| iOS privacy manifest: every required-reason API a plugin calls is declared (App Store ITMS-91053) | ✓ `privacy_manifest_test` (scans each iOS plugin's native sources against its manifest and Readle's: BUG-41) | N/A |
| Duplicate ids (CDN story = bundled story) | ✓ `content_client_test` (bundled `brot` skipped, 108 in library) | N/A: web has no CDN source |
| Missing optional fields (no picture, no thumb) | ✓ `edge_cases_test` (missing picture renders, no error) | ✓ placeholder `📖` (`Library.tsx`), thumbs fall back to hero |
| Corrupt / truncated JSON (saved state) | ✓ `edge_cases_test` | ✓ `edges.test` |
| Reminder time out of range or of the wrong type (-1, 1440, "19:00", 600.5) | ✓ `reminder_test` (falls back to 19:00, alone) | N/A |
| A field or entry of the wrong type | ✓ `edge_cases_test` (BUG-36) | ✓ `edges.test`, `edges.spec` (BUG-37) |
| Unknown schema version (manifest@2) | ✓ `content_client_test` edges | N/A |

### German text
| Case | App | Web |
|---|---|---|
| Umlauts and ß | ✓ `linker_test`, `edge_cases_test` (dates), clip matching (`content.test` BUG-26) | ✓ `screens.test` (Äpfel, Fuß blanking) |
| Very long compounds | ✓ `edge_cases_test` (48-letter word, 320 px, 200 %), `whole_words_text_test`, `a11y_test` 310 % | ✓ `a11y.spec` 200 % (hyphenated titles) |
| Inflected forms → headword (gibt → geben) | ✓ flow 3, `linker_test` | ✓ `reader.spec`, `screens.test` |
| Compounds glossed by their head (Haustür → Tür) | ✓ `linker_test` | ✓ `reader.spec` |
| Names stay unglossed (Deutschland) | ✓ flow 3 | ✓ `reader.spec` |
| "sich" headwords, separable verbs | N/A: the linker resolves single tokens; separable prefixes stay unlinked by design (golden test pins the behaviour) | same |
| Plural "—" / multiple translations / long examples | ✓ word sheet in flow 3 and `a11y_test` (200 %, 310 %) | ✓ `reader.spec` |
| Same spelling, different sound (weg / Weg) | ✓ clip matcher refuses heteronyms (`build_content.py`, `content.test` pins `weg` unrecorded) | same content |

### Time (tests run in Europe/Berlin)
| Case | App | Web |
|---|---|---|
| Midnight rollover | ✓ `edge_cases_test` | ✓ `edges.test` |
| DST nights (29 Mar, 25 Oct 2026) | ✓ `edge_cases_test` (addDays, streak) | ✓ `edges.test` |
| Leap day, year end | ✓ `edge_cases_test` | ✓ `edges.test` |
| Clock moved backwards | ✓ `content_client_test` (BUG-35) | N/A: no daily check on the web |
| 24 h daily-check edge (23:59 / 24:01) | ✓ `content_client_test` | N/A |
| Streak day boundaries | ✓ `logic_test`, `edge_cases_test` | ✓ `store.test` |
| Daily reminder: at / one minute before the time, 23:59 → 00:00, DST nights (23 h / 25 h apart, same wall clock), a time in the spring-forward gap, year end, leap day | ✓ `reminder_test` | N/A: the web app has no scheduled notifications (no push server) |
| Reminder skipped once you read or practised today; quiet after 7 days away | ✓ `reminder_test` | N/A |

### Levels
| Case | App | Web |
|---|---|---|
| Each single level | ✓ flow 1 (B1), flow 8 (A2), `story_of_the_day_test` | ✓ `edges.spec` (B2, A2, B1) |
| All levels, in sequence A1 → B2 | ✓ flow 1, `story_of_the_day_test` | ✓ `screens.test`, `edges.spec` |
| Switching level mid-session | ✓ flow 2 | ✓ `edges.spec` |
| A level with every story read | ✓ `story_of_the_day_test` | ✓ `screens.test` |

### Lifecycle
| Case | App | Web |
|---|---|---|
| First run vs upgrade from an older build | ✓ flow 1, `app_state_test` (old state skips onboarding) | ✓ `store.test` defaults merge |
| Restart restores state | ✓ `app_state_test`, flow 9 | ✓ `edges.test` (state loaded from storage), `reading.spec` (tip stays gone on the next story) |
| Process death mid-download | ✓ `content_client_test` (staging discarded, previous set kept) | N/A |
| Rapid double taps (Download twice) | ✓ `content_client_test` (installs once) | N/A |
| Back mid-flow (leave while listening) | ✓ flow 4 | ✓ `reader.spec` |
| Two tabs at once | N/A | ✓ `store.test` (BUG-21) |
| Rotation, backgrounding during audio/ads | Device tier only (not automated yet) | N/A |
| Off by default: no notification call, no permission prompt at launch | ✓ `reminder_test`, flow 12 | N/A |
| Reminder on, notifications blocked later in system settings | ✓ `reminder_test` (Settings says so, opens the system page; gone once allowed) | N/A |
| Reminder from the lock screen; reading on through a screen lock | Device tier, by hand (`docs/better-log.md`) | N/A |

### Network / CDN
| Case | App | Web |
|---|---|---|
| Offline | ✓ `content_client_test`, device pass in airplane mode | ✓ `offline.spec`, `offline-audio.spec` |
| 304 / ETag | ✓ `content_client_test`, `content_e2e_test` (real HTTP) | N/A |
| Hash mismatch, half-downloaded file | ✓ `content_client_test` (refused, previous kept) | N/A |
| `min_client` too new | ✓ `content_client_test` | N/A |
| Server 500, not-JSON, wrong schema | ✓ `content_client_test` edges | N/A |
| Off-host or `..` paths, unsafe slugs | ✓ `content_client_test` (BUG-33, BUG-34) | N/A |
| Flag off: no request at all | ✓ `content_client_test`, flow 8 (no check tile) | N/A |
| Auto-update not allowed (default) / allowed on Wi-Fi / allowed on mobile data | ✓ `content_client_test` (offer only / installs / offer only), flow 13 | N/A |
| Auto-update fails mid-download | ✓ `content_client_test` (offer stays, previous set kept) | N/A |
| Nothing new: no network question asked | ✓ `content_client_test` | N/A |
| `min_client` too new: store link | ✓ flow 14 (Android link; iOS text only until the App Store record exists) | N/A |
| Live CDN | ✓ `cdn_live_test` (tag `live`, run before a release) | N/A |

### Ads / consent
| Case | App | Web |
|---|---|---|
| ADS_ENABLED off: no SDK calls | ✓ `ads_config_test`, every flow runs with `NoAds` | N/A: no ads on the web |
| Test units in debug, Readle's units in release | ✓ `ads_config_test` | N/A |
| Frequency caps at the boundary, never in session 1 | ✓ `interstitial_policy_test` | N/A |
| Banner size cap | ✓ device tier `ads_test` (≤ 120 dp) | N/A |
| Consent obtained / denied / not required, ATT allowed / denied | Device tier, by hand (UMP and ATT are native forms; a release-like iOS check is a todo) | N/A |

### Audio
| Case | App | Web |
|---|---|---|
| Clip present | ✓ flow 3 | ✓ `reader.spec` |
| Clip missing → device voice (logged) | ✓ flow 3 (Deutschland) | ✓ `reader.spec` |
| Clip fails to play → device voice | ✓ `edge_cases_test` | ✓ `wordAudio.ts` catch, `reader.spec` |
| No German voice → Listen hidden | ✓ `edge_cases_test` | ✓ `reading.spec` (BUG-11) |
| Every named clip exists | ✓ `content.test` | same content |

### Accessibility and layout
| Case | App | Web |
|---|---|---|
| Font scale 1.0 and 2.0 (and iOS 310 %) | ✓ `a11y_test` (320×640 at 200 %, 310 %), device pass at 2.0 | ✓ `a11y.spec` 200 % |
| Smallest width (320 / 360) | ✓ `a11y_test` 320 px, `edge_cases_test` | ✓ `a11y.spec` 375 px |
| Dark mode | ✓ `a11y_test` (contrast on every tab, onboarding) | ✓ contrast audit |
| Labels, 48 dp targets, contrast | ✓ `a11y_test` (Flutter guidelines) | ✓ `a11y.spec` (modal sheet, aria-pressed, contrast) |

### Numbers at the edges
| Case | App | Web |
|---|---|---|
| Quiz 0 / 49 / 50 / 79 / 80 / 100 % | ✓ `edge_cases_test` | ✓ `edges.test` |
| Due badge 99 → 99, 100 → 99+ | ✓ `edge_cases_test` | same rule in `App.tsx` |
| Reading time for 0 / 1 words → 1 min | ✓ `edge_cases_test` | ✓ build (`reading_minutes`) |
| Progress never goes back | ✓ app state | ✓ `store.test` |
