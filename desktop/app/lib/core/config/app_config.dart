class AppConfig {
  const AppConfig({
    required this.appDisplayName,
    required this.bundleId,
    required this.websiteHostPath,
    required this.termsUrl,
    required this.privacyUrl,
    required this.supportEmail,
    required this.donationsUrl,
    required this.billingProvider,
    required this.showsPaidPurchaseUI,
    required this.lemonSqueezy,
    required this.tdlib,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final ls = json['lemonSqueezy'] as Map<String, dynamic>? ?? {};
    final td = json['tdlib'] as Map<String, dynamic>? ?? {};
    return AppConfig(
      appDisplayName: json['appDisplayName'] as String? ?? 'Tandem AI Chat',
      bundleId: json['bundleId'] as String? ?? 'com.tandemai.tandemdesktop',
      websiteHostPath: json['websiteHostPath'] as String? ?? '',
      termsUrl: json['termsUrl'] as String? ?? '',
      privacyUrl: json['privacyUrl'] as String? ?? '',
      supportEmail: json['supportEmail'] as String? ?? '',
      donationsUrl: json['donationsUrl'] as String? ??
          'https://destream.net/live/SergeyKosilov/donate',
      billingProvider: json['billingProvider'] as String? ?? 'external',
      showsPaidPurchaseUI: json['showsPaidPurchaseUI'] as bool? ?? false,
      lemonSqueezy: LemonSqueezyConfig(
        storeId: ls['storeId'] as String? ?? '',
        variantId: ls['variantId'] as String? ?? '',
        checkoutUrl: ls['checkoutUrl'] as String? ?? '',
      ),
      tdlib: TdlibConfig(
        apiId: (td['apiId'] as num?)?.toInt() ?? 0,
        apiHash: td['apiHash'] as String? ?? '',
      ),
    );
  }

  final String appDisplayName;
  final String bundleId;
  final String websiteHostPath;
  final String termsUrl;
  final String privacyUrl;
  final String supportEmail;
  final String donationsUrl;
  final String billingProvider;
  final bool showsPaidPurchaseUI;
  final LemonSqueezyConfig lemonSqueezy;
  final TdlibConfig tdlib;

  bool get usesExternalBilling => billingProvider == 'external';

  /// When paid UI is off, do not require a Lemon Squeezy license for the pipeline.
  bool get requiresActiveLicense => usesExternalBilling && showsPaidPurchaseUI;
}

class LemonSqueezyConfig {
  const LemonSqueezyConfig({
    required this.storeId,
    required this.variantId,
    required this.checkoutUrl,
  });

  final String storeId;
  final String variantId;
  final String checkoutUrl;
}

class TdlibConfig {
  const TdlibConfig({required this.apiId, required this.apiHash});

  final int apiId;
  final String apiHash;

  bool get isConfigured => apiId != 0 && apiHash.isNotEmpty;
}
