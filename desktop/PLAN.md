# Tandem AI Chat — Windows & Linux desktop

Plan for a **full UI** desktop app (parity with TandemMac), developed only under `desktop/`.

## 0. Current state

- **`desktop/`** — Flutter app, TDLib + AI pipeline MVP, Lemon Squeezy gate, system tray.
- **No impact** on Xcode schemes, Swift targets, or App Store / Mac direct archives.

## 1. Product goals (same as Mac direct)

- TDLib session: phone login, monitored chats, AI pipeline (draft / auto-send).
- System tray: always-on when user wants it.
- Settings: Telegram, AI setup, **Lemon Squeezy license** (external billing).
- Distribution: website downloads (`.exe`/zip / AppImage/tar), not Microsoft Store for v1.

## 2. Stack

| Layer | Choice |
|-------|--------|
| UI | Flutter 3.x (Material + Tandem theme) |
| State | Riverpod |
| Storage | SharedPreferences + secure storage for license key |
| Telegram | TDLib via `tdlib` package + platform `libtdjson` |
| Licensing | Lemon Squeezy License API (HTTP, same flow as Mac) |
| Always-on | `window_manager` close-to-hide (tray icon later) |

## 3. Phases

### Phase A — Scaffold

- [x] `desktop/` folder, isolation docs, config template
- [x] `flutter create` via `scripts/bootstrap.sh`
- [x] App shell: navigation, theme, screens
- [x] CI: `.github/workflows/desktop-ci.yml` (`paths: desktop/**`)

### Phase B — TDLib (MVP)

- [x] `tdlib` package + native library loader (`setup-tdlib.sh`)
- [x] Auth flow: phone → code → password → ready
- [x] Chat list + local monitor/reply preferences
- [x] Message receive hooked into pipeline

### Phase C — AI pipeline (MVP)

- [x] Monitor selected chats → prompt → AI destination → parse → draft / auto-send
- [x] Consent gate; Settings for destination / role / enable
- [ ] NEED_CONTEXT follow-ups (deferred)

### Phase D — Licensing & polish

- [x] Lemon Squeezy activate / validate (force re-check) / deactivate
- [x] Pipeline gated when external billing + inactive license
- [x] Per-chat pause (incognito-style skip)
- [x] Close to background (window hide; tray icon deferred)
- [x] `scripts/build-release.sh` for Linux/Windows artifacts
- [x] Website: Windows/Linux download buttons (coming soon until artifacts published)
- [ ] Publish first Win/Linux binaries + flip `windowsDownloadReady` / `linuxDownloadReady`

### Phase E — Beta release

- [x] `scripts/fetch-tdlib-prebuilt.sh` — Linux/Windows TDLib from ivk1800 releases
- [x] Bundle `libtdjson` into release artifacts (`build-release.sh`)
- [x] `TdLibRuntime` resolves library next to executable (release bundles)
- [x] `.github/workflows/desktop-release.yml` — Linux + Windows CI builds, GitHub Release on `desktop-v*` tags
- [ ] Tag `desktop-v0.1.0`, download artifacts, or run workflow with **Publish website**
- [ ] Optional: Authenticode signing for Windows

## 4. Bundle IDs & naming

- Application ID: `com.tandemai.tandemdesktop`
- Display name: **Tandem AI Chat**
- Lemon Squeezy: reuse Mac direct variant (or add Desktop variant in dashboard).

## 5. Sync with Apple app

When Mac/iOS behavior changes, update **`docs/PARITY.md`** manually. Do not share code — share **spec** only.
