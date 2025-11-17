import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../table/models/participant.dart';

class ParticipantStatusRow extends StatelessWidget {
  final Participant participant;
  final bool isHost;
  final VoidCallback? onConfirmPayment;

  const ParticipantStatusRow({
    super.key,
    required this.participant,
    this.isHost = false,
    this.onConfirmPayment,
  });

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusText, statusIcon) = _getStatusInfo();

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
                    Row(
                      children: [
                        Text(
                          participant.displayName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (isHost) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lightBerry,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'HOST',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.deepBerry,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '\$${participant.totalOwed.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.darkFig.withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              _buildStatusBadge(context, statusColor, statusText, statusIcon),
            ],
          ),
          // Confirm Button (only for pending confirmation)
          if (participant.paymentStatus == PaymentStatus.pendingConfirmation &&
              onConfirmPayment != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onConfirmPayment,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Confirm Payment Received'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lushGreen,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, String, IconData) _getStatusInfo() {
    switch (participant.paymentStatus) {
      case PaymentStatus.paid:
        return (AppColors.lushGreen, 'PAID', Icons.check_circle);
      case PaymentStatus.pendingConfirmation:
        return (
          AppColors.warmSpice,
          'PENDING',
          Icons.pending,
        );
      case PaymentStatus.owing:
        return (AppColors.darkFig, 'OWING', Icons.attach_money);
    }
  }

  Widget _buildStatusBadge(
    BuildContext context,
    Color color,
    String text,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class PaymentSummaryCard extends StatelessWidget {
  final double totalCollected;
  final double totalOutstanding;
  final int paidCount;
  final int pendingCount;
  final int owingCount;

  const PaymentSummaryCard({
    super.key,
    required this.totalCollected,
    required this.totalOutstanding,
    required this.paidCount,
    required this.pendingCount,
    required this.owingCount,
  });

  @override
  Widget build(BuildContext context) {
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
            children: [
              Expanded(
                child: _buildAmountColumn(
                  context,
                  'Collected',
                  totalCollected,
                  AppColors.lushGreen,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: AppColors.paleGray,
              ),
              Expanded(
                child: _buildAmountColumn(
                  context,
                  'Outstanding',
                  totalOutstanding,
                  AppColors.warmSpice,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCountChip(context, 'Paid', paidCount, AppColors.lushGreen),
              _buildCountChip(
                  context, 'Pending', pendingCount, AppColors.warmSpice),
              _buildCountChip(context, 'Owing', owingCount, AppColors.paleGray),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountColumn(
    BuildContext context,
    String label,
    double amount,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.darkFig.withOpacity(0.7),
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildCountChip(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
