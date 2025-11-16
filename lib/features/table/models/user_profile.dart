class UserProfile {
  final String id;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final bool hasAcceptedTerms;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    required this.hasAcceptedTerms,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      hasAcceptedTerms: json['hasAcceptedTerms'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'hasAcceptedTerms': hasAcceptedTerms,
    };
  }

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatarUrl,
    bool? hasAcceptedTerms,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      hasAcceptedTerms: hasAcceptedTerms ?? this.hasAcceptedTerms,
    );
  }
}
