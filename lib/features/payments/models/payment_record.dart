enum PaymentType {
  appPayment,
  manualPayment;

  factory PaymentType.fromString(String value) {
    switch (value) {
      case 'app_payment':
        return PaymentType.appPayment;
      case 'manual_payment':
        return PaymentType.manualPayment;
      default:
        return PaymentType.appPayment;
    }
  }

  String toApiString() {
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

  factory TransactionStatus.fromString(String value) {
    switch (value) {
      case 'pending':
        return TransactionStatus.pending;
      case 'completed':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.failed;
      default:
        return TransactionStatus.pending;
    }
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
  final DateTime createdAt;

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
    required this.createdAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String,
      tableId: json['tableId'] as String,
      payerUserId: json['payerUserId'] as String,
      receiverUserId: json['receiverUserId'] as String,
      amount: (json['amount'] as num).toDouble(),
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      type: PaymentType.fromString(json['type'] as String),
      transactionStatus: TransactionStatus.fromString(
        json['transactionStatus'] as String? ?? json['status'] as String,
      ),
      paymentGatewayReference: json['paymentGatewayReference'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
      'type': type.toApiString(),
      'transactionStatus': transactionStatus.name,
      'paymentGatewayReference': paymentGatewayReference,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  double get totalWithFee => amount + fee;
}

class InitiatePaymentResponse {
  final String paymentId;
  final String paymentUrl;
  final String callbackUrl;
  final double amount;
  final double fee;

  const InitiatePaymentResponse({
    required this.paymentId,
    required this.paymentUrl,
    required this.callbackUrl,
    required this.amount,
    required this.fee,
  });

  factory InitiatePaymentResponse.fromJson(Map<String, dynamic> json) {
    return InitiatePaymentResponse(
      paymentId: json['paymentId'] as String,
      paymentUrl: json['paymentUrl'] as String,
      callbackUrl: json['callbackUrl'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      fee: (json['fee'] as num).toDouble(),
    );
  }
}

class PaymentStatusResponse {
  final String paymentId;
  final TransactionStatus status;
  final String? message;

  const PaymentStatusResponse({
    required this.paymentId,
    required this.status,
    this.message,
  });

  factory PaymentStatusResponse.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResponse(
      paymentId: json['paymentId'] as String,
      status: TransactionStatus.fromString(json['status'] as String),
      message: json['message'] as String?,
    );
  }
}
