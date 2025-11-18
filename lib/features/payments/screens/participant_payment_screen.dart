import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../table/providers/table_provider.dart';
import '../../table/models/participant.dart';
import '../../table/repository/table_repository.dart';
import '../providers/payment_provider.dart';

class ParticipantPaymentScreen extends ConsumerStatefulWidget {
  final String tableId;

  const ParticipantPaymentScreen({super.key, required this.tableId});

  @override
  ConsumerState<ParticipantPaymentScreen> createState() =>
      _ParticipantPaymentScreenState();
}

class _ParticipantPaymentScreenState
    extends ConsumerState<ParticipantPaymentScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentTableProvider.notifier).loadTable(widget.tableId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tableAsync = ref.watch(currentTableProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: tableAsync.when(
        data: (tableData) {
          if (tableData == null || currentUser == null) {
            return const Center(child: Text('No data available'));
          }

          final participant = tableData.participants.firstWhere(
            (p) => p.userId == currentUser.id,
            orElse: () => Participant(
              id: '',
              tableId: '',
              userId: '',
              displayName: '',
              paymentStatus: PaymentStatus.owing,
            ),
          );

          if (participant.id.isEmpty) {
            return const Center(child: Text('You are not part of this table'));
          }

          // Find host info
          final host = tableData.participants.firstWhere(
            (p) => p.userId == tableData.table.hostUserId,
            orElse: () => participant,
          );

          return _buildPaymentScreen(context, tableData, participant, host);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.warmSpice),
              const SizedBox(height: AppSpacing.md),
              Text('Error: $error'),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref
                    .read(currentTableProvider.notifier)
                    .loadTable(widget.tableId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentScreen(
    BuildContext context,
    TableData tableData,
    Participant participant,
    Participant host,
  ) {
    // Check payment status
    if (participant.paymentStatus == PaymentStatus.paid) {
      return _buildSettledScreen(context, participant);
    }

    if (participant.paymentStatus == PaymentStatus.pendingConfirmation) {
      return _buildPendingConfirmationScreen(context, participant, host);
    }

    // Owing state - show payment options
    return _buildOwingScreen(context, tableData, participant, host);
  }

  Widget _buildSettledScreen(BuildContext context, Participant participant) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
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
              "You're All Settled!",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.lushGreen,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Payment of ${AppConstants.currencySymbol}${participant.totalOwed.toStringAsFixed(2)} confirmed',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingConfirmationScreen(
    BuildContext context,
    Participant participant,
    Participant host,
  ) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.lightWarmSpice,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pending,
                size: 80,
                color: AppColors.warmSpice,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Awaiting Host Confirmation',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.warmSpice,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You marked your payment of ${AppConstants.currencySymbol}${participant.totalOwed.toStringAsFixed(2)} as paid outside the app.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Waiting for ${host.displayName} to confirm receipt.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.darkFig.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            const CircularProgressIndicator(
              color: AppColors.warmSpice,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwingScreen(
    BuildContext context,
    TableData tableData,
    Participant participant,
    Participant host,
  ) {
    final amount = participant.totalOwed;
    final fee = amount * AppConstants.appFeePercentage;
    final totalWithFee = amount + fee;

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),

          // Amount Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.lightCrust,
              borderRadius: AppRadius.allMd,
              border: Border.all(color: AppColors.paleGray),
            ),
            child: Column(
              children: [
                Text(
                  'You owe ${host.displayName}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppColors.deepBerry,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Payment Options
          Text(
            'How would you like to pay?',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.lg),

          // Pay in App Option
          _buildPaymentOption(
            context: context,
            title: 'Pay in App',
            subtitle: 'Instant settlement',
            icon: Icons.credit_card,
            color: AppColors.deepBerry,
            isPrimary: true,
            details: [
              _buildFeeRow('Amount', '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}'),
              _buildFeeRow('Service Fee (4%)', '${AppConstants.currencySymbol}${fee.toStringAsFixed(2)}'),
              const Divider(),
              _buildFeeRow('Total', '${AppConstants.currencySymbol}${totalWithFee.toStringAsFixed(2)}',
                  isBold: true),
            ],
            onTap: _isProcessing ? null : () => _initiateInAppPayment(amount),
          ),

          const SizedBox(height: AppSpacing.md),

          // Paid Outside Option
          _buildPaymentOption(
            context: context,
            title: 'Mark as Paid Outside',
            subtitle: 'Cash, bank transfer, etc.',
            icon: Icons.money_off,
            color: AppColors.darkFig,
            isPrimary: false,
            details: [
              Text(
                'Pay the host directly with cash or transfer, then they will confirm receipt in the app.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.darkFig.withOpacity(0.7),
                    ),
              ),
            ],
            onTap: _isProcessing
                ? null
                : () => _markPaidOutside(participant),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isPrimary,
    required List<Widget> details,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? color.withOpacity(0.05) : AppColors.snow,
        borderRadius: AppRadius.allMd,
        border: Border.all(
          color: isPrimary ? color : AppColors.paleGray,
          width: isPrimary ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.allMd,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 32),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                          ),
                          Text(
                            subtitle,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.darkFig.withOpacity(0.7),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    if (isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          'RECOMMENDED',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.snow,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ...details,
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: isPrimary
                      ? ElevatedButton(
                          onPressed: onTap,
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.snow,
                                  ),
                                )
                              : const Text('Pay Now'),
                        )
                      : OutlinedButton(
                          onPressed: onTap,
                          child: const Text('Mark as Paid Outside'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeeRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateInAppPayment(double amount) async {
    setState(() => _isProcessing = true);

    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final response = await paymentRepo.initiatePayment(
        tableId: widget.tableId,
        amount: amount,
      );

      if (mounted) {
        context.push(
          '/payment-webview/${widget.tableId}',
          extra: response,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initiating payment: $e'),
            backgroundColor: AppColors.warmSpice,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _markPaidOutside(Participant participant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid Outside'),
        content: Text(
          'By marking this as paid outside, you confirm that you have paid ${AppConstants.currencySymbol}${participant.totalOwed.toStringAsFixed(2)} to the host through another method (cash, bank transfer, etc.).\n\nThe host will need to confirm receipt before you are marked as paid.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      await paymentRepo.markPaidOutside(
        tableId: widget.tableId,
      );

      // Reload table data to update status
      await ref.read(currentTableProvider.notifier).loadTable(widget.tableId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as paid. Awaiting host confirmation.'),
            backgroundColor: AppColors.warmSpice,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.warmSpice,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}
