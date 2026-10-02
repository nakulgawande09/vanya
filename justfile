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

# Compile every project script under strict typing
check: import
    {{godot}} --headless --path client -s ../tools/check_scripts.gd

# Headless CPU benchmark: a grove with 40 beasts (prints one JSON line)
bench: import
    {{godot}} --headless --path client res://bench/bench_swarm_40.tscn

# Re-extract the Asset Bible boards (*.dc.html) into theme SVGs and rebuild theme scenes
art boards:
    python3 pipelines/asset/extract_bible.py {{boards}} --godot {{godot}}
    python3 pipelines/asset/build_scenes.py

# Re-render placeholder audio (needs numpy, scipy, ffmpeg) and rebuild the theme audio manifests
audio:
    python3 pipelines/audio/synth.py
    {{godot}} --headless --path client --import
    python3 pipelines/audio/import_flags.py
    {{godot}} --headless --path client --import
    {{godot}} --headless --path client -s ../tools/build_audio_manifest.gd

# Audio memory budget per quality tier (after import) and loudness report
audio-check: import
    python3 tools/audio_budget.py
    python3 pipelines/audio/synth.py --report

# Boot the game headless for ~2 s to catch script and scene errors
smoke: import
    {{godot}} --headless --path client --quit-after 120

# Debug APK (needs the Android SDK and templates; see client/platform/android/README.md)
export-android-debug:
    {{godot}} --headless --path client -s ../tools/render_icons.gd
    {{godot}} --headless --path client --import
    mkdir -p out/android
    {{godot}} --headless --path client --install-android-build-template --export-debug "Android Debug" ../out/android/vanya-debug.apk

# --- Real-phone feel test (docs/feel-test/feel-test-plan.md) ---------------------------------

package := "com.curiosapien.vanya"

# Install the debug APK on the connected phone and launch it
deploy apk="out/android/vanya-debug.apk":
    adb install -r {{apk}}
    adb shell monkey -p {{package}} -c android.intent.category.LAUNCHER 1

# Connect to a phone over Wi-Fi (pair first: adb pair IP:PORT CODE), then deploy
deploy-wifi address apk="out/android/vanya-debug.apk":
    adb connect {{address}}
    just deploy {{apk}}

# Tail Godot's log on the phone
logcat:
    adb logcat -s godot:V

# Copy the overlay's feeltest_*.csv files off the phone (debug builds; uses run-as)
pull-feeltest:
    mkdir -p out/feeltest
    for f in $(adb exec-out run-as {{package}} ls files | tr -d '\r' | grep '^feeltest_'); do adb exec-out run-as {{package}} cat files/$f > out/feeltest/$f; echo "pulled $f"; done

# Log battery and thermal state from the computer every 10 s (cross-check for the overlay)
phone-stats out="out/feeltest/phone_stats.log":
    mkdir -p out/feeltest
    while true; do date +%T | tee -a {{out}}; adb shell dumpsys battery | grep -E 'level|temperature' | tee -a {{out}}; adb shell dumpsys thermalservice | grep -iE 'headroom|status' | head -n 4 | tee -a {{out}}; sleep 10; done

# Summarise a feel-test CSV for the results template
feeltest-report csv:
    python3 tools/feeltest_report.py {{csv}}
