enum PaymentType {
  appPayment,
  manualPayment;

  static PaymentType fromString(String value) {
    switch (value) {
      case 'app_payment':
        return PaymentType.appPayment;
      case 'manual_payment':
        return PaymentType.manualPayment;
      default:
        return PaymentType.appPayment;
    }
  }

  String toJsonString() {
    switch (this) {
      case PaymentType.appPayment:
        return 'app_payment';
      case PaymentType.manualPayment:
        return 'manual_payment';
    }
  }
}

enum TransactionStatus {
  pending,
  completed,
  failed;

  static TransactionStatus fromString(String value) {
    return TransactionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TransactionStatus.pending,
    );
  }
}

class PaymentRecord {
  final String id;
  final String tableId;
  final String payerUserId;
  final String receiverUserId;
  final double amount;
  final double fee;
  final PaymentType type;
  final TransactionStatus transactionStatus;
  final String? paymentGatewayReference;

  const PaymentRecord({
    required this.id,
    required this.tableId,
    required this.payerUserId,
    required this.receiverUserId,
    required this.amount,
    required this.fee,
    required this.type,
    required this.transactionStatus,
    this.paymentGatewayReference,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String,
      tableId: json['tableId'] as String,
      payerUserId: json['payerUserId'] as String,
      receiverUserId: json['receiverUserId'] as String,
      amount: (json['amount'] as num).toDouble(),
      fee: (json['fee'] as num).toDouble(),
      type: PaymentType.fromString(json['type'] as String),
      transactionStatus:
          TransactionStatus.fromString(json['transactionStatus'] as String),
      paymentGatewayReference: json['paymentGatewayReference'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tableId': tableId,
      'payerUserId': payerUserId,
      'receiverUserId': receiverUserId,
      'amount': amount,
      'fee': fee,
      'type': type.toJsonString(),
      'transactionStatus': transactionStatus.name,
      'paymentGatewayReference': paymentGatewayReference,
    };
  }
}
