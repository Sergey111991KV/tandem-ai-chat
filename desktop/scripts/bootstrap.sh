#!/usr/bin/env bash
# Create the Flutter app under desktop/app (Windows + Linux only).
# Safe to re-run: skips if pubspec.yaml already exists.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/app"

if ! command -v flutter >/dev/null 2>&1; then
  echo "==> Flutter SDK not found."
  echo "    Install: https://docs.flutter.dev/get-started/install"
  echo "    Then re-run: ./scripts/bootstrap.sh"
  exit 1
fi

if [[ -f "$APP_DIR/pubspec.yaml" ]]; then
  echo "==> Flutter app already exists at $APP_DIR — skipping create."
  exit 0
fi

echo "==> Enabling desktop platforms..."
flutter config --enable-windows-desktop --enable-linux-desktop 2>/dev/null || true

echo "==> Creating Flutter project in $APP_DIR ..."
mkdir -p "$APP_DIR"
cd "$APP_DIR"
flutter create \
  --org com.tandemai \
  --project-name tandem_desktop \
  --platforms=linux,windows \
  .

echo "==> Done. Next:"
echo "    cd desktop/app && flutter pub get && flutter run -d linux"
