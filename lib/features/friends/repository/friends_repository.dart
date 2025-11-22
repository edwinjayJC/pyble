import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/api_provider.dart';
import '../models/friend.dart';
import '../models/friend_request.dart';

class FriendsRepository {
  final ApiClient _apiClient;

  FriendsRepository(this._apiClient);

  /// Send a friend request to another user
  Future<String> sendFriendRequest(String targetUserId) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/profiles/friends/request',
      body: {'targetUserId': targetUserId},
    );
    return response['requestId'] as String;
  }

  /// Get all pending friend requests for the current user
  Future<List<FriendRequest>> getPendingRequests() async {
    final response = await _apiClient.get<List<dynamic>>(
      '/profiles/friends/requests',
    );
    return response
        .map((json) => FriendRequest.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Accept or reject a friend request
  Future<void> respondToRequest(String requestId, String action) async {
    await _apiClient.put<Map<String, dynamic>>(
      '/profiles/friends/request/$requestId',
      body: {'action': action},
    );
  }

  /// Accept a friend request
  Future<void> acceptRequest(String requestId) async {
    await respondToRequest(requestId, 'accept');
  }

  /// Reject a friend request
  Future<void> rejectRequest(String requestId) async {
    await respondToRequest(requestId, 'reject');
  }

  /// Remove a friend
  Future<void> removeFriend(String friendUserId) async {
    await _apiClient.delete<Map<String, dynamic>>(
      '/profiles/friends/$friendUserId',
    );
  }

  /// Get the current user's friends list
  /// Note: This endpoint needs to be added to the backend API
  /// For now, we'll assume it returns the friends array from the user profile
  Future<List<Friend>> getFriendsList() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/profiles/me',
    );

    final friendsJson = response['friends'] as List<dynamic>? ?? [];
    return friendsJson
        .map((json) => Friend.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

/// Provider for the FriendsRepository
final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FriendsRepository(apiClient);
});
