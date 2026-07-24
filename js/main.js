document.addEventListener("DOMContentLoaded", () => {
  applySiteConfig();
  initMobileNav();
});

function applySiteConfig() {
  const cfg = window.TANDEM_SITE;
  if (!cfg) return;

  const showsPaid = cfg.showsPaidPurchaseUI === true;

  document.querySelectorAll("[data-paid-purchase]").forEach((el) => {
    el.hidden = !showsPaid;
  });
  document.querySelectorAll("[data-donations-only]").forEach((el) => {
    el.hidden = showsPaid;
  });

  if (showsPaid) {
    setHref("[data-role='checkout-link']", cfg.checkoutUrl);
  } else {
    // Point any leftover checkout CTAs at donations so stale markup stays safe.
    setHref("[data-role='checkout-link']", cfg.donationsUrl);
  }

  setHref("[data-role='donate-link']", cfg.donationsUrl);
  setHref("[data-role='terms-link']", cfg.termsUrl);
  setHref("[data-role='privacy-link']", cfg.privacyUrl);
  setHref("[data-role='support-link']", cfg.supportEmail ? `mailto:${cfg.supportEmail}` : null);

  document.querySelectorAll("[data-role='mac-license-price']").forEach((el) => {
    el.textContent = cfg.macLicensePriceDisplay || "$X.XX";
  });
  document.querySelectorAll("[data-role='mac-license-price-suffix']").forEach((el) => {
    el.textContent = cfg.macLicensePriceSuffix || "/month";
  });

  document.querySelectorAll("[data-role='appstore-link']").forEach((link) => {
    if (cfg.appStoreUrl) {
      link.href = cfg.appStoreUrl;
      link.removeAttribute("aria-disabled");
      link.classList.remove("is-disabled");
    } else {
      link.href = "#";
      link.setAttribute("aria-disabled", "true");
      link.classList.add("is-disabled");
      link.addEventListener("click", (event) => {
        event.preventDefault();
      });
      if (!link.title) {
        link.title = "App Store link will be added when the listing is live";
      }
    }
  });

  setHref("[data-role='dmg-link']", cfg.dmgDownloadPath);

  wireOptionalDownload(
    "[data-role='windows-download-link']",
    "[data-role='windows-download-status']",
    cfg.windowsDownloadReady ? cfg.windowsDownloadPath : null,
    "Coming soon"
  );
  wireOptionalDownload(
    "[data-role='linux-download-link']",
    "[data-role='linux-download-status']",
    cfg.linuxDownloadReady ? cfg.linuxDownloadPath : null,
    "Coming soon"
  );
}

function wireOptionalDownload(linkSelector, statusSelector, url, comingSoonLabel) {
  document.querySelectorAll(linkSelector).forEach((link) => {
    const status = link.querySelector(statusSelector);
    if (url) {
      link.href = url;
      link.removeAttribute("aria-disabled");
      link.classList.remove("is-disabled");
      if (status) status.textContent = "Download";
    } else {
      link.href = "#";
      link.setAttribute("aria-disabled", "true");
      link.classList.add("is-disabled");
      if (status) status.textContent = comingSoonLabel;
      link.addEventListener("click", (event) => event.preventDefault());
    }
  });
}

function setHref(selector, url) {
  if (!url) return;
  document.querySelectorAll(selector).forEach((el) => {
    el.href = url;
  });
}

function initMobileNav() {
  const toggle = document.querySelector(".nav-toggle");
  const links = document.querySelector(".nav-links");
  if (!toggle || !links) return;

  toggle.addEventListener("click", () => {
    const isOpen = links.classList.toggle("open");
    toggle.setAttribute("aria-expanded", String(isOpen));
  });

  links.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => links.classList.remove("open"));
  });
}
