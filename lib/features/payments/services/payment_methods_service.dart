import '../../../core/api/api_client.dart';
import '../models/payment_method.dart';

class PaymentMethodsService {
  final ApiClient apiClient;

  PaymentMethodsService({required this.apiClient});

  Future<List<PaymentMethod>> list() async {
    return apiClient.get(
      '/payment-methods',
      parser: (data) {
        final list = data as List<dynamic>? ?? [];
        return list
            .map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<AddPaymentMethodInitResponse> addCard({
    required bool makeDefault,
    String? label,
  }) async {
    return apiClient.post(
      '/payment-methods',
      body: {
        'provider': PaymentProvider.paystack.apiValue,
        'type': PaymentMethodType.card.apiValue,
        'makeDefault': makeDefault,
        'label': label,
      },
      parser: (data) =>
          AddPaymentMethodInitResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<PaymentMethod> setDefault(String id) async {
    return apiClient.patch(
      '/payment-methods/$id/default',
      parser: (data) =>
          PaymentMethod.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<PaymentMethod> updateLabel(String id, String label) async {
    return apiClient.patch(
      '/payment-methods/$id',
      body: {'label': label},
      parser: (data) =>
          PaymentMethod.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> delete(String id) async {
    await apiClient.delete('/payment-methods/$id', parser: (_) {});
  }
}
