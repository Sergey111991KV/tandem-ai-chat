import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pipeline_settings.dart';

class PipelineSettingsStore {
  static const _key = 'tandem.desktop.pipelineSettings';

  Future<PipelineSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const PipelineSettings();
    try {
      return PipelineSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const PipelineSettings();
    }
  }

  Future<void> save(PipelineSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
