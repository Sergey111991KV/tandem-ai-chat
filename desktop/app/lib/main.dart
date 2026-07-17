import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/tandem_app.dart';
import 'core/config/app_config.dart';
import 'core/config/app_config_loader.dart';
import 'core/services/desktop_prefs.dart';
import 'core/services/desktop_tray_service.dart';
import 'core/services/telegram_service.dart';
import 'core/services/telegram_service_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DesktopTrayService? tray;
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1100, 760),
      minimumSize: Size(900, 620),
      center: true,
      title: 'Tandem AI Chat',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    final closeToTray = await DesktopPrefs().getCloseToTray();
    tray = DesktopTrayService();
    await tray.initialize(closeToTray: closeToTray);
  }

  final config = await AppConfigLoader.load();
  final telegramService = await TelegramServiceFactory.create(config);

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        telegramServiceProvider.overrideWithValue(telegramService),
        if (tray != null) desktopTrayProvider.overrideWithValue(tray),
      ],
      child: const TandemApp(),
    ),
  );
}

final desktopTrayProvider = Provider<DesktopTrayService?>((ref) => null);

/// Loaded once at startup; override in tests.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('AppConfig must be overridden at startup');
});

final telegramServiceProvider = Provider<TelegramService>((ref) {
  throw UnimplementedError('TelegramService must be overridden at startup');
});
