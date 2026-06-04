/// Central application configuration.
///
/// The API base URL is supplied at build/run time via `--dart-define`.
/// Default is the Android emulator loopback to host machine (10.0.2.2),
/// so running on a stock emulator with the backend on the host machine
/// works out of the box.
///
/// Override for other environments:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.42:5000/api
///   flutter build apk --dart-define=API_BASE_URL=https://api.example.com/api
class AppConfig {
  /// Base URL of the backend REST API (without trailing slash).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );

  /// HTTP request timeout in seconds.
  static const int requestTimeoutSeconds = 30;

  /// SharedPreferences key for the access token.
  static const String tokenStorageKey = 'access_token';
}
