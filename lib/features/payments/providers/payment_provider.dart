import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../repository/payment_repository.dart';
import '../models/payment_record.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaymentRepository(apiClient: apiClient);
});

// Provider for initiating payments
final initiatePaymentProvider = FutureProvider.family
    .autoDispose<InitiatePaymentResponse, PaymentInitiateParams>(
        (ref, params) async {
  final repository = ref.watch(paymentRepositoryProvider);
  return await repository.initiatePayment(
    tableId: params.tableId,
    amount: params.amount,
  );
});

class PaymentInitiateParams {
  final String tableId;
  final double amount;

  const PaymentInitiateParams({
    required this.tableId,
    required this.amount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentInitiateParams &&
          runtimeType == other.runtimeType &&
          tableId == other.tableId &&
          amount == other.amount;

  @override
  int get hashCode => tableId.hashCode ^ amount.hashCode;
}

// State for payment status polling
class PaymentStatusState {
  final String paymentId;
  final TransactionStatus status;
  final bool isPolling;
  final String? errorMessage;

  const PaymentStatusState({
    required this.paymentId,
    required this.status,
    this.isPolling = false,
    this.errorMessage,
  });

  PaymentStatusState copyWith({
    String? paymentId,
    TransactionStatus? status,
    bool? isPolling,
    String? errorMessage,
  }) {
    return PaymentStatusState(
      paymentId: paymentId ?? this.paymentId,
      status: status ?? this.status,
      isPolling: isPolling ?? this.isPolling,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Notifier for payment status polling
class PaymentStatusNotifier extends AutoDisposeNotifier<PaymentStatusState?> {
  Timer? _pollingTimer;

  @override
  PaymentStatusState? build() {
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    return null;
  }

  void startPolling(String paymentId) {
    state = PaymentStatusState(
      paymentId: paymentId,
      status: TransactionStatus.pending,
      isPolling: true,
    );

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.paymentStatusPollingInterval),
      (_) => _checkStatus(),
    );

    // Immediately check status
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final currentState = state;
    if (currentState == null || !currentState.isPolling) return;

    final repository = ref.read(paymentRepositoryProvider);

    try {
      final statusResponse =
          await repository.getPaymentStatus(currentState.paymentId);

      state = currentState.copyWith(
        status: statusResponse.status,
        errorMessage: statusResponse.message,
      );

      // Stop polling if payment is completed or failed
      if (statusResponse.status == TransactionStatus.completed ||
          statusResponse.status == TransactionStatus.failed) {
        stopPolling();
      }
    } catch (e) {
      // Keep polling on error, but update error message
      state = currentState.copyWith(
        errorMessage: e.toString(),
      );
    }
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;

    final currentState = state;
    if (currentState != null) {
      state = currentState.copyWith(isPolling: false);
    }
  }

  void reset() {
    stopPolling();
    state = null;
  }
}

final paymentStatusProvider =
    NotifierProvider.autoDispose<PaymentStatusNotifier, PaymentStatusState?>(
        () {
  return PaymentStatusNotifier();
});

// Helper provider to calculate fee
final paymentFeeProvider = Provider.family<double, double>((ref, amount) {
  return amount * AppConstants.appFeePercentage;
});

// Helper provider to calculate total with fee
final paymentTotalProvider = Provider.family<double, double>((ref, amount) {
  final fee = ref.watch(paymentFeeProvider(amount));
  return amount + fee;
});
