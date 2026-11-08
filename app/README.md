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
  dictionary (bundled assets today; the german-content CDN can be added behind it later)
- `lib/state/app_state.dart`: progress, saved words and settings, in the web app's JSON schema
- `lib/services/speech.dart`: German TTS (`flutter_tts`); Listen is hidden without a German voice
- `test/flows.dart`: end-to-end flows shared by `test/widget_test.dart` and
  `integration_test/app_test.dart`

The bundle id `com.pratiyush.readle` is provisional until the app's final name is chosen.
