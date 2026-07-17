import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Resolves the TDLib JSON shared library for the current platform.
abstract final class TdLibRuntime {
  static Future<String?> resolveLibraryPath() async {
    final candidates = <String>[];

    candidates.addAll(_bundleNativePaths());
    final repoNative = _repoNativePath();
    if (repoNative != null) {
      candidates.add(repoNative);
    }

    if (Platform.isMacOS) {
      candidates.addAll([
        '/opt/homebrew/lib/libtdjson.dylib',
        '/usr/local/lib/libtdjson.dylib',
      ]);
    } else if (Platform.isLinux) {
      candidates.addAll([
        '/usr/lib/libtdjson.so',
        '/usr/local/lib/libtdjson.so',
      ]);
    } else if (Platform.isWindows) {
      candidates.add(r'C:\tdlib\tdjson.dll');
    }

    for (final path in candidates) {
      if (await File(path).exists()) {
        debugPrint('TDLib: using $path');
        return path;
      }
    }
    debugPrint('TDLib: no native library found — using stub Telegram service');
    return null;
  }

  static List<String> _bundleNativePaths() {
  // Release bundles: library sits next to the executable or in lib/.
    final exeDir = p.dirname(Platform.resolvedExecutable);
    if (Platform.isMacOS) {
      return [
        p.join(exeDir, 'libtdjson.dylib'),
        p.join(exeDir, 'Frameworks', 'libtdjson.dylib'),
      ];
    }
    if (Platform.isLinux) {
      return [
        p.join(exeDir, 'libtdjson.so'),
        p.join(exeDir, 'lib', 'libtdjson.so'),
      ];
    }
    if (Platform.isWindows) {
      return [p.join(exeDir, 'tdjson.dll')];
    }
    return const [];
  }

  static String? _repoNativePath() {
    // desktop/app → desktop/native/tdlib
    final cwd = Directory.current.path;
    final base = p.normalize(p.join(cwd, '..', '..', 'native', 'tdlib'));
    if (Platform.isMacOS) {
      return p.join(base, 'macos', 'libtdjson.dylib');
    }
    if (Platform.isLinux) {
      return p.join(base, 'linux', 'libtdjson.so');
    }
    if (Platform.isWindows) {
      return p.join(base, 'windows', 'tdjson.dll');
    }
    return null;
  }
}
