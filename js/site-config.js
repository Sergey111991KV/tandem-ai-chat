/**
 * Single source of truth for public URLs on tandem-ai-chat website.
 * Keep in sync with Config/Shared.xcconfig (TANDEM_*_URL) and Config/macOS-Direct.xcconfig (checkout).
 */
window.TANDEM_SITE = {
  /**
   * Master switch — same idea as TANDEM_SHOWS_SUBSCRIPTION_PURCHASE_UI in xcconfig.
   * false = hide Lemon Squeezy / paid pricing; show donations instead.
   * true  = show Subscribe / checkout / pricing.
   */
  showsPaidPurchaseUI: false,

  /** Lemon Squeezy hosted checkout — Mac Premium (only used when showsPaidPurchaseUI is true). */
  checkoutUrl:
    "https://tandem-chat.lemonsqueezy.com/checkout/buy/c9f40173-6751-419d-b148-574e3151d956",

  /** Display price on download.html — keep in sync with Lemon Squeezy variant. */
  macLicensePriceDisplay: "$4.99",
  macLicensePriceSuffix: "/month",

  /** Voluntary donations (destream) — same as TANDEM_DONATIONS_URL in Shared.xcconfig. */
  donationsUrl: "https://destream.net/live/SergeyKosilov/donate",

  termsUrl: "https://addeo.github.io/clowSpeakerT/docs/",
  privacyUrl: "https://addeo.github.io/clowSpeaker/docs/",
  supportEmail: "supp0rt.serg@yandex.com",

  /** Set when the iOS App Store listing is live; null keeps buttons as “coming soon”. */
  appStoreUrl: null,

  dmgDownloadPath: "downloads/TandemAIChat.dmg",

  /** Windows / Linux Flutter desktop builds (Phase D). Null = “coming soon”. */
  windowsDownloadPath: "downloads/TandemAIChat-windows-x64.zip",
  linuxDownloadPath: "downloads/TandemAIChat-linux-x64.tar.gz",
  /** Set true when the zip/tarball is published on GitHub Pages. */
  windowsDownloadReady: true,
  linuxDownloadReady: true,
};
