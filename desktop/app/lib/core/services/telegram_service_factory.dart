import '../config/app_config.dart';
import '../tdlib/tdlib_runtime.dart';
import 'stub_telegram_service.dart';
import 'tdlib_telegram_service.dart';
import 'telegram_service.dart';

abstract final class TelegramServiceFactory {
  static Future<TelegramService> create(AppConfig config) async {
    final libPath = await TdLibRuntime.resolveLibraryPath();
    if (libPath == null) {
      return StubTelegramService();
    }
    try {
      final service = TdLibTelegramService(config: config, libraryPath: libPath);
      await service.initialize();
      return service;
    } catch (_) {
      return StubTelegramService();
    }
  }
}
