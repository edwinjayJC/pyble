class ClaimedBy {
  final String userId;
  final double share;

  const ClaimedBy({required this.userId, required this.share});

  factory ClaimedBy.fromJson(Map<String, dynamic> json) {
    return ClaimedBy(
      userId: json['userId'] as String,
      share: (json['share'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'userId': userId, 'share': share};
  }
}

class BillItem {
  final String id;
  final String tableId;
  final String description;
  final double price;
  final List<ClaimedBy> claimedBy;

  const BillItem({
    required this.id,
    required this.tableId,
    required this.description,
    required this.price,
    this.claimedBy = const [],
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: json['itemId'] as String? ?? json['id'] as String,
      tableId: json['tableId'] as String? ?? '',
      description: json['name'] as String? ?? json['description'] as String,
      price: (json['price'] as num).toDouble(),
      claimedBy:
          (json['claimedBy'] as List<dynamic>?)
              ?.map((e) => ClaimedBy.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': id,
      'tableId': tableId,
      'name': description,
      'price': price,
      'claimedBy': claimedBy.map((e) => e.toJson()).toList(),
    };
  }

  BillItem copyWith({
    String? id,
    String? tableId,
    String? description,
    double? price,
    List<ClaimedBy>? claimedBy,
  }) {
    return BillItem(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      description: description ?? this.description,
      price: price ?? this.price,
      claimedBy: claimedBy ?? this.claimedBy,
    );
  }

  int get claimantsCount => claimedBy.length;

  bool get isClaimed => claimedBy.isNotEmpty;

  bool isClaimedByUser(String userId) {
    return claimedBy.any((c) => c.userId == userId);
  }

  double getShareForUser(String userId) {
    final claim = claimedBy.where((c) => c.userId == userId).firstOrNull;
    return claim?.share ?? 0.0;
  }

  double get splitAmount {
    if (claimantsCount == 0) return 0.0;
    return price / claimantsCount;
  }
}
