enum SplitRequestStatus {
  pending,
  approved,
  rejected;

  factory SplitRequestStatus.fromString(String value) {
    switch (value) {
      case 'approved':
        return SplitRequestStatus.approved;
      case 'rejected':
        return SplitRequestStatus.rejected;
      case 'pending':
      default:
        return SplitRequestStatus.pending;
    }
  }
}

class SplitRequest {
  final String id;
  final String itemId;
  final String itemName;
  final double itemPrice;
  final String requestedByUserId;
  final String requestedByName;
  final String targetUserId;
  final SplitRequestStatus status;
  final DateTime createdAt;

  const SplitRequest({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
    required this.requestedByUserId,
    required this.requestedByName,
    required this.targetUserId,
    required this.status,
    required this.createdAt,
  });

  factory SplitRequest.fromJson(Map<String, dynamic> json) {
    return SplitRequest(
      id: json['id'] as String? ?? '',
      itemId: json['itemId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? 'Unknown Item',
      itemPrice: (json['itemPrice'] as num?)?.toDouble() ?? 0.0,
      requestedByUserId: json['requestedByUserId'] as String? ?? '',
      requestedByName: json['requestedByName'] as String? ?? 'Host',
      targetUserId: json['targetUserId'] as String? ?? '',
      status: SplitRequestStatus.fromString(
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
      'itemId': itemId,
      'itemName': itemName,
      'itemPrice': itemPrice,
      'requestedByUserId': requestedByUserId,
      'requestedByName': requestedByName,
      'targetUserId': targetUserId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  SplitRequest copyWith({
    String? id,
    String? itemId,
    String? itemName,
    double? itemPrice,
    String? requestedByUserId,
    String? requestedByName,
    String? targetUserId,
    SplitRequestStatus? status,
    DateTime? createdAt,
  }) {
    return SplitRequest(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      itemPrice: itemPrice ?? this.itemPrice,
      requestedByUserId: requestedByUserId ?? this.requestedByUserId,
      requestedByName: requestedByName ?? this.requestedByName,
      targetUserId: targetUserId ?? this.targetUserId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
