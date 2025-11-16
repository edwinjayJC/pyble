class ItemClaim {
  final String id;
  final String billItemId;
  final String userId;

  const ItemClaim({
    required this.id,
    required this.billItemId,
    required this.userId,
  });

  factory ItemClaim.fromJson(Map<String, dynamic> json) {
    return ItemClaim(
      id: json['id'] as String,
      billItemId: json['billItemId'] as String,
      userId: json['userId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'billItemId': billItemId,
      'userId': userId,
    };
  }

  ItemClaim copyWith({
    String? id,
    String? billItemId,
    String? userId,
  }) {
    return ItemClaim(
      id: id ?? this.id,
      billItemId: billItemId ?? this.billItemId,
      userId: userId ?? this.userId,
    );
  }
}
