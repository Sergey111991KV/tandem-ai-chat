#!/usr/bin/env bash
# Download prebuilt TDLib JSON libraries for Linux/Windows into desktop/native/tdlib/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NATIVE="$ROOT/native/tdlib"
TAG="${TDJSON_TAG:-linux-x64-1.8.39-18618ca}"
WIN_TAG="${TDJSON_WIN_TAG:-windows-x64-1.8.39-18618ca}"
BASE="https://github.com/ivk1800/td-json-client-prebuilt/releases/download"

fetch_linux() {
  local dest="$NATIVE/linux/libtdjson.so"
  if [[ -f "$dest" ]]; then
    echo "==> Linux: already present at $dest"
    return 0
  fi
  mkdir -p "$NATIVE/linux"
  local tmp
  tmp="$(mktemp -d)"
  echo "==> Linux: downloading libtdjson ($TAG)..."
  curl -fsSL -o "$tmp/libtdjson.zip" "$BASE/$TAG/libtdjson.zip"
  extract_zip "$tmp/libtdjson.zip" "$tmp"
  cp "$tmp/libtdjson.so" "$dest"
  rm -rf "$tmp"
  echo "==> Linux: saved to $dest"
}

fetch_windows() {
  local dest_dir="$NATIVE/windows"
  if [[ -f "$dest_dir/tdjson.dll" ]]; then
    echo "==> Windows: already present in $dest_dir"
    return 0
  fi
  mkdir -p "$dest_dir"
  local tmp
  tmp="$(mktemp -d)"
  echo "==> Windows: downloading tdjson DLLs ($WIN_TAG)..."
  curl -fsSL -o "$tmp/dlls.zip" "$BASE/$WIN_TAG/dlls.zip"
  extract_zip "$tmp/dlls.zip" "$dest_dir"
  rm -rf "$tmp"
  echo "==> Windows: saved to $dest_dir"
}

extract_zip() {
  local archive="$1"
  local dest="$2"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q -o "$archive" -d "$dest"
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command "Expand-Archive -Path '$archive' -DestinationPath '$dest' -Force"
  else
    echo "Need unzip or PowerShell to extract $archive"
    exit 1
  fi
}

usage() {
  echo "Usage: $0 [linux|windows|all]"
  exit 1
}

target="${1:-all}"
case "$target" in
  linux) fetch_linux ;;
  windows) fetch_windows ;;
  all)
    fetch_linux
    fetch_windows
    ;;
  *) usage ;;
esac
