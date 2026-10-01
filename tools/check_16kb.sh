#!/usr/bin/env bash
# Verifies Google Play's 16 KB page-size requirement for an APK:
#   1. uncompressed .so files are 16 KB aligned inside the zip (zipalign -P 16)
#   2. every 64-bit .so has ELF LOAD segments aligned to >= 16 KB (2**14)
# Usage: tools/check_16kb.sh path/to/app.apk   (needs ANDROID_HOME with build-tools and an NDK)
set -euo pipefail

APK="$1"
BUILD_TOOLS_VERSION="${BUILD_TOOLS_VERSION:-36.1.0}"
ZIPALIGN="$ANDROID_HOME/build-tools/$BUILD_TOOLS_VERSION/zipalign"
OBJDUMP="$(ls "$ANDROID_HOME"/ndk/*/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump 2>/dev/null | head -n 1)"

"$ZIPALIGN" -c -P 16 4 "$APK"
echo "zipalign: OK (16 KB)"

if [[ -z "$OBJDUMP" ]]; then
  echo "llvm-objdump not found (install an NDK); skipping ELF segment check" >&2
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q -o "$APK" 'lib/*' -d "$TMP" 2>/dev/null || true

fail=0
checked=0
while IFS= read -r -d '' so; do
  checked=$((checked + 1))
  if "$OBJDUMP" -p "$so" | awk '/LOAD/ {print $NF}' | grep -qvE '^2\*\*(1[4-9]|2[0-9])$'; then
    echo "NOT 16 KB aligned: ${so#"$TMP"/}" >&2
    fail=1
  fi
done < <(find "$TMP/lib" \( -path '*arm64-v8a*' -o -path '*x86_64*' \) -name '*.so' -print0 2>/dev/null)

if [[ $fail -ne 0 ]]; then
  exit 1
fi
echo "ELF LOAD alignment: OK ($checked 64-bit libraries)"
