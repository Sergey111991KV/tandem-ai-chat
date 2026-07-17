#!/usr/bin/env bash
# Build release artifacts for Linux and/or Windows (run on the matching OS).
# Does not touch the Apple Xcode product.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app"
OUT="$ROOT/dist"
NATIVE="$ROOT/native/tdlib"
mkdir -p "$OUT"

bundle_linux_tdlib() {
  local bundle="$APP/build/linux/x64/release/bundle"
  local src="$NATIVE/linux/libtdjson.so"
  if [[ ! -f "$src" ]]; then
    echo "==> Linux: no libtdjson.so — bundle will use stub Telegram (dev only)"
    return 0
  fi
  cp "$src" "$bundle/lib/libtdjson.so"
  echo "==> Linux: bundled libtdjson.so into release lib/"
}

bundle_windows_tdlib() {
  local bundle="$APP/build/windows/x64/runner/Release"
  local src_dir="$NATIVE/windows"
  if [[ ! -f "$src_dir/tdjson.dll" ]]; then
    echo "==> Windows: no tdjson.dll — bundle will use stub Telegram (dev only)"
    return 0
  fi
  for dll in tdjson.dll libcrypto-1_1.dll libssl-1_1.dll zlib1.dll; do
    if [[ -f "$src_dir/$dll" ]]; then
      cp "$src_dir/$dll" "$bundle/"
    fi
  done
  echo "==> Windows: bundled TDLib DLLs into Release/"
}

cd "$APP"
flutter pub get

case "$(uname -s)" in
  Linux)
    "$ROOT/scripts/fetch-tdlib-prebuilt.sh" linux
    flutter build linux --release
    bundle_linux_tdlib
    ARCHIVE="$OUT/TandemAIChat-linux-x64.tar.gz"
    tar -czf "$ARCHIVE" -C build/linux/x64/release/bundle .
    echo "==> Linux bundle: $ARCHIVE"
    echo "    Optional: convert to AppImage with your preferred tooling."
    ;;
  Darwin)
    echo "==> On macOS this builds the Flutter macOS target for local smoke tests only."
    flutter build macos --release
    echo "==> macOS: $APP/build/macos/Build/Products/Release/tandem_desktop.app"
    echo "    Windows/Linux release builds must run on those OSes (or CI runners)."
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    "$ROOT/scripts/fetch-tdlib-prebuilt.sh" windows
    flutter build windows --release
    bundle_windows_tdlib
    ARCHIVE="$OUT/TandemAIChat-windows-x64.zip"
    # shellcheck disable=SC2086
    powershell.exe -Command "Compress-Archive -Path 'build\\windows\\x64\\runner\\Release\\*' -DestinationPath '$ARCHIVE' -Force" \
      2>/dev/null || (
        cd build/windows/x64/runner/Release && zip -r "$ARCHIVE" .
      )
    echo "==> Windows zip: $ARCHIVE"
    ;;
  *)
    echo "Unsupported host OS for desktop release build."
    exit 1
    ;;
esac
