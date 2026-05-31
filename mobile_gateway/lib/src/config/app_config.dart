class AppConfig {
  // Development/test defaults only. Override shared builds with --dart-define.
  static const defaultBackendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://example-dev-tunnel-url',
  );
  static const defaultDeviceName = String.fromEnvironment(
    'DEVICE_NAME',
    defaultValue: 'ESP32 Device',
  );
  static const defaultBleDeviceName = String.fromEnvironment(
    'BLE_DEVICE_NAME',
    defaultValue: 'ESPP',
  );
  static const defaultLegacyApiKey = String.fromEnvironment('LEGACY_API_KEY');
  static const debugTestingUsername = String.fromEnvironment(
    'DEBUG_TEST_USERNAME',
  );
  static const debugTestingPassword = String.fromEnvironment(
    'DEBUG_TEST_PASSWORD',
  );
}

class BleUuidConfig {
  static const serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const sensorNotifyCharacteristicUuid =
      'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String? configWriteCharacteristicUuid = null;
}
