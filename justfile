# Vanya task runner. Install `just` (https://just.systems) or run the commands directly.

godot := `tools/setup_godot.sh 2>/dev/null | tail -n 1`

# Download the pinned Godot editor and GdUnit4
setup:
    tools/setup_godot.sh

# Also download the Android export templates
setup-android:
    tools/setup_godot.sh --templates

# Import assets (needed after a fresh clone and before tests or exports)
import:
    {{godot}} --headless --path client --import

# Dependency rules + Godot 3 API check
lint:
    python3 tools/lint_deps.py

# GdUnit4 unit and scene tests (headless)
client-test: import
    {{godot}} --headless --path client -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests

# Boot the game headless for ~2 s to catch script and scene errors
smoke: import
    {{godot}} --headless --path client --quit-after 120

# Debug APK (needs the Android SDK and templates; see client/platform/android/README.md)
export-android-debug: import
    mkdir -p out/android
    {{godot}} --headless --path client --install-android-build-template --export-debug "Android Debug" ../out/android/vanya-debug.apk
