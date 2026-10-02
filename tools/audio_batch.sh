#!/usr/bin/env bash
# Audio Bible A4 batch step for recorded / downloaded sources (ffmpeg only, no sox needed).
# Usage: tools/audio_batch.sh raw_dir out_dir
#   Files in raw_dir are named <archetype_id>__<nn>.wav (e.g. sfx.player.hurt__01.wav).
#   raw_dir/LICENSES.csv (same columns as the theme's) must list each file; rows are appended
#   to out_dir/../LICENSES.csv so lint_deps can check them. CC0, Sonniss-GDC or original only.
# Output: SFX/UI under 1 s → mono 16-bit WAV (Godot imports it as QOA); everything else → OGG.
#   sfx.* / ui.*  trim leading/trailing silence, mono, loudnorm I=-20 LUFS, TP -1 dBTP
#   amb.*         stereo, loudnorm I=-26, TP -1
#   mus.*         stereo, fixed gain only (keeps stems bar-exact and balanced), TP -1 via limiter
# After copying, run: python3 pipelines/audio/import_flags.py and re-import.
set -euo pipefail
IN="${1:?raw_dir}"; OUT="${2:?out_dir}"; MUS_GAIN="${MUS_GAIN:-0}"
mkdir -p "$OUT"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
LIC_OUT="$(dirname "$OUT")/LICENSES.csv"
for f in "$IN"/*.wav; do
  base="$(basename "$f" .wav)"; id="${base%%__*}"; nn="${base##*__}"
  name="$(echo "$id" | tr '.' '_')_${nn}"
  case "$id" in
    mus.*) CH=2; AF="volume=${MUS_GAIN}dB,alimiter=limit=0.89:level=false"; Q=3 ;;
    amb.*) CH=2; AF="loudnorm=I=-26:TP=-1.0:LRA=11"; Q=2 ;;
    *)     CH=1; AF="silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-20:TP=-1.0:LRA=11"; Q=3 ;;
  esac
  ffmpeg -loglevel error -y -i "$f" -ac "$CH" -ar 44100 -af "$AF" -c:a pcm_s16le "$TMP/out.wav"
  secs="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TMP/out.wav")"
  if [[ "$id" =~ ^(sfx|ui)\. ]] && awk "BEGIN{exit !($secs < 1.0)}"; then
    cp "$TMP/out.wav" "$OUT/$name.wav"; out="$name.wav"
  else
    ffmpeg -loglevel error -y -i "$TMP/out.wav" -c:a libvorbis -q:a "$Q" "$OUT/$name.ogg"; out="$name.ogg"
  fi
  row="$(grep -F "$(basename "$f")" "$IN/LICENSES.csv" 2>/dev/null | head -n 1 || true)"
  if [[ -z "$row" ]]; then
    echo "audio_batch: no licence row for $(basename "$f") in $IN/LICENSES.csv" >&2; exit 1
  fi
  echo "$(basename "$OUT")/$out,${row#*,}" >> "$LIC_OUT"
  echo "audio_batch: $f -> $OUT/$out"
done
