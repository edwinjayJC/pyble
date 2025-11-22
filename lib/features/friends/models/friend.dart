class Friend {
  final String userId;
  final bool isAuto;
  final DateTime addedAt;
  final String displayName;
  final String? avatarUrl;

  const Friend({
    required this.userId,
    required this.isAuto,
    required this.addedAt,
    required this.displayName,
    this.avatarUrl,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      userId: json['userId'] as String,
      isAuto: json['isAuto'] as bool? ?? false,
      addedAt: DateTime.parse(json['addedAt'] as String),
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'isAuto': isAuto,
      'addedAt': addedAt.toIso8601String(),
      'displayName': displayName,
      'avatarUrl': avatarUrl,
    };
  }

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }
}
