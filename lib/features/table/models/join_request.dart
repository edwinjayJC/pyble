enum JoinRequestStatus {
  pending,
  accepted,
  rejected;

  factory JoinRequestStatus.fromString(String value) {
    switch (value) {
      case 'accepted':
        return JoinRequestStatus.accepted;
      case 'rejected':
        return JoinRequestStatus.rejected;
      case 'pending':
      default:
        return JoinRequestStatus.pending;
    }
  }
}

class JoinRequest {
  final String id;
  final String userId;
  final String displayName;
  final JoinRequestStatus status;
  final DateTime createdAt;

  const JoinRequest({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.status,
    required this.createdAt,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Unknown User',
      status: JoinRequestStatus.fromString(
        json['status'] as String? ?? 'pending',
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'displayName': displayName,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  JoinRequest copyWith({
    String? id,
    String? userId,
    String? displayName,
    JoinRequestStatus? status,
    DateTime? createdAt,
  }) {
    return JoinRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get initials {
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (displayName.isNotEmpty) {
      return displayName[0].toUpperCase();
    }
    return '?';
  }
}
