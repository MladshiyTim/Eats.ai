import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// Thrown when the server returns a non-2xx response.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown when both access token and refresh token are expired / missing.
class AuthExpiredException implements Exception {
  @override
  String toString() => 'AuthExpiredException: session expired — please log in again';
}

/// Singleton HTTP client that:
///   1. Automatically injects `Authorization: Bearer <access_token>`.
///   2. On 401, attempts a token refresh via /auth/refresh/.
///   3. On refresh failure, throws [AuthExpiredException].
class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();
  factory ApiClient() => instance;

  final _storage = const FlutterSecureStorage();
  final _httpClient = http.Client();

  // ── Token helpers ────────────────────────────────────────────────────────────

  Future<String?> _getAccessToken() => _storage.read(key: kAccessTokenKey);
  Future<String?> _getRefreshToken() => _storage.read(key: kRefreshTokenKey);

  Future<void> storeTokens({required String access, required String refresh}) async {
    await _storage.write(key: kAccessTokenKey, value: access);
    await _storage.write(key: kRefreshTokenKey, value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: kAccessTokenKey);
    await _storage.delete(key: kRefreshTokenKey);
  }

  // ── Request builders ─────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) {
    // Ensure path starts with /
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$apiBaseUrl$cleanPath');
  }

  // ── Token refresh ─────────────────────────────────────────────────────────────

  /// Attempts to refresh the access token.
  /// Returns new access token string or throws [AuthExpiredException].
  Future<String> _refreshAccessToken() async {
    final refresh = await _getRefreshToken();
    if (refresh == null) throw AuthExpiredException();

    final response = await _httpClient.post(
      _uri('/auth/refresh/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newAccess = data['access'] as String;
      await _storage.write(key: kAccessTokenKey, value: newAccess);
      // Some backends also return a new refresh token
      if (data['refresh'] != null) {
        await _storage.write(key: kRefreshTokenKey, value: data['refresh'] as String);
      }
      return newAccess;
    }

    // Refresh failed — session fully expired
    await clearTokens();
    throw AuthExpiredException();
  }

  // ── Core request method ───────────────────────────────────────────────────────

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) async {
    final headers = await _authHeaders();
    final uri = _uri(path);

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _httpClient.get(uri, headers: headers);
          break;
        case 'POST':
          response = await _httpClient.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await _httpClient.put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PATCH':
          response = await _httpClient.patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await _httpClient.delete(uri, headers: headers);
          break;
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
    } on SocketException {
      throw const ApiException(statusCode: 0, message: 'Tarmoq xatosi: serverga ulanib bo\'lmadi');
    }

    // Handle 401 — try to refresh once
    if (response.statusCode == 401 && !isRetry) {
      await _refreshAccessToken(); // throws AuthExpiredException if fails
      return _request(method, path, body: body, isRetry: true);
    }

    return _parseResponse(response);
  }

  dynamic _parseResponse(http.Response response) {
    // 204 No Content
    if (response.statusCode == 204) return null;

    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    dynamic decoded;
    try {
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (_) {
      decoded = null;
    }

    if (isSuccess) return decoded;

    // Extract error message from backend response
    String message = 'Noma\'lum xato (${response.statusCode})';
    if (decoded is Map) {
      if (decoded['error'] != null) {
        message = decoded['error'].toString();
      } else if (decoded['detail'] != null) {
        message = decoded['detail'].toString();
      } else if (decoded['non_field_errors'] != null) {
        final errors = decoded['non_field_errors'];
        message = (errors is List) ? errors.join(', ') : errors.toString();
      } else {
        // Collect field-level errors
        final fieldErrors = decoded.entries
            .where((e) => e.value != null)
            .map((e) {
              final v = e.value;
              return '${e.key}: ${v is List ? v.join(', ') : v}';
            })
            .join('; ');
        if (fieldErrors.isNotEmpty) message = fieldErrors;
      }
    }

    throw ApiException(statusCode: response.statusCode, message: message);
  }

  // ── Public HTTP methods ───────────────────────────────────────────────────────

  Future<dynamic> get(String path) => _request('GET', path);

  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body: body);

  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _request('PUT', path, body: body);

  Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _request('DELETE', path);

  /// Uploads a file via multipart/form-data (e.g. a food photo).
  /// Refreshes the access token once on 401, mirroring [_request].
  Future<dynamic> postMultipartFile(
    String path, {
    required String filePath,
    String fileField = 'image',
    Map<String, String>? fields,
    bool isRetry = false,
  }) async {
    final token = await _getAccessToken();
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (fields != null) request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(fileField, filePath));

    http.Response response;
    try {
      final streamed = await _httpClient.send(request);
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw const ApiException(
          statusCode: 0, message: 'Tarmoq xatosi: serverga ulanib bo\'lmadi');
    }

    if (response.statusCode == 401 && !isRetry) {
      await _refreshAccessToken();
      return postMultipartFile(
        path,
        filePath: filePath,
        fileField: fileField,
        fields: fields,
        isRetry: true,
      );
    }
    return _parseResponse(response);
  }

  /// POST without auth headers — used for login/register endpoints.
  Future<dynamic> postPublic(String path, Map<String, dynamic> body) async {
    final uri = _uri(path);
    final headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
    } on SocketException {
      throw const ApiException(statusCode: 0, message: 'Tarmoq xatosi: serverga ulanib bo\'lmadi');
    }
    return _parseResponse(response);
  }
}
