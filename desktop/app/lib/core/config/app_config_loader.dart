import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'app_config.dart';

class AppConfigLoader {
  static Future<AppConfig> load() async {
    final local = await _readLocalFile();
    if (local != null) {
      return AppConfig.fromJson(local);
    }
    final bundled =
        await rootBundle.loadString('assets/config/app_config.json');
    return AppConfig.fromJson(jsonDecode(bundled) as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>?> _readLocalFile() async {
    final cwd = Directory.current.path;
    final candidates = [
      '$cwd/../config/app_config.local.json',
      '$cwd/../config/app_config.example.json',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    }
    return null;
  }
}
