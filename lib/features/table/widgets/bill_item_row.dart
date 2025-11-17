import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/bill_item.dart';
import '../models/participant.dart';

class BillItemRow extends StatelessWidget {
  final BillItem item;
  final List<Participant> participants;
  final String? currentUserId;
  final bool isHost;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BillItemRow({
    super.key,
    required this.item,
    required this.participants,
    this.currentUserId,
    this.isHost = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isClaimedByMe = currentUserId != null && item.isClaimedByUser(currentUserId!);
    final isClaimed = item.isClaimed;
    final isOrphan = !isClaimed;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isClaimedByMe
          ? AppColors.lightBerry.withOpacity(0.3)
          : isOrphan
              ? AppColors.lightWarmSpice.withOpacity(0.2)
              : AppColors.snow,
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.description,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkFig,
                          ),
                    ),
                  ),
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepBerry,
                        ),
                  ),
                ],
              ),
              if (isClaimed) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildClaimedByAvatars(context),
                    const Spacer(),
                    if (item.claimantsCount > 1)
                      Text(
                        '\$${item.splitAmount.toStringAsFixed(2)} each',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.darkFig.withOpacity(0.7),
                            ),
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: AppColors.warmSpice.withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Unclaimed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.warmSpice,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClaimedByAvatars(BuildContext context) {
    const maxAvatars = 4;
    final claimants = item.claimedBy.take(maxAvatars).toList();
    final overflow = item.claimantsCount - maxAvatars;

    return Row(
      children: [
        ...claimants.asMap().entries.map((entry) {
          final index = entry.key;
          final claim = entry.value;
          final participant = participants.firstWhere(
            (p) => p.userId == claim.userId,
            orElse: () => Participant(
              id: claim.userId,
              tableId: '',
              userId: claim.userId,
              displayName: 'Unknown',
              paymentStatus: PaymentStatus.owing,
              totalOwed: 0,
            ),
          );

          return Padding(
            padding: EdgeInsets.only(left: index > 0 ? 0 : 0),
            child: Transform.translate(
              offset: Offset(-index * 8.0, 0),
              child: _buildAvatar(participant),
            ),
          );
        }),
        if (overflow > 0)
          Transform.translate(
            offset: Offset(-claimants.length * 8.0, 0),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.paleGray,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.snow, width: 2),
              ),
              child: Center(
                child: Text(
                  '+$overflow',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkFig,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar(Participant participant) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.lightBerry,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.snow, width: 2),
      ),
      child: Center(
        child: Text(
          participant.initials,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.deepBerry,
          ),
        ),
      ),
    );
  }
}
