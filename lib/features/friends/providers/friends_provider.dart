import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/friend.dart';
import '../models/friend_request.dart';
import '../repository/friends_repository.dart';

/// Provider for the list of friends
final friendsListProvider =
    AsyncNotifierProvider<FriendsListNotifier, List<Friend>>(
  FriendsListNotifier.new,
);

class FriendsListNotifier extends AsyncNotifier<List<Friend>> {
  @override
  Future<List<Friend>> build() async {
    return _fetchFriends();
  }

  Future<List<Friend>> _fetchFriends() async {
    final repository = ref.read(friendsRepositoryProvider);
    return repository.getFriendsList();
  }

  /// Refresh the friends list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchFriends);
  }

  /// Remove a friend from the list
  Future<void> removeFriend(String friendUserId) async {
    final repository = ref.read(friendsRepositoryProvider);
    await repository.removeFriend(friendUserId);

    // Update local state
    state = state.whenData((friends) {
      return friends.where((f) => f.userId != friendUserId).toList();
    });
  }
}

/// Provider for pending friend requests
final friendRequestsProvider =
    AsyncNotifierProvider<FriendRequestsNotifier, List<FriendRequest>>(
  FriendRequestsNotifier.new,
);

class FriendRequestsNotifier extends AsyncNotifier<List<FriendRequest>> {
  @override
  Future<List<FriendRequest>> build() async {
    return _fetchRequests();
  }

  Future<List<FriendRequest>> _fetchRequests() async {
    final repository = ref.read(friendsRepositoryProvider);
    return repository.getPendingRequests();
  }

  /// Refresh the requests list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchRequests);
  }

  /// Accept a friend request
  Future<void> acceptRequest(String requestId) async {
    final repository = ref.read(friendsRepositoryProvider);
    await repository.acceptRequest(requestId);

    // Remove from local state
    state = state.whenData((requests) {
      return requests.where((r) => r.id != requestId).toList();
    });

    // Refresh friends list
    ref.invalidate(friendsListProvider);
  }

  /// Reject a friend request
  Future<void> rejectRequest(String requestId) async {
    final repository = ref.read(friendsRepositoryProvider);
    await repository.rejectRequest(requestId);

    // Remove from local state
    state = state.whenData((requests) {
      return requests.where((r) => r.id != requestId).toList();
    });
  }
}

/// Provider for sending friend requests
final sendFriendRequestProvider = Provider<SendFriendRequestService>((ref) {
  return SendFriendRequestService(ref);
});

class SendFriendRequestService {
  final Ref _ref;

  SendFriendRequestService(this._ref);

  /// Send a friend request to a user by their ID
  Future<String> sendRequest(String targetUserId) async {
    final repository = _ref.read(friendsRepositoryProvider);
    final requestId = await repository.sendFriendRequest(targetUserId);
    return requestId;
  }
}
