class BlockedUser {
  final String userId;
  final String displayName;
  final DateTime blockedAt;

  const BlockedUser({
    required this.userId,
    required this.displayName,
    required this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Unknown User',
      blockedAt: json['blockedAt'] != null
          ? DateTime.parse(json['blockedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'blockedAt': blockedAt.toIso8601String(),
    };
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
