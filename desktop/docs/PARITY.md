# Mac UI / behavior parity checklist

Use this when implementing `desktop/app`. Source of truth for the Apple app is **behavior**, not Swift files.

## Auth & Telegram

- [x] TDLib init with user `api_id` / `api_hash`
- [x] Phone → code → 2FA flow
- [x] Session persists under app data directory

## Chats

- [x] Chat list with filters (monitored / all)
- [x] Per-chat: enable monitoring, role, reply mode (draft / auto)
- [x] Thread view for monitored chat
- [x] Per-chat pause (skip pipeline turns)

## AI pipeline

- [x] Single AI destination chat (bot or user)
- [x] Build structured prompt from new messages + role
- [x] Parse AI response; draft or send to Telegram
- [x] Third-party AI consent before first send
- [x] License gate for external billing builds
- [ ] NEED_CONTEXT follow-up turns (Mac protocol depth)

## Settings

- [x] Telegram connection status
- [x] AI setup (destination, role, enable, consent)
- [x] Subscription / license (activate, re-check, deactivate)
- [x] Support link, Terms, Privacy (URLs from config)
- [x] Close to tray preference

## Always-on

- [x] Close to background (process stays alive)
- [ ] Optional start at login (OS-specific, deferred)
- [ ] System tray icon menu (deferred)

## Billing (`external` only on desktop direct builds)

- [x] Activate license key → Lemon Squeezy API
- [x] Periodic validate; force re-check; deactivate
- [x] Up to 3 activations (dashboard setting)

## Out of scope for v1

- iOS StoreKit / Mac App Store IAP
- iCloud sync
- Shared SwiftData schema with Apple app
