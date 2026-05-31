// Example development configuration values.
//
// Prefer passing real values with Flutter --dart-define or entering them in
// the app Settings screen. Never commit real API keys, passwords, database
// credentials, or .env files.

class AppConfigExample {
  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'your-backend-url',
  );
  static const legacyApiKey = String.fromEnvironment(
    'LEGACY_API_KEY',
    defaultValue: 'your-api-key',
  );
  static const debugTestingUsername = String.fromEnvironment(
    'DEBUG_TEST_USERNAME',
    defaultValue: 'your-username',
  );
  static const debugTestingPassword = String.fromEnvironment(
    'DEBUG_TEST_PASSWORD',
    defaultValue: 'your-password',
  );
}
