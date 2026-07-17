# Desktop — Windows & Linux (scaffold)

Cross-platform desktop app (Windows + Linux) with UI parity to **TandemMac**. Lives in **`desktop/`** only — the iOS/macOS Swift product is not modified.

## Isolation rules

| Allowed | Not allowed |
|---------|-------------|
| Code under `desktop/` | Edits to `TandemAIChat/`, `TandemMac/`, `*.xcodeproj` |
| Copy branding from `Website/assets/` | Swift packages / shared modules with the Apple app |
| Same Lemon Squeezy **public** store/variant IDs | Secrets in git (`config/app_config.local.json`) |
| Website download links (when builds exist) | Changing `Config/*.xcconfig` for desktop builds |

## Stack

- **Flutter** (Windows + Linux)
- **TDLib** (native, platform-specific binaries)
- **Lemon Squeezy** License API (direct distribution, like Mac direct build)

See **`PLAN.md`** for phases and **`docs/PARITY.md`** for feature checklist vs Mac.

## First-time setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (stable, desktop enabled).
2. Bootstrap (already done if `desktop/app/pubspec.yaml` exists):

```bash
cd desktop
./scripts/bootstrap.sh
```

3. Configure Telegram API + TDLib (for real login, not demo):

```bash
cp config/app_config.example.json config/app_config.local.json
# Edit apiId / apiHash from https://my.telegram.org
./scripts/setup-tdlib.sh
```

4. Run:

```bash
cd desktop/app
flutter pub get
flutter run -d macos    # on Mac for local dev
# flutter run -d linux  # on Linux
# flutter run -d windows  # on Windows
```

## Current status (Phases A–D)

- Dark Tandem theme, onboarding → Telegram auth → chats → Settings
- TDLib when `libtdjson` is present; otherwise stub with demo pipeline
- AI pipeline: monitor → prompt → AI destination → draft / auto-send + consent
- Lemon Squeezy license gates the pipeline (external billing)
- Per-chat pause; close-to-background always-on
- Release helper: `./scripts/build-release.sh` (run on Linux/Windows host)
- CI: `.github/workflows/desktop-ci.yml`

## Build (after bootstrap)

```bash
cd desktop/app
flutter build linux --release    # AppImage/deb packaging — see PLAN.md
flutter build windows --release
```

## Config

Copy public defaults and adjust locally:

```bash
cp config/app_config.example.json config/app_config.local.json
```

`app_config.local.json` is gitignored.
