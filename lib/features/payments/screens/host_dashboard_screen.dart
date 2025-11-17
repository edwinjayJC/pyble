import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../table/providers/table_provider.dart';
import '../../table/models/participant.dart';
import '../../table/repository/table_repository.dart';
import '../repository/payment_repository.dart';
import '../providers/payment_provider.dart';

class HostDashboardScreen extends ConsumerStatefulWidget {
  final String tableId;

  const HostDashboardScreen({super.key, required this.tableId});

  @override
  ConsumerState<HostDashboardScreen> createState() =>
      _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: tableAsync.when(
        data: (tableData) {
          if (tableData == null) {
            return const Center(child: Text('No table data'));
          }
          return _buildDashboard(context, tableData);
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

  Widget _buildDashboard(BuildContext context, TableData tableData) {
    final participants = tableData.participants;
    final totalOwed = participants.fold<double>(
      0,
      (sum, p) =>
          p.paymentStatus != PaymentStatus.paid ? sum + p.totalOwed : sum,
    );
    final totalCollected = participants.fold<double>(
      0,
      (sum, p) =>
          p.paymentStatus == PaymentStatus.paid ? sum + p.totalOwed : sum,
    );

    final paidCount =
        participants.where((p) => p.paymentStatus == PaymentStatus.paid).length;
    final pendingCount = participants
        .where((p) => p.paymentStatus == PaymentStatus.pendingConfirmation)
        .length;
    final owingCount =
        participants.where((p) => p.paymentStatus == PaymentStatus.owing).length;

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(currentTableProvider.notifier).loadTable(widget.tableId),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Card
            _buildSummaryCard(
              totalOwed: totalOwed,
              totalCollected: totalCollected,
              paidCount: paidCount,
              pendingCount: pendingCount,
              owingCount: owingCount,
              totalParticipants: participants.length,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Status Header
            Text(
              'Participants',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Participant List
            ...participants.map((participant) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _buildParticipantRow(context, participant),
                )),

            const SizedBox(height: AppSpacing.xl),

            // Actions
            if (owingCount == 0 && pendingCount == 0)
              _buildSettleTableButton(context, tableData),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required double totalOwed,
    required double totalCollected,
    required int paidCount,
    required int pendingCount,
    required int owingCount,
    required int totalParticipants,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lightCrust,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: AppColors.paleGray),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn(
                'Collected',
                '\$${totalCollected.toStringAsFixed(2)}',
                AppColors.lushGreen,
              ),
              _buildStatColumn(
                'Outstanding',
                '\$${totalOwed.toStringAsFixed(2)}',
                AppColors.warmSpice,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCountBadge('Paid', paidCount, AppColors.lushGreen),
              _buildCountBadge('Pending', pendingCount, AppColors.warmSpice),
              _buildCountBadge('Owing', owingCount, AppColors.paleGray),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.darkFig.withOpacity(0.7),
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildCountBadge(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            count.toString(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildParticipantRow(BuildContext context, Participant participant) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    bool showConfirmButton = false;

    switch (participant.paymentStatus) {
      case PaymentStatus.paid:
        statusColor = AppColors.lushGreen;
        statusText = 'PAID';
        statusIcon = Icons.check_circle;
        break;
      case PaymentStatus.pendingConfirmation:
        statusColor = AppColors.warmSpice;
        statusText = 'Awaiting Your Confirmation';
        statusIcon = Icons.pending;
        showConfirmButton = true;
        break;
      case PaymentStatus.owing:
        statusColor = AppColors.darkFig;
        statusText = 'OWES \$${participant.totalOwed.toStringAsFixed(2)}';
        statusIcon = Icons.attach_money;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: AppColors.paleGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withOpacity(0.2),
                child: Text(
                  participant.initials,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Name and Amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (participant.paymentStatus == PaymentStatus.paid)
                      Text(
                        '\$${participant.totalOwed.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.darkFig.withOpacity(0.7),
                            ),
                      ),
                  ],
                ),
              ),
              // Status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
          // Confirm Button
          if (showConfirmButton) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmPayment(participant),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lushGreen,
                ),
                child: const Text('Confirm Payment Received'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmPayment(Participant participant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Confirm you received \$${participant.totalOwed.toStringAsFixed(2)} from ${participant.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lushGreen,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      await paymentRepo.confirmPayment(
        tableId: widget.tableId,
        participantId: participant.id,
      );

      // Reload table data
      await ref.read(currentTableProvider.notifier).loadTable(widget.tableId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment from ${participant.displayName} confirmed'),
            backgroundColor: AppColors.lushGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming payment: $e'),
            backgroundColor: AppColors.warmSpice,
          ),
        );
      }
    }
  }

  Widget _buildSettleTableButton(BuildContext context, TableData tableData) {
    return ElevatedButton(
      onPressed: () => _settleTable(),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.lushGreen,
      ),
      child: const Text('Settle Table'),
    );
  }

  Future<void> _settleTable() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settle Table?'),
        content: const Text(
          'This will close the table and mark it as settled. '
          'All participants have been paid. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lushGreen,
            ),
            child: const Text('Settle'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ref.read(currentTableProvider.notifier).settleTable();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Table settled successfully!'),
            backgroundColor: AppColors.lushGreen,
          ),
        );
        // Navigate to home after settling
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error settling table: $e'),
            backgroundColor: AppColors.warmSpice,
          ),
        );
      }
    }
  }
}
