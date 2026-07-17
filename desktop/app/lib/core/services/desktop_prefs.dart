import 'package:shared_preferences/shared_preferences.dart';

class DesktopPrefs {
  static const _closeToTrayKey = 'tandem.desktop.closeToTray';

  Future<bool> getCloseToTray() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_closeToTrayKey) ?? true;
  }

  Future<void> setCloseToTray(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_closeToTrayKey, value);
  }
}
