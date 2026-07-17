import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tandem_desktop/app/tandem_app.dart';
import 'package:tandem_desktop/core/config/app_config.dart';
import 'package:tandem_desktop/core/services/stub_telegram_service.dart';
import 'package:tandem_desktop/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});

    const config = AppConfig(
      appDisplayName: 'Tandem AI Chat',
      bundleId: 'com.tandemai.tandemdesktop',
      websiteHostPath: 'example.github.io/tandem-ai-chat',
      termsUrl: 'https://example.com/terms',
      privacyUrl: 'https://example.com/privacy',
      supportEmail: 'support@example.com',
      donationsUrl: 'https://example.com/donate',
      billingProvider: 'external',
      showsPaidPurchaseUI: false,
      lemonSqueezy: LemonSqueezyConfig(
        storeId: '1',
        variantId: '2',
        checkoutUrl: 'https://example.com/checkout',
      ),
      tdlib: TdlibConfig(apiId: 0, apiHash: ''),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          telegramServiceProvider.overrideWithValue(StubTelegramService()),
        ],
        child: const TandemApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI replies in your Telegram'), findsOneWidget);
  });
}
