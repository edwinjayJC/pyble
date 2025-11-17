import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pyble/core/theme/app_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/payment_provider.dart';
import '../models/payment_record.dart';

class PaymentProcessingScreen extends ConsumerStatefulWidget {
  final String tableId;
  final String paymentId;

  const PaymentProcessingScreen({
    super.key,
    required this.tableId,
    required this.paymentId,
  });

  @override
  ConsumerState<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState
    extends ConsumerState<PaymentProcessingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentStatusProvider.notifier).startPolling(widget.paymentId);
    });
  }

  @override
  void dispose() {
    // Stop polling when leaving the screen
    ref.read(paymentStatusProvider.notifier).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentStatus = ref.watch(paymentStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing Payment'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: _buildContent(context, paymentStatus),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PaymentStatusState? statusState) {
    if (statusState == null) {
      return _buildLoadingState(context);
    }

    switch (statusState.status) {
      case TransactionStatus.pending:
        return _buildPendingState(context);
      case TransactionStatus.completed:
        return _buildSuccessState(context);
      case TransactionStatus.failed:
        return _buildFailedState(context, statusState.errorMessage);
    }
  }

  Widget _buildLoadingState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          color: AppColors.deepBerry,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Initializing...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildPendingState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            color: AppColors.deepBerry,
            strokeWidth: 6,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Processing Your Payment',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Please wait while we confirm your payment...',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.darkFig.withOpacity(0.7),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.lightCrust,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.darkFig,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'This may take a few moments',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 80,
            color: AppColors.lushGreen,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Payment Successful!',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.lushGreen,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "You're all settled up!",
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/table/${widget.tableId}/payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lushGreen,
            ),
            child: const Text('View Settlement Status'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => context.go('/home'),
          child: const Text('Back to Home'),
        ),
      ],
    );
  }

  Widget _buildFailedState(BuildContext context, String? errorMessage) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.lightWarmSpice,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline,
            size: 80,
            color: AppColors.warmSpice,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Payment Failed',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.warmSpice,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          errorMessage ?? 'Your payment could not be processed.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              ref.read(paymentStatusProvider.notifier).reset();
              context.pushReplacement('/table/${widget.tableId}/payment');
            },
            child: const Text('Try Again'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => context.go('/home'),
          child: const Text('Back to Home'),
        ),
      ],
    );
  }
}
