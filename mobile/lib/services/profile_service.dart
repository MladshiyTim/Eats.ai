import '../models/profile.dart';
import 'api_client.dart';

/// Manages user profile CRUD via the /profile/ endpoint.
class ProfileService {
  final ApiClient _client = ApiClient.instance;

  /// Fetches the current user's profile.
  Future<Profile> getProfile() async {
    final data = await _client.get('/profile/') as Map<String, dynamic>;
    return Profile.fromJson(data);
  }

  /// Creates or updates the profile via PATCH.
  Future<Profile> updateProfile(Map<String, dynamic> fields) async {
    final data = await _client.patch('/profile/', fields) as Map<String, dynamic>;
    return Profile.fromJson(data);
  }

  /// Creates the profile for the first time via POST.
  Future<Profile> createProfile(Map<String, dynamic> fields) async {
    final data = await _client.post('/profile/', fields) as Map<String, dynamic>;
    return Profile.fromJson(data);
  }
}
