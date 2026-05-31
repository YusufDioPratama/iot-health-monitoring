import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

class SecureStore {
  SecureStore() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String> backendBaseUrl() async {
    return await _storage.read(key: _Keys.baseUrl) ??
        AppConfig.defaultBackendBaseUrl;
  }

  Future<String> deviceName() async {
    return await _storage.read(key: _Keys.deviceName) ??
        AppConfig.defaultDeviceName;
  }

  Future<String?> accessToken() => _storage.read(key: _Keys.accessToken);
  Future<String?> refreshToken() => _storage.read(key: _Keys.refreshToken);
  Future<String?> username() => _storage.read(key: _Keys.username);
  Future<String?> deviceSecret() => _storage.read(key: _Keys.deviceSecret);
  Future<String> legacyApiKey() async {
    final stored = await _storage.read(key: _Keys.legacyApiKey);
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    return AppConfig.defaultLegacyApiKey.trim();
  }

  Future<bool> mockMode() async {
    return (await _storage.read(key: _Keys.mockMode)) == 'true';
  }

  Future<void> saveBaseUrl(String value) {
    return _storage.write(key: _Keys.baseUrl, value: value.trim());
  }

  Future<void> saveDeviceName(String value) {
    return _storage.write(key: _Keys.deviceName, value: value.trim());
  }

  Future<void> saveDeviceSecret(String value) async {
    if (value.trim().isEmpty) {
      await _storage.delete(key: _Keys.deviceSecret);
      return;
    }
    await _storage.write(key: _Keys.deviceSecret, value: value.trim());
  }

  Future<void> saveLegacyApiKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _Keys.legacyApiKey);
      return;
    }
    await _storage.write(key: _Keys.legacyApiKey, value: trimmed);
  }

  Future<void> saveMockMode(bool value) {
    return _storage.write(key: _Keys.mockMode, value: value ? 'true' : 'false');
  }

  Future<void> saveSession({
    required String access,
    required String refresh,
    required String username,
    required String deviceName,
    required String baseUrl,
  }) async {
    await Future.wait([
      _storage.write(key: _Keys.accessToken, value: access),
      _storage.write(key: _Keys.refreshToken, value: refresh),
      _storage.write(key: _Keys.username, value: username),
      _storage.write(key: _Keys.deviceName, value: deviceName),
      _storage.write(key: _Keys.activeDevice, value: deviceName),
      _storage.write(key: _Keys.baseUrl, value: baseUrl),
    ]);
  }

  Future<void> saveAccessToken(String value) {
    return _storage.write(key: _Keys.accessToken, value: value);
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _Keys.accessToken),
      _storage.delete(key: _Keys.refreshToken),
      _storage.delete(key: _Keys.username),
      _storage.delete(key: _Keys.activeDevice),
    ]);
  }

  Future<int> lastSeq(String deviceName) async {
    final value = await _storage.read(key: '${_Keys.lastSeq}:$deviceName');
    return int.tryParse(value ?? '') ?? -1;
  }

  Future<void> saveLastSeq(String deviceName, int seq) {
    return _storage.write(key: '${_Keys.lastSeq}:$deviceName', value: '$seq');
  }
}

class _Keys {
  static const baseUrl = 'backend_base_url';
  static const deviceName = 'device_name';
  static const activeDevice = 'active_device';
  static const accessToken = 'access_token';
  static const refreshToken = 'refresh_token';
  static const username = 'username';
  static const deviceSecret = 'device_secret';
  static const legacyApiKey = 'legacy_api_key';
  static const lastSeq = 'last_seq';
  static const mockMode = 'mock_mode';
}
