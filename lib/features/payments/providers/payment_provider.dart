import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../repository/payment_repository.dart';
import '../models/payment_record.dart';
import '../models/paystack_models.dart';
import '../services/paystack_payment_service.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaymentRepository(apiClient: apiClient);
});

final paystackPaymentServiceProvider = Provider<PaystackPaymentService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaystackPaymentService(apiClient: apiClient);
});

// Provider for initiating payments
final initiatePaymentProvider = FutureProvider.family
    .autoDispose<PaystackInitializeResponse, PaymentInitiateParams>((
      ref,
      params,
    ) async {
      final service = ref.watch(paystackPaymentServiceProvider);
      return await service.initializePayment(
        tableId: params.tableId,
        dinerId: params.dinerId,
        dinerEmail: params.dinerEmail,
        chargeAmountZar: params.chargeAmountZar,
      );
    });

class PaymentInitiateParams {
  final String tableId;
  final String dinerId;
  final String dinerEmail;
  final double chargeAmountZar;

  const PaymentInitiateParams({
    required this.tableId,
    required this.dinerId,
    required this.dinerEmail,
    required this.chargeAmountZar,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentInitiateParams &&
          runtimeType == other.runtimeType &&
          tableId == other.tableId &&
          dinerId == other.dinerId &&
          dinerEmail == other.dinerEmail &&
          chargeAmountZar == other.chargeAmountZar;

  @override
  int get hashCode =>
      tableId.hashCode ^
      dinerId.hashCode ^
      dinerEmail.hashCode ^
      chargeAmountZar.hashCode;
}

// State for payment status polling
class PaymentStatusState {
  final String reference;
  final TransactionStatus status;
  final bool isPolling;
  final String? errorMessage;

  const PaymentStatusState({
    required this.reference,
    required this.status,
    this.isPolling = false,
    this.errorMessage,
  });

  PaymentStatusState copyWith({
    String? reference,
    TransactionStatus? status,
    bool? isPolling,
    String? errorMessage,
  }) {
    return PaymentStatusState(
      reference: reference ?? this.reference,
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

  void startPolling(String reference) {
    state = PaymentStatusState(
      reference: reference,
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

    final paystackService = ref.read(paystackPaymentServiceProvider);

    try {
      final verifyResponse = await paystackService.verifyPayment(
        currentState.reference,
      );

      final paymentStatus = verifyResponse.payment.status;
      final transactionStatus = paymentStatus == PaystackPaymentStatus.success
          ? TransactionStatus.completed
          : paymentStatus == PaystackPaymentStatus.failed
          ? TransactionStatus.failed
          : TransactionStatus.pending;

      state = currentState.copyWith(
        status: transactionStatus,
        errorMessage: verifyResponse.paystack.gatewayResponse,
      );

      // Stop polling if payment is completed or failed
      if (transactionStatus == TransactionStatus.completed ||
          transactionStatus == TransactionStatus.failed) {
        stopPolling();
      }
    } catch (e) {
      // Keep polling on error, but update error message
      state = currentState.copyWith(errorMessage: e.toString());
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

  void markFailure(String message, {String reference = ''}) {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    state = PaymentStatusState(
      reference: reference,
      status: TransactionStatus.failed,
      isPolling: false,
      errorMessage: message,
    );
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
      },
    );

// Helper provider to calculate fee
final paymentFeeProvider = Provider.family<double, double>((ref, amount) {
  return amount * AppConstants.appFeePercentage;
});

// Helper provider to calculate total with fee
final paymentTotalProvider = Provider.family<double, double>((ref, amount) {
  final fee = ref.watch(paymentFeeProvider(amount));
  return amount + fee;
});
