#!/usr/bin/env bash
# Installs the pinned Godot editor (headless-capable), and optionally the export templates,
# plus the pinned GdUnit4 addon. Idempotent. Usage:
#   tools/setup_godot.sh               # editor + GdUnit4
#   tools/setup_godot.sh --templates   # also Android export templates
# Prints the Godot binary path on the last line (CI reads it).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/.godot-version")"   # e.g. 4.7.2-stable
TEMPLATE_DIR_NAME="${VERSION/-/.}"                        # e.g. 4.7.2.stable
GDUNIT_VERSION="v6.1.3"
TOOLS_DIR="$ROOT/.tools/godot-$VERSION"
GODOT_BIN="$TOOLS_DIR/Godot_v${VERSION}_linux.x86_64"
RELEASE_URL="https://github.com/godotengine/godot/releases/download/$VERSION"

mkdir -p "$TOOLS_DIR"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Downloading Godot $VERSION editor..." >&2
  curl -fsSL -o "$TOOLS_DIR/godot.zip" "$RELEASE_URL/Godot_v${VERSION}_linux.x86_64.zip"
  unzip -q -o "$TOOLS_DIR/godot.zip" -d "$TOOLS_DIR"
  rm "$TOOLS_DIR/godot.zip"
  chmod +x "$GODOT_BIN"
fi

if [[ "${1:-}" == "--templates" ]]; then
  TEMPLATES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$TEMPLATE_DIR_NAME"
  if [[ ! -f "$TEMPLATES/android_source.zip" ]]; then
    echo "Downloading Godot $VERSION export templates (large)..." >&2
    mkdir -p "$TEMPLATES"
    curl -fsSL -o "$TOOLS_DIR/templates.tpz" "$RELEASE_URL/Godot_v${VERSION}_export_templates.tpz"
    # Only the Android templates are needed; skip the other ~1 GB.
    unzip -q -o -j "$TOOLS_DIR/templates.tpz" 'templates/android_*' 'templates/version.txt' -d "$TEMPLATES"
    rm "$TOOLS_DIR/templates.tpz"
  fi
fi

ADDON="$ROOT/client/addons/gdUnit4"
if ! grep -q "version=\"${GDUNIT_VERSION#v}\"" "$ADDON/plugin.cfg" 2>/dev/null; then
  echo "Installing GdUnit4 $GDUNIT_VERSION..." >&2
  TMP="$(mktemp -d)"
  git clone -q --depth 1 --branch "$GDUNIT_VERSION" https://github.com/godot-gdunit-labs/gdUnit4 "$TMP/gdunit4"
  rm -rf "$ADDON"
  mkdir -p "$ROOT/client/addons"
  cp -r "$TMP/gdunit4/addons/gdUnit4" "$ADDON"
  rm -rf "$ADDON/test" "$TMP"
fi

echo "$GODOT_BIN"
