import 'dart:convert';

import 'package:http/http.dart' as http;

class LemonSqueezyApi {
  LemonSqueezyApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://api.lemonsqueezy.com/v1/licenses';

  Future<ActivateResult> activate({
    required String licenseKey,
    required String instanceName,
  }) async {
    final response = await _client.post(
      Uri.parse('$_base/activate'),
      headers: _headers,
      body: _formBody({
        'license_key': licenseKey,
        'instance_name': instanceName,
      }),
    );
    final json = _decode(response.body);
    final meta = json['meta'] as Map<String, dynamic>?;
    final instance = json['instance'] as Map<String, dynamic>?;
    return ActivateResult(
      activated: json['activated'] as bool? ?? false,
      error: json['error'] as String?,
      instanceId: instance?['id'] as String?,
      variantId: meta?['variant_id']?.toString(),
    );
  }

  Future<void> deactivate({
    required String licenseKey,
    required String instanceId,
  }) async {
    await _client.post(
      Uri.parse('$_base/deactivate'),
      headers: _headers,
      body: _formBody({
        'license_key': licenseKey,
        'instance_id': instanceId,
      }),
    );
  }

  Future<ValidateResult> validate({
    required String licenseKey,
    required String instanceId,
  }) async {
    final response = await _client.post(
      Uri.parse('$_base/validate'),
      headers: _headers,
      body: _formBody({
        'license_key': licenseKey,
        'instance_id': instanceId,
      }),
    );
    final json = _decode(response.body);
    final licenseInfo = json['license_key'] as Map<String, dynamic>?;
    final expiresRaw = licenseInfo?['expires_at'] as String?;
    return ValidateResult(
      valid: json['valid'] as bool? ?? false,
      status: licenseInfo?['status'] as String?,
      expiresAt: expiresRaw != null ? DateTime.tryParse(expiresRaw) : null,
    );
  }

  Map<String, String> get _headers => const {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      };

  String _formBody(Map<String, String> fields) {
    return fields.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
  }

  Map<String, dynamic> _decode(String body) {
    return jsonDecode(body) as Map<String, dynamic>;
  }
}

class ActivateResult {
  const ActivateResult({
    required this.activated,
    this.error,
    this.instanceId,
    this.variantId,
  });

  final bool activated;
  final String? error;
  final String? instanceId;
  final String? variantId;
}

class ValidateResult {
  const ValidateResult({
    required this.valid,
    this.status,
    this.expiresAt,
  });

  final bool valid;
  final String? status;
  final DateTime? expiresAt;
}
