enum FriendRequestStatus {
  pending,
  accepted,
  rejected,
}

class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromDisplayName;
  final String? fromAvatarUrl;
  final FriendRequestStatus status;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromDisplayName,
    this.fromAvatarUrl,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      fromDisplayName: json['fromDisplayName'] as String,
      fromAvatarUrl: json['fromAvatarUrl'] as String?,
      status: _parseStatus(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static FriendRequestStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return FriendRequestStatus.accepted;
      case 'rejected':
        return FriendRequestStatus.rejected;
      default:
        return FriendRequestStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromDisplayName': fromDisplayName,
      'fromAvatarUrl': fromAvatarUrl,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get initials {
    final parts = fromDisplayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fromDisplayName.isNotEmpty ? fromDisplayName[0].toUpperCase() : '?';
  }
}
