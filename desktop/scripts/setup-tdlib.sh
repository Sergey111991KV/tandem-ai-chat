#!/usr/bin/env bash
# Copy or download TDLib JSON library into desktop/native/tdlib/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NATIVE="$ROOT/native/tdlib"

copy_macos() {
  local src=""
  if [[ -f "$NATIVE/macos/libtdjson.dylib" ]]; then
    echo "==> macOS: already present at $NATIVE/macos/libtdjson.dylib"
    return 0
  fi
  for candidate in \
    /opt/homebrew/lib/libtdjson.dylib \
    /usr/local/lib/libtdjson.dylib; do
    if [[ -f "$candidate" ]]; then
      src="$candidate"
      break
    fi
  done
  if [[ -z "$src" ]] && command -v brew >/dev/null 2>&1; then
    echo "==> Installing tdlib via Homebrew..."
    brew install tdlib
    src="/opt/homebrew/lib/libtdjson.dylib"
  fi
  if [[ ! -f "$src" ]]; then
    echo "==> macOS: libtdjson.dylib not found. Run: brew install tdlib"
    return 1
  fi
  mkdir -p "$NATIVE/macos"
  cp "$src" "$NATIVE/macos/libtdjson.dylib"
  echo "==> macOS: copied to $NATIVE/macos/libtdjson.dylib"
}

setup_linux() {
  if [[ -f "$NATIVE/linux/libtdjson.so" ]]; then
    echo "==> Linux: already present"
    return 0
  fi
  echo "==> Linux: fetching prebuilt libtdjson..."
  "$ROOT/scripts/fetch-tdlib-prebuilt.sh" linux
}

setup_windows() {
  if [[ -f "$NATIVE/windows/tdjson.dll" ]]; then
    echo "==> Windows: already present"
    return 0
  fi
  echo "==> Windows: fetching prebuilt tdjson DLLs..."
  "$ROOT/scripts/fetch-tdlib-prebuilt.sh" windows
}

case "$(uname -s)" in
  Darwin) copy_macos ;;
  Linux) setup_linux ;;
  MINGW*|MSYS*|CYGWIN*) setup_windows ;;
  *) echo "Unknown OS"; exit 1 ;;
esac
