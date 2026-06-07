import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

/// Authentication state exposed to the widget tree via Provider.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  // ── Internal helpers ──────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Public actions ────────────────────────────────────────────────────────────

  /// Checks whether a valid token exists (called from SplashScreen).
  Future<bool> checkLoginStatus() async {
    try {
      final loggedIn = await _authService.isLoggedIn();
      if (loggedIn) {
        // Verify token is valid by fetching the current user
        _currentUser = await _authService.getCurrentUser();
        notifyListeners();
        return true;
      }
    } on AuthExpiredException {
      _currentUser = null;
    } on ApiException {
      // Token might be stale — treat as not logged in
      _currentUser = null;
    } catch (_) {
      _currentUser = null;
    }
    return false;
  }

  /// Logs in and updates state.
  Future<void> login(String username, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      _currentUser = await _authService.login(username, password);
      notifyListeners();
    } on ApiException catch (e) {
      _setError(e.message);
      rethrow;
    } on AuthExpiredException {
      _setError('Sessiya muddati tugagan. Iltimos, qayta kiring.');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Registers a new account and updates state.
  Future<void> register(String username, String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      _currentUser = await _authService.register(username, email, password);
      notifyListeners();
    } on ApiException catch (e) {
      _setError(e.message);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Logs out and clears user state.
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authService.logout();
    } finally {
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the locally cached user (e.g., after profile saves).
  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }
}
