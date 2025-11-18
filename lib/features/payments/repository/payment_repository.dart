import '../../../core/api/api_client.dart';
import '../models/payment_record.dart';

class PaymentRepository {
  final ApiClient apiClient;

  PaymentRepository({required this.apiClient});

  /// Initiate a payment in the app (PIA flow)
  Future<InitiatePaymentResponse> initiatePayment({
    required String tableId,
    required double amount,
  }) async {
    return await apiClient.post(
      '/payments/initiate',
      body: {
        'tableId': tableId,
        'amount': amount,
      },
      parser: (data) =>
          InitiatePaymentResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Check payment status (used for polling)
  Future<PaymentStatusResponse> getPaymentStatus(String paymentId) async {
    return await apiClient.get(
      '/payments/status/$paymentId',
      parser: (data) =>
          PaymentStatusResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Mark payment as paid outside the app (POA flow)
  Future<void> markPaidOutside({
    required String tableId,
  }) async {
    await apiClient.post(
      '/tables/$tableId/mark-paid-outside',
      parser: (_) {},
    );
  }

  /// Host confirms they received payment (for POA)
  Future<void> confirmPayment({
    required String tableId,
    required String participantUserId,
  }) async {
    await apiClient.post(
      '/tables/$tableId/confirm-payment',
      body: {
        'participantUserId': participantUserId,
      },
      parser: (_) {},
    );
  }

  /// Get payment history for a table
  Future<List<PaymentRecord>> getTablePayments(String tableId) async {
    return await apiClient.get(
      '/tables/$tableId/payments',
      parser: (data) {
        final list = data as List<dynamic>;
        return list
            .map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }
}
