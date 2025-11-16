enum PaymentStatus {
  owing,
  pendingConfirmation,
  paid;

  static PaymentStatus fromString(String value) {
    switch (value) {
      case 'pending_confirmation':
        return PaymentStatus.pendingConfirmation;
      default:
        return PaymentStatus.values.firstWhere(
          (e) => e.name == value,
          orElse: () => PaymentStatus.owing,
        );
    }
  }

  String toJsonString() {
    switch (this) {
      case PaymentStatus.pendingConfirmation:
        return 'pending_confirmation';
      default:
        return name;
    }
  }
}

class Participant {
  final String id;
  final String tableId;
  final String userId;
  final String displayName;
  final String initials;
  final PaymentStatus paymentStatus;

  const Participant({
    required this.id,
    required this.tableId,
    required this.userId,
    required this.displayName,
    required this.initials,
    required this.paymentStatus,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] as String,
      tableId: json['tableId'] as String,
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      initials: json['initials'] as String,
      paymentStatus: PaymentStatus.fromString(json['paymentStatus'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tableId': tableId,
      'userId': userId,
      'displayName': displayName,
      'initials': initials,
      'paymentStatus': paymentStatus.toJsonString(),
    };
  }

  Participant copyWith({
    String? id,
    String? tableId,
    String? userId,
    String? displayName,
    String? initials,
    PaymentStatus? paymentStatus,
  }) {
    return Participant(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      initials: initials ?? this.initials,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }
}
