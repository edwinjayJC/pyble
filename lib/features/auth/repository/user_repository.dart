import '../../../core/api/api_client.dart';
import '../models/user_profile.dart';

class UserRepository {
  final ApiClient apiClient;

  UserRepository({required this.apiClient});

  Future<UserProfile> getProfile(String userId) async {
    return await apiClient.get(
      '/profiles/me',
      parser: (data) => UserProfile.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<UserProfile> createProfile({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    return await apiClient.post(
      '/profiles',
      body: {
        'id': userId,
        'email': email,
        'displayName': displayName,
      },
      parser: (data) => UserProfile.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<UserProfile> updateProfile(
    String userId, {
    String? displayName,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;

    return await apiClient.put(
      '/profiles/$userId',
      body: body,
      parser: (data) => UserProfile.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<UserProfile> acceptTerms(String userId) async {
    return await apiClient.post(
      '/profiles/accept-terms',
      parser: (data) => UserProfile.fromJson(data as Map<String, dynamic>),
    );
  }
}
