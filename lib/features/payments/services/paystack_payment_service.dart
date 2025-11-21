import '../../../core/api/api_client.dart';
import '../models/paystack_models.dart';

class PaystackPaymentService {
  final ApiClient apiClient;

  PaystackPaymentService({required this.apiClient});

  Future<PaystackInitializeResponse> initializePayment({
    required String tableId,
    required String dinerId,
    required String dinerEmail,
    required double chargeAmountZar,
    String? paymentMethodId,
  }) async {
    return apiClient.post(
      '/payments/paystack/initialize',
      body: {
        'tableId': tableId,
        'dinerId': dinerId,
        'dinerEmail': dinerEmail,
        'chargeAmountZar': chargeAmountZar,
        'paymentMethodId': paymentMethodId,
      },
      parser: (data) =>
          PaystackInitializeResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<PaystackVerifyResponse> verifyPayment(String reference) async {
    return apiClient.get(
      '/payments/paystack/verify/$reference',
      parser: (data) =>
          PaystackVerifyResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<HostPayoutResponse> triggerHostPayout({
    required String tableId,
    required String hostDinerId,
  }) async {
    return apiClient.post(
      '/tables/$tableId/host-payout',
      body: {'hostDinerId': hostDinerId},
      parser: (data) =>
          HostPayoutResponse.fromJson(data as Map<String, dynamic>),
    );
  }
}
