import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import 'lemon_squeezy_api.dart';

class LicenseRepository {
  LicenseRepository({
    required this.config,
    LemonSqueezyApi? api,
    FlutterSecureStorage? storage,
  })  : _api = api ?? LemonSqueezyApi(),
        _storage = storage ?? const FlutterSecureStorage();

  final AppConfig config;
  final LemonSqueezyApi _api;
  final FlutterSecureStorage _storage;

  static const _storageKey = 'com.tandemai.tandemdesktop.license';
  static const _instanceNameKey = 'tandem.lemonsqueezy.instanceName';
  static const _revalidateSeconds = 60 * 60 * 6;

  LicenseEntitlement? _cache;
  DateTime? _lastValidated;

  Future<LicenseEntitlement> resolveEntitlement({bool force = false}) async {
    final stored = await _loadStored();
    if (stored == null) return const LicenseEntitlement.inactive();

    if (!force &&
        _cache != null &&
        _lastValidated != null &&
        DateTime.now().difference(_lastValidated!).inSeconds <
            _revalidateSeconds) {
      return _cache!;
    }

    final entitlement = await _validate(stored);
    _cache = entitlement;
    _lastValidated = DateTime.now();
    return entitlement;
  }

  Future<void> activate(String rawKey) async {
    final key = rawKey.trim();
    if (key.isEmpty) {
      throw const LicenseActivationException('Enter a license key.');
    }

    final instanceName = await _instanceName();
    final result = await _api.activate(
      licenseKey: key,
      instanceName: instanceName,
    );

    if (!result.activated) {
      throw LicenseActivationException(
        result.error ?? 'Activation failed.',
      );
    }

    if (!_matchesVariant(result.variantId)) {
      throw const LicenseActivationException(
        'This license key is for a different product.',
      );
    }

    if (result.instanceId == null) {
      throw const LicenseActivationException('Invalid server response.');
    }

    await _saveStored(
      _StoredLicense(licenseKey: key, instanceId: result.instanceId!),
    );
    _cache = null;
    _lastValidated = null;
  }

  Future<void> deactivate() async {
    final stored = await _loadStored();
    if (stored != null) {
      await _api.deactivate(
        licenseKey: stored.licenseKey,
        instanceId: stored.instanceId,
      );
    }
    await _storage.delete(key: _storageKey);
    _cache = null;
    _lastValidated = null;
  }

  Future<bool> get isActivated async => (await _loadStored()) != null;

  Future<LicenseEntitlement> _validate(_StoredLicense stored) async {
    try {
      final result = await _api.validate(
        licenseKey: stored.licenseKey,
        instanceId: stored.instanceId,
      );
      if (!result.valid || result.status != 'active') {
        return const LicenseEntitlement.inactive();
      }
      if (result.expiresAt != null && result.expiresAt!.isBefore(DateTime.now())) {
        return const LicenseEntitlement.inactive();
      }
      return LicenseEntitlement(
        isActive: true,
        expirationDate: result.expiresAt,
      );
    } catch (_) {
      return _cache ?? const LicenseEntitlement.inactive();
    }
  }

  bool _matchesVariant(String? variantId) {
    final configured = config.lemonSqueezy.variantId;
    if (configured.isEmpty) return true;
    return variantId == configured;
  }

  Future<_StoredLicense?> _loadStored() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return _StoredLicense(
      licenseKey: json['licenseKey'] as String,
      instanceId: json['instanceId'] as String,
    );
  }

  Future<void> _saveStored(_StoredLicense license) async {
    await _storage.write(
      key: _storageKey,
      value: jsonEncode({
        'licenseKey': license.licenseKey,
        'instanceId': license.instanceId,
      }),
    );
  }

  Future<String> _instanceName() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_instanceNameKey);
    if (existing != null) return existing;
    final host = 'Desktop';
    final name = '$host-${const Uuid().v4().substring(0, 8)}';
    await prefs.setString(_instanceNameKey, name);
    return name;
  }
}

class _StoredLicense {
  const _StoredLicense({required this.licenseKey, required this.instanceId});

  final String licenseKey;
  final String instanceId;
}

class LicenseActivationException implements Exception {
  const LicenseActivationException(this.message);
  final String message;

  @override
  String toString() => message;
}
