#!/usr/bin/env bash
# Build release artifacts for Linux and/or Windows (run on the matching OS).
# Does not touch the Apple Xcode product.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app"
OUT="$ROOT/dist"
NATIVE="$ROOT/native/tdlib"
mkdir -p "$OUT"

detect_linux_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "x64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "x64" ;;
  esac
}

bundle_linux_tdlib() {
  local arch="$1"
  local bundle="$APP/build/linux/${arch}/release/bundle"
  local src="$NATIVE/linux/libtdjson.so"
  if [[ ! -f "$src" ]]; then
    echo "==> Linux: no libtdjson.so — bundle will use stub Telegram (dev only)"
    return 0
  fi
  mkdir -p "$bundle/lib"
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

zip_windows_release() {
  local release_dir="$1"
  local archive="$2"
  rm -f "$archive"
  if command -v powershell.exe >/dev/null 2>&1; then
    local win_src win_dst
    win_src="$(cygpath -w "$release_dir" 2>/dev/null || echo "$release_dir")"
    win_dst="$(cygpath -w "$archive" 2>/dev/null || echo "$archive")"
    powershell.exe -NoProfile -Command \
      "Compress-Archive -Path (Join-Path '$win_src' '*') -DestinationPath '$win_dst' -Force"
    return 0
  fi
  if command -v zip >/dev/null 2>&1; then
    (cd "$release_dir" && zip -r "$archive" .)
    return 0
  fi
  echo "Need powershell.exe or zip to create $archive"
  exit 1
}

cd "$APP"
flutter config --enable-linux-desktop >/dev/null 2>&1 || true
flutter config --enable-windows-desktop >/dev/null 2>&1 || true
flutter pub get

HOST="$(uname -s)"
case "$HOST" in
  Linux)
    ARCH="$(detect_linux_arch)"
    "$ROOT/scripts/fetch-tdlib-prebuilt.sh" linux
    flutter build linux --release
    bundle_linux_tdlib "$ARCH"
    # Website download link expects this exact x64 filename on CI (ubuntu-latest).
    if [[ "$ARCH" == "x64" ]]; then
      ARCHIVE="$OUT/TandemAIChat-linux-x64.tar.gz"
    else
      ARCHIVE="$OUT/TandemAIChat-linux-${ARCH}.tar.gz"
    fi
    tar -czf "$ARCHIVE" -C "build/linux/${ARCH}/release/bundle" .
    echo "==> Linux bundle: $ARCHIVE"
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
    zip_windows_release "$APP/build/windows/x64/runner/Release" "$ARCHIVE"
    echo "==> Windows zip: $ARCHIVE"
    ;;
  *)
    # GitHub Actions windows bash sometimes reports a longer MINGW name; treat as Windows
    # if the windows folder exists after enabling desktop.
    if [[ -d "$APP/windows" ]] && command -v powershell.exe >/dev/null 2>&1; then
      "$ROOT/scripts/fetch-tdlib-prebuilt.sh" windows
      flutter build windows --release
      bundle_windows_tdlib
      ARCHIVE="$OUT/TandemAIChat-windows-x64.zip"
      zip_windows_release "$APP/build/windows/x64/runner/Release" "$ARCHIVE"
      echo "==> Windows zip: $ARCHIVE"
    else
      echo "Unsupported host OS for desktop release build: $HOST"
      exit 1
    fi
    ;;
esac
