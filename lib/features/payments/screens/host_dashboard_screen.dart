import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pyble/core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/providers/supabase_provider.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'cancel') {
                _cancelTable();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: colorScheme.error, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Cancel Table'),
                  ],
                ),
              ),
            ],
          ),
        ],
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
              Icon(Icons.error_outline,
                  size: 48, color: colorScheme.error),
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
    final currentUser = ref.watch(currentUserProvider);
    final hostParticipant = participants.firstWhere(
      (p) => p.userId == tableData.table.hostUserId,
      orElse: () => participants.first,
    );
    final isHostOwing = hostParticipant.userId == currentUser?.id &&
        hostParticipant.paymentStatus == PaymentStatus.owing;

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
            // Host's own payment card (if host owes)
            if (isHostOwing) ...[
              _buildHostPaymentCard(context, hostParticipant),
              const SizedBox(height: AppSpacing.lg),
            ],

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

  Widget _buildHostPaymentCard(BuildContext context, Participant hostParticipant) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.5),
        borderRadius: AppRadius.allMd,
        border: Border.all(color: colorScheme.primary.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_circle, color: colorScheme.primary, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Share',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                    Text(
                      'You paid the restaurant, but you also owe your share',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your amount:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                '${AppConstants.currencySymbol}${hostParticipant.totalOwed.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _markHostShareAsPaid(hostParticipant),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: isDark ? colorScheme.onPrimary : Colors.white,
              ),
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark My Share as Paid'),
            ),
          ),
        ],
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Define semantic colors
    final successColor = isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);
    final warningColor = colorScheme.error;
    final neutralColor = colorScheme.onSurface.withOpacity(0.3);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn(
                'Collected',
                '${AppConstants.currencySymbol}${totalCollected.toStringAsFixed(2)}',
                successColor,
              ),
              _buildStatColumn(
                'Outstanding',
                '${AppConstants.currencySymbol}${totalOwed.toStringAsFixed(2)}',
                warningColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCountBadge('Paid', paidCount, successColor),
              _buildCountBadge('Pending', pendingCount, warningColor),
              _buildCountBadge('Owing', owingCount, neutralColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    IconData statusIcon;
    bool showConfirmButton = false;

    // Define semantic colors
    final successColor = isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);
    final warningColor = colorScheme.error;
    final neutralColor = colorScheme.onSurface;

    switch (participant.paymentStatus) {
      case PaymentStatus.paid:
        statusColor = successColor;
        statusText = 'PAID';
        statusIcon = Icons.check_circle;
        break;
      case PaymentStatus.pendingConfirmation:
        statusColor = warningColor;
        statusText = 'Awaiting Your Confirmation';
        statusIcon = Icons.pending;
        showConfirmButton = true;
        break;
      case PaymentStatus.owing:
        statusColor = neutralColor;
        statusText = 'OWES ${AppConstants.currencySymbol}${participant.totalOwed.toStringAsFixed(2)}';
        statusIcon = Icons.attach_money;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withOpacity(isDark ? 0.2 : 0.15),
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
                        '${AppConstants.currencySymbol}${participant.totalOwed.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
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
                  backgroundColor: successColor,
                  foregroundColor: isDark ? colorScheme.onPrimary : Colors.white,
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final successColor = isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Confirm you received ${AppConstants.currencySymbol}${participant.totalOwed.toStringAsFixed(2)} from ${participant.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: successColor,
              foregroundColor: isDark ? colorScheme.onPrimary : Colors.white,
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
        participantUserId: participant.id,
      );

      // Reload table data
      await ref.read(currentTableProvider.notifier).loadTable(widget.tableId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment from ${participant.displayName} confirmed'),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming payment: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildSettleTableButton(BuildContext context, TableData tableData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);

    return ElevatedButton(
      onPressed: () => _settleTable(),
      style: ElevatedButton.styleFrom(
        backgroundColor: successColor,
        foregroundColor: isDark ? colorScheme.onPrimary : Colors.white,
      ),
      child: const Text('Settle Table'),
    );
  }

  Future<void> _settleTable() async {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final successColor = isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);

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
              backgroundColor: successColor,
              foregroundColor: isDark ? colorScheme.onPrimary : Colors.white,
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
          SnackBar(
            content: const Text('Table settled successfully!'),
            backgroundColor: successColor,
          ),
        );
        // Navigate to tables list after settling
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error settling table: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _markHostShareAsPaid(Participant hostParticipant) async {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final successColor = isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Your Share as Paid?'),
        content: Text(
          'This will mark your share of ${AppConstants.currencySymbol}${hostParticipant.totalOwed.toStringAsFixed(2)} as paid. '
          'Since you already paid the restaurant, this settles your portion of the bill.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: successColor,
              foregroundColor: isDark ? colorScheme.onPrimary : Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);

      // Mark as paid outside, then immediately confirm it (host confirms their own payment)
      await paymentRepo.markPaidOutside(tableId: widget.tableId);
      await paymentRepo.confirmPayment(
        tableId: widget.tableId,
        participantUserId: hostParticipant.userId,
      );

      // Reload table data
      await ref.read(currentTableProvider.notifier).loadTable(widget.tableId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Your share has been marked as paid'),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking share as paid: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _cancelTable() async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Table?'),
        content: const Text(
          'Are you sure you want to cancel this table? '
          'All participants will be notified and this action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Yes, Cancel Table'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final tableRepo = ref.read(tableRepositoryProvider);
      await tableRepo.cancelTable(widget.tableId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Table cancelled'),
            backgroundColor: colorScheme.error,
          ),
        );
        // Navigate to tables list after cancelling
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling table: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }
}
