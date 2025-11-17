class UserProfile {
  final String id;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final bool hasAcceptedTerms;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    required this.hasAcceptedTerms,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      hasAcceptedTerms: json['hasAcceptedTerms'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'hasAcceptedTerms': hasAcceptedTerms,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatarUrl,
    bool? hasAcceptedTerms,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      hasAcceptedTerms: hasAcceptedTerms ?? this.hasAcceptedTerms,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }
}
