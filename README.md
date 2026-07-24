# Tandem AI Chat — website

Static site for [Tandem AI Chat](https://github.com/Sergey111991KV/tandem-ai-chat): landing page and Mac download.

**Live URL (after GitHub Pages is enabled):**  
https://sergey111991kv.github.io/tandem-ai-chat/

## Pages

| Page | Purpose |
|------|---------|
| `index.html` | Landing |
| `download.html` | Mac `.dmg` + Lemon Squeezy license checkout |
| `donate.html` | Voluntary donations (Destream) |

## Payment & URLs (`js/site-config.js`)

Edit **`Website/js/site-config.js`** — single place for checkout, donations, legal links, and App Store URL. Keep aligned with:

| Website config | App xcconfig |
|----------------|--------------|
| `checkoutUrl` | `TANDEM_LS_CHECKOUT_URL` in `Config/macOS-Direct.xcconfig` |
| `donationsUrl` | `TANDEM_DONATIONS_URL` in `Config/Shared.xcconfig` |
| `macLicensePriceDisplay` | Lemon Squeezy variant price (manual — update after changing price in dashboard) |
| `appStoreUrl` | Set when iOS listing is live |

### Mac license (Lemon Squeezy)

1. Dashboard checklist: `Config/LemonSqueezySetup-Mac.en.txt`
2. Set real price on variant → update `macLicensePriceDisplay` in `site-config.js`
3. Test checkout in incognito; confirm license email arrives
4. Direct Mac build: `./scripts/archive-tandemmac-direct.sh` → Settings → Subscription → paste key

### Donations (Destream)

- App: Settings → Support → “Support translation (donate)”
- Website: `donate.html` + footer/nav links
- URL: `https://destream.net/live/SergeyKosilov/donate` (same as `TANDEM_DONATIONS_URL`)

### iOS subscription (App Store — not live yet)

- Product ID: `com.tandemai.subscription.monthly`
- Switch `TANDEM_BILLING_PROVIDER = apple` in Release xcconfig when Paid Apps Agreement is active
- Checklist: `Config/AppStoreSubscription-ASC-Checklist.en.md`, QA: `TESTFLIGHT_SUBSCRIPTION_QA.md`

## Deploy

From the main app repo:

```bash
./scripts/deploy-website.sh
```

Requires push access to this repository (GitHub account **Sergey111991KV**).

### First-time GitHub Pages

1. Push this repo to `main`.
2. **Settings → Pages → Build and deployment**
3. Source: **Deploy from a branch**
4. Branch: **main** / **/ (root)**
5. Save — site goes live in 1–2 minutes.

### After notarization

Copy the Mac `.dmg` and redeploy:

```bash
cp /tmp/TandemAIChat-*.dmg Website/downloads/TandemAIChat.dmg
./scripts/deploy-website.sh
```
