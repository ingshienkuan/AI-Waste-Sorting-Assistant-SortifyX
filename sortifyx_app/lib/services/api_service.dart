import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Lightweight HTTP wrapper around the backend REST API.
///
/// - Reads the base URL from [AppConfig] (no hardcoded values in screens).
/// - Attaches the JWT bearer token automatically when present.
/// - Applies a uniform timeout to every request.
/// - Wraps low-level errors in [ApiException] for clean handling in the UI.
class ApiService {
  static String get baseUrl => AppConfig.baseUrl;
  static final Duration _timeout =
      Duration(seconds: AppConfig.requestTimeoutSeconds);

  static String? _cachedToken;

  // ---------------- Token storage ----------------

  /// Returns the saved access token, or null if not logged in.
  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(AppConfig.tokenStorageKey);
    return _cachedToken;
  }

  /// Persists [token] for use in subsequent authenticated requests.
  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.tokenStorageKey, token);
  }

  /// Clears the stored access token (used on logout).
  static Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.tokenStorageKey);
  }

  // ---------------- Internal helpers ----------------

  static Future<Map<String, String>> _headers({bool jsonBody = true}) async {
    final token = await getToken();
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Uri _uri(String endpoint, [Map<String, dynamic>? query]) {
    final base = Uri.parse('$baseUrl$endpoint');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: {
      ...base.queryParameters,
      ...query.map((k, v) => MapEntry(k, v.toString())),
    });
  }

  static ApiException _wrapError(Object e) {
    if (e is SocketException) {
      return ApiException(
        'Cannot reach server. Check that the backend is running '
        'and the API URL is correct.',
      );
    }
    if (e is HttpException) {
      return ApiException('HTTP error: ${e.message}');
    }
    if (e is FormatException) {
      return ApiException('Invalid server response.');
    }
    return ApiException('Network error: $e');
  }

  // ---------------- Public methods ----------------

  /// GET request. [query] is appended as URL parameters.
  static Future<http.Response> get(
    String endpoint, {
    Map<String, dynamic>? query,
  }) async {
    try {
      return await http
          .get(_uri(endpoint, query), headers: await _headers())
          .timeout(_timeout);
    } catch (e) {
      throw _wrapError(e);
    }
  }

  /// POST request with a JSON body.
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      return await http
          .post(
            _uri(endpoint),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      throw _wrapError(e);
    }
  }

  /// PUT request with a JSON body.
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      return await http
          .put(
            _uri(endpoint),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      throw _wrapError(e);
    }
  }

  /// DELETE request.
  static Future<http.Response> delete(String endpoint) async {
    try {
      return await http
          .delete(_uri(endpoint), headers: await _headers())
          .timeout(_timeout);
    } catch (e) {
      throw _wrapError(e);
    }
  }

  /// Multipart POST for file uploads. Returns a fully-buffered [http.Response]
  /// so callers can use the same `response.statusCode` / `response.body`
  /// pattern as the other methods.
  ///
  /// [fields] lets callers attach extra form fields alongside the file
  /// (e.g. `{'source': 'camera'}`).
  static Future<http.Response> postMultipart(
    String endpoint,
    String filePath,
    String fieldName, {
    Map<String, String>? fields,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _uri(endpoint));
      final token = await getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';
      if (fields != null) request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));

      final streamed = await request.send().timeout(_timeout);
      return await http.Response.fromStream(streamed);
    } catch (e) {
      throw _wrapError(e);
    }
  }
}

/// Exception thrown by [ApiService] for any network/transport failure.
/// HTTP error responses (4xx/5xx) are NOT thrown — they are returned as
/// regular [http.Response]s so callers can inspect the JSON error payload.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
