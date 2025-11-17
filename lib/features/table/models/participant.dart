enum PaymentStatus {
  owing,
  pendingConfirmation,
  paid;

  factory PaymentStatus.fromString(String value) {
    switch (value) {
      case 'owing':
        return PaymentStatus.owing;
      case 'pending_confirmation':
      case 'awaiting_confirmation':
        return PaymentStatus.pendingConfirmation;
      case 'paid':
      case 'paid_in_app':
      case 'paid_outside':
        return PaymentStatus.paid;
      default:
        return PaymentStatus.owing;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.owing:
        return 'Owing';
      case PaymentStatus.pendingConfirmation:
        return 'Awaiting Confirmation';
      case PaymentStatus.paid:
        return 'Paid';
    }
  }
}

class Participant {
  final String id;
  final String tableId;
  final String userId;
  final String displayName;
  final PaymentStatus paymentStatus;
  final double totalOwed;

  const Participant({
    required this.id,
    required this.tableId,
    required this.userId,
    required this.displayName,
    required this.paymentStatus,
    this.totalOwed = 0.0,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] as String? ?? json['participantId'] as String,
      tableId: json['tableId'] as String? ?? '',
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      paymentStatus: PaymentStatus.fromString(
        json['status'] as String? ?? json['paymentStatus'] as String? ?? 'owing',
      ),
      totalOwed: (json['totalOwed'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tableId': tableId,
      'userId': userId,
      'displayName': displayName,
      'status': paymentStatus.name,
      'totalOwed': totalOwed,
    };
  }

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  Participant copyWith({
    String? id,
    String? tableId,
    String? userId,
    String? displayName,
    PaymentStatus? paymentStatus,
    double? totalOwed,
  }) {
    return Participant(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      totalOwed: totalOwed ?? this.totalOwed,
    );
  }
}
