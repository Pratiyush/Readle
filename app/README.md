# Readle — Flutter app (Android + iOS)

The store app. It ports the web reader in `../src` to Flutter and ships the same compiled content:
`assets/content` is a symlink to `../public/content`, built by `../tools/build_content.py`.

```sh
flutter pub get
flutter run                                  # a device or simulator
flutter test                                 # unit + widget flows (headless)
flutter test integration_test -d <device>    # the same flows on an emulator, simulator or phone
```

- `lib/content/`: models and `ContentRepository`, the only way screens read stories and the
  dictionary. `LayeredContentRepository` puts stories installed from the german-content CDN
  (`cdn/`: daily manifest check, verified staged download, atomic swap, rollback) over the bundled
  ones; `linker.dart` makes their words tappable with the builder's own rules (tables in
  `assets/linker/`, written by `../tools/build_content.py`). The CDN check is **off by default**:
  build with `--dart-define=CONTENT_CDN_ENABLED=true` to turn it on. Point a debug build at a local CDN
  with `--dart-define=CONTENT_CDN=http://10.0.2.2:8787/` and `../../content/tools/serve`.
  Live smoke test: `flutter test --run-skipped --tags live test/cdn_live_test.dart`.
- `lib/state/app_state.dart`: progress, saved words and settings, in the web app's JSON schema
- `lib/services/speech.dart`: German TTS (`flutter_tts`); Listen is hidden without a German voice
- `test/flows.dart`: end-to-end flows shared by `test/widget_test.dart` and
  `integration_test/app_test.dart`

The bundle id `com.pratiyush.readle` is provisional until the app's final name is chosen.
