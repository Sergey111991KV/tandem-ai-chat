import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../tdlib/tdlib_session.dart';

class ChatPreferencesStore {
  static const _key = 'tandem.desktop.chatPreferences';

  Future<Map<int, ChatPreferences>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (id, value) => MapEntry(
        int.parse(id),
        ChatPreferences.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  Future<void> save(int chatId, ChatPreferences pref) async {
    final all = await loadAll();
    all[chatId] = pref;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(
        all.map((k, v) => MapEntry('$k', v.toJson())),
      ),
    );
  }
}
