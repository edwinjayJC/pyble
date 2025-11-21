enum PaymentProvider {
  paystack,
  stripe,
  zapper,
  external;

  String get apiValue {
    switch (this) {
      case PaymentProvider.paystack:
        return 'paystack';
      case PaymentProvider.stripe:
        return 'stripe';
      case PaymentProvider.zapper:
        return 'zapper';
      case PaymentProvider.external:
        return 'external';
    }
  }

  static PaymentProvider fromString(String value) {
    switch (value.toLowerCase()) {
      case 'stripe':
        return PaymentProvider.stripe;
      case 'zapper':
        return PaymentProvider.zapper;
      case 'external':
        return PaymentProvider.external;
      case 'paystack':
      default:
        return PaymentProvider.paystack;
    }
  }
}

enum PaymentMethodType {
  card,
  bankAccount,
  wallet,
  cryptoWallet,
  externalFlag;

  String get apiValue {
    switch (this) {
      case PaymentMethodType.card:
        return 'card';
      case PaymentMethodType.bankAccount:
        return 'bank_account';
      case PaymentMethodType.wallet:
        return 'wallet';
      case PaymentMethodType.cryptoWallet:
        return 'crypto_wallet';
      case PaymentMethodType.externalFlag:
        return 'external_flag';
    }
  }

  static PaymentMethodType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'bank_account':
        return PaymentMethodType.bankAccount;
      case 'wallet':
        return PaymentMethodType.wallet;
      case 'crypto_wallet':
        return PaymentMethodType.cryptoWallet;
      case 'external_flag':
        return PaymentMethodType.externalFlag;
      case 'card':
      default:
        return PaymentMethodType.card;
    }
  }
}

class PaymentMethod {
  final String id;
  final PaymentProvider provider;
  final PaymentMethodType type;
  final String? last4;
  final String? brand;
  final int? expiryMonth;
  final int? expiryYear;
  final String? label;
  final bool isDefault;
  final bool isActive;

  const PaymentMethod({
    required this.id,
    required this.provider,
    required this.type,
    this.last4,
    this.brand,
    this.expiryMonth,
    this.expiryYear,
    this.label,
    this.isDefault = false,
    this.isActive = true,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id']?.toString() ?? '',
      provider: PaymentProvider.fromString(json['provider'] as String? ?? ''),
      type: PaymentMethodType.fromString(json['type'] as String? ?? ''),
      last4: json['last4'] as String?,
      brand: json['brand'] as String?,
      expiryMonth: (json['expiryMonth'] as num?)?.toInt(),
      expiryYear: (json['expiryYear'] as num?)?.toInt(),
      label: json['label'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider': provider.apiValue,
      'type': type.apiValue,
      'last4': last4,
      'brand': brand,
      'expiryMonth': expiryMonth,
      'expiryYear': expiryYear,
      'label': label,
      'isDefault': isDefault,
      'isActive': isActive,
    };
  }

  PaymentMethod copyWith({
    String? id,
    PaymentProvider? provider,
    PaymentMethodType? type,
    String? last4,
    String? brand,
    int? expiryMonth,
    int? expiryYear,
    String? label,
    bool? isDefault,
    bool? isActive,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      type: type ?? this.type,
      last4: last4 ?? this.last4,
      brand: brand ?? this.brand,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
    );
  }
}

class AddPaymentMethodInitResponse {
  final String initMethod;
  final String redirectUrl;
  final String pendingPaymentMethodId;

  const AddPaymentMethodInitResponse({
    required this.initMethod,
    required this.redirectUrl,
    required this.pendingPaymentMethodId,
  });

  factory AddPaymentMethodInitResponse.fromJson(Map<String, dynamic> json) {
    return AddPaymentMethodInitResponse(
      initMethod: json['initMethod'] as String? ?? 'redirect',
      redirectUrl: json['redirectUrl'] as String? ??
          json['redirect_url'] as String? ??
          '',
      pendingPaymentMethodId:
          json['pendingPaymentMethodId'] as String? ??
              json['paymentMethodId'] as String? ??
              '',
    );
  }
}
