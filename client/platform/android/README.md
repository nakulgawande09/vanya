# Android

| Setting | Value |
|---|---|
| Package | `com.curiosapien.vanya` |
| Min / target SDK | 24 / 36 (Play requires target 36 since 31 Aug 2026) |
| ABIs | arm64-v8a, armeabi-v7a |
| Build | Gradle build template (needed for plugins: AdMob, billing, ADPF) |
| Presets | `Android Debug` (APK), `Android Release` (AAB), in `client/export_presets.cfg` |
| Version | `version/name` SemVer; `version/code = MAJOR*10000 + MINOR*100 + PATCH`. Bump both in the presets for each release |

## Toolchain (from Godot 4.7.2's `config.gradle`)
- JDK 17
- Android SDK: `platform-tools`, `platforms;android-36`, `build-tools;36.1.0`, `ndk;29.0.14206865`

## Local debug build
1. Install the SDK packages above (Android Studio's SDK Manager, or `sdkmanager`).
2. In the Godot editor, go to Editor Settings → Export → Android and set the Android SDK and Java SDK paths.
3. `tools/setup_godot.sh --templates` installs the Android export templates. In the editor, you can instead use Editor → Manage Export Templates.
4. Project → Install Android Build Template. This creates `client/android/build/`, which is gitignored and regenerated.
5. Export the `Android Debug` preset, or run `just export-android-debug`, then `adb install -r out/android/vanya-debug.apk`.
6. Check 16 KB alignment with `tools/check_16kb.sh out/android/vanya-debug.apk`.

Godot signs debug builds with the editor's debug keystore. CI generates a throwaway one.

## Release signing
- Use Play App Signing. Keep the upload keystore out of the repo (`*.keystore` and `*.jks` are gitignored).
- In CI, set these repository secrets: `ANDROID_UPLOAD_KEYSTORE_BASE64` (`base64 -w0 upload.keystore`), `ANDROID_UPLOAD_KEY_ALIAS` and `ANDROID_UPLOAD_KEY_PASSWORD`. Pushing a `v*` tag then builds a signed AAB.
- Locally, Godot reads `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.

## Planned native plugins (Godot Android v2 plugins, Kotlin)
- **Week 3:** ADPF thermal bridge (`PowerManager.getThermalHeadroom()` every 10 s plus `OnThermalStatusChangedListener`) → `ThermalService.thermal_changed`. Also `GameManager.setGameState()` on Android 13+.
- **Week 11–12:** Poing AdMob v5.x and godot-iap (Play Billing 8+), vendored and pinned under `client/addons/`.
- Re-run `tools/check_16kb.sh` after adding any plugin that ships `.so` files.
