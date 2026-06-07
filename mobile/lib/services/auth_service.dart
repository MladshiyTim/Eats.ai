import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';
import '../models/user.dart';
import 'api_client.dart';

/// Handles all authentication operations: register, login, logout, token checking.
class AuthService {
  final ApiClient _client = ApiClient.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Registers a new user.
  /// On success, stores JWT tokens and returns the [User].
  Future<User> register(String username, String email, String password) async {
    final data = await _client.postPublic('/auth/register/', {
      'username': username,
      'email': email,
      'password': password,
      'password2': password,
    }) as Map<String, dynamic>;

    await _storeTokensFromResponse(data);
    return _extractUser(data);
  }

  /// Logs in with username + password.
  /// On success, stores JWT tokens and returns the [User].
  Future<User> login(String username, String password) async {
    final data = await _client.postPublic('/auth/login/', {
      'username': username,
      'password': password,
    }) as Map<String, dynamic>;

    await _storeTokensFromResponse(data);
    return _extractUser(data);
  }

  /// Clears stored tokens — effectively logs out the user.
  Future<void> logout() async {
    await _client.clearTokens();
  }

  /// Returns true if an access token is present in secure storage.
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: kAccessTokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Fetches the currently authenticated user from /auth/me/.
  Future<User> getCurrentUser() async {
    final data = await _client.get('/auth/me/') as Map<String, dynamic>;
    return User.fromJson(data);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Future<void> _storeTokensFromResponse(Map<String, dynamic> data) async {
    // Backend may wrap tokens under a 'tokens' key or return them at root level.
    final tokens = data['tokens'] as Map<String, dynamic>?;
    final access = (tokens?['access'] ?? data['access']) as String?;
    final refresh = (tokens?['refresh'] ?? data['refresh']) as String?;

    if (access == null || refresh == null) {
      throw ApiException(
        statusCode: 400,
        message: 'Server tokenlarni qaytarmadi',
      );
    }

    await _client.storeTokens(access: access, refresh: refresh);
  }

  User _extractUser(Map<String, dynamic> data) {
    // Backend may return user under a 'user' key or directly in the root object.
    final userData = (data['user'] as Map<String, dynamic>?) ?? data;
    return User.fromJson(userData);
  }
}
