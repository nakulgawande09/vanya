# ADR-0004: Android Gradle build, API 36, arm64 + armv7, CI-built APK/AAB

- **Status:** Accepted (2026-10-01)
- **Context:** The planned plugins (AdMob, Play Billing, the ADPF thermal bridge) need the Gradle build. Play requires target API 36 since 31 Aug 2026, and support for 16 KB page sizes.
- **Decision:**
  - Package `com.curiosapien.vanya`; min SDK 24, target SDK 36; ABIs arm64-v8a and armeabi-v7a; `use_gradle_build = true`.
  - Toolchain pinned to Godot 4.7.2's `config.gradle`: JDK 17, build-tools 36.1.0, NDK 29.0.14206865.
  - GitHub Actions builds a debug APK on every push and runs `tools/check_16kb.sh`. `v*` tags build a release AAB signed with the upload key from repository secrets.
- **Consequences:** `client/android/build/` is regenerated and gitignored; only deliberate overrides will be committed. Keystores never enter the repo.
