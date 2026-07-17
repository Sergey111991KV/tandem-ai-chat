import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Close-to-background helper (keeps the process alive when the window closes).
///
/// Full system-tray icons can be added later via `tray_manager` once packaging is ready.
class DesktopTrayService with WindowListener {
  DesktopTrayService();

  bool _closeToTray = true;
  bool _initialized = false;

  Future<void> initialize({bool closeToTray = true}) async {
    if (kIsWeb ||
        !(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      return;
    }
    _closeToTray = closeToTray;
    if (_initialized) return;
    _initialized = true;

    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
  }

  Future<void> setCloseToTray(bool enabled) async {
    _closeToTray = enabled;
    await windowManager.setPreventClose(enabled);
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideWindow() async {
    await windowManager.hide();
  }

  @override
  void onWindowClose() async {
    if (_closeToTray) {
      await hideWindow();
    } else {
      await windowManager.destroy();
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    windowManager.removeListener(this);
    _initialized = false;
  }
}
