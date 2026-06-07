import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../services/api_client.dart';
import '../services/profile_service.dart';
import 'auth_provider.dart';

/// Profile state exposed via Provider.
/// Uses [ChangeNotifierProxyProvider] so it reacts to auth changes.
class ProfileProvider extends ChangeNotifier {
  final ProfileService _profileService = ProfileService();

  Profile? _profile;
  bool _isLoading = false;
  String? _error;

  Profile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfile => _profile != null;

  // Called by ProxyProvider when AuthProvider changes.
  void updateAuth(AuthProvider auth) {
    if (!auth.isAuthenticated) {
      // Clear profile on logout
      _profile = null;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Loads the profile from the backend.
  Future<void> loadProfile() async {
    _setLoading(true);
    _error = null;
    try {
      _profile = await _profileService.getProfile();
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // Profile doesn't exist yet — that's normal for new users
        _profile = null;
      } else {
        _error = e.message;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Creates or updates the profile with the given fields.
  Future<void> saveProfile(Map<String, dynamic> fields) async {
    _setLoading(true);
    _error = null;
    try {
      if (_profile?.id != null) {
        _profile = await _profileService.updateProfile(fields);
      } else {
        // Try PATCH first; if 404 then POST to create
        try {
          _profile = await _profileService.updateProfile(fields);
        } on ApiException catch (e) {
          if (e.statusCode == 404) {
            _profile = await _profileService.createProfile(fields);
          } else {
            rethrow;
          }
        }
      }
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Clears cached profile (e.g., on logout).
  void clear() {
    _profile = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
