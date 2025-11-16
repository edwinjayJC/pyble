import '../../../core/api/api_client.dart';
import '../models/user_profile.dart';

class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository(this._apiClient);

  Future<UserProfile> getMyProfile() async {
    return _apiClient.get<UserProfile>(
      '/profiles/me',
      fromJson: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<UserProfile> createProfile({
    required String id,
    required String email,
    required String displayName,
  }) async {
    return _apiClient.post<UserProfile>(
      '/profiles',
      body: {
        'id': id,
        'email': email,
        'displayName': displayName,
      },
      fromJson: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<UserProfile> acceptTerms() async {
    return _apiClient.put<UserProfile>(
      '/profiles/me/accept-terms',
      fromJson: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> deleteAccount() async {
    await _apiClient.delete('/profiles/me');
  }
}
