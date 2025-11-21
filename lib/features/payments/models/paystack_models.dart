enum PaystackPaymentStatus {
  pending,
  success,
  failed;

  factory PaystackPaymentStatus.fromString(String value) {
    switch (value.toLowerCase()) {
      case 'success':
        return PaystackPaymentStatus.success;
      case 'failed':
      case 'abandoned':
        return PaystackPaymentStatus.failed;
      default:
        return PaystackPaymentStatus.pending;
    }
  }
}

enum HostPayoutStatus {
  pending,
  success,
  failed;

  factory HostPayoutStatus.fromString(String value) {
    switch (value.toLowerCase()) {
      case 'success':
        return HostPayoutStatus.success;
      case 'failed':
        return HostPayoutStatus.failed;
      default:
        return HostPayoutStatus.pending;
    }
  }
}

class PaystackInitializeResponse {
  final String authorizationUrl;
  final String accessCode;
  final String reference;
  final String paymentId;
  final String callbackUrl;

  const PaystackInitializeResponse({
    required this.authorizationUrl,
    required this.accessCode,
    required this.reference,
    required this.paymentId,
    this.callbackUrl = '',
  });

  factory PaystackInitializeResponse.fromJson(Map<String, dynamic> json) {
    return PaystackInitializeResponse(
      authorizationUrl:
          json['authorization_url'] as String? ??
          json['authorizationUrl'] as String? ??
          '',
      accessCode:
          json['access_code'] as String? ?? json['accessCode'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      paymentId:
          json['paymentId'] as String? ?? json['payment_id'] as String? ?? '',
      callbackUrl:
          json['callback_url'] as String? ??
          json['callbackUrl'] as String? ??
          '',
    );
  }
}

class PaystackPaymentInfo {
  final String id;
  final String reference;
  final String tableId;
  final String dinerId;
  final double amountZar;
  final PaystackPaymentStatus status;

  const PaystackPaymentInfo({
    required this.id,
    required this.reference,
    required this.tableId,
    required this.dinerId,
    required this.amountZar,
    required this.status,
  });

  factory PaystackPaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaystackPaymentInfo(
      id: json['id']?.toString() ?? '',
      reference: json['reference'] as String? ?? '',
      tableId: json['tableId'] as String? ?? '',
      dinerId: json['dinerId'] as String? ?? '',
      amountZar: (json['amountZar'] as num?)?.toDouble() ?? 0,
      status: PaystackPaymentStatus.fromString(
        json['status'] as String? ?? 'pending',
      ),
    );
  }
}

class PaystackGatewaySnapshot {
  final String status;
  final String? gatewayResponse;

  const PaystackGatewaySnapshot({required this.status, this.gatewayResponse});

  factory PaystackGatewaySnapshot.fromJson(Map<String, dynamic> json) {
    return PaystackGatewaySnapshot(
      status: json['status'] as String? ?? '',
      gatewayResponse: json['gatewayResponse'] as String?,
    );
  }
}

class PaystackVerifyResponse {
  final PaystackPaymentInfo payment;
  final PaystackGatewaySnapshot paystack;

  const PaystackVerifyResponse({required this.payment, required this.paystack});

  factory PaystackVerifyResponse.fromJson(Map<String, dynamic> json) {
    return PaystackVerifyResponse(
      payment: PaystackPaymentInfo.fromJson(
        json['payment'] as Map<String, dynamic>? ?? {},
      ),
      paystack: PaystackGatewaySnapshot.fromJson(
        json['paystack'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class HostPayoutSummary {
  final String id;
  final HostPayoutStatus status;
  final double payoutAmountZar;

  const HostPayoutSummary({
    required this.id,
    required this.status,
    required this.payoutAmountZar,
  });

  factory HostPayoutSummary.fromJson(Map<String, dynamic> json) {
    return HostPayoutSummary(
      id: json['id']?.toString() ?? '',
      status: HostPayoutStatus.fromString(json['status'] as String? ?? ''),
      payoutAmountZar: (json['payoutAmountZar'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HostPayoutResponse {
  final String tableId;
  final String tableStatus;
  final HostPayoutSummary hostPayout;

  const HostPayoutResponse({
    required this.tableId,
    required this.tableStatus,
    required this.hostPayout,
  });

  factory HostPayoutResponse.fromJson(Map<String, dynamic> json) {
    return HostPayoutResponse(
      tableId: json['tableId'] as String? ?? '',
      tableStatus: json['tableStatus'] as String? ?? '',
      hostPayout: HostPayoutSummary.fromJson(
        json['hostPayout'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
