import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/constants/app_constants.dart';
import '../models/bill_item.dart';
import '../models/participant.dart';

class BillItemRow extends StatelessWidget {
  final BillItem item;
  final List<Participant> participants;
  final String? currentUserId;
  final bool isHost;

  // CHANGED: Explicit callbacks for distinct actions
  final VoidCallback? onClaimToggle;
  final VoidCallback? onSplit;

  const BillItemRow({
    super.key,
    required this.item,
    required this.participants,
    this.currentUserId,
    this.isHost = false,
    this.onClaimToggle,
    this.onSplit,
  });

  @override
  Widget build(BuildContext context) {
    final isClaimedByMe = currentUserId != null && item.isClaimedByUser(currentUserId!);
    final isShared = item.claimantsCount > 1;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      // DESIGN FIX: Clean white background. Don't color the whole card pink/red.
      color: AppColors.snow,
      elevation: 0, // Flat modern look
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.allMd,
        side: BorderSide(
          // DESIGN FIX: Use border color to indicate state, not background
          color: isClaimedByMe ? AppColors.deepBerry : AppColors.paleGray,
          width: isClaimedByMe ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Item Details (Left Side)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.description,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkFig,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${AppConstants.currencySymbol}${item.price.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkFig.withOpacity(0.6),
                              fontFeatures: [const FontFeature.tabularFigures()],
                            ),
                          ),
                          if (isShared) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.paleGray,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "÷${item.claimantsCount}",
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkFig,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. The Action Cluster (Right Side)
                Row(
                  children: [
                    // THE FIX: Visible Split Button
                    _buildSplitButton(context, isShared),

                    const SizedBox(width: 8),

                    // THE FIX: Explicit Claim Button
                    _buildClaimButton(context, isClaimedByMe),
                  ],
                ),
              ],
            ),

            // 3. Avatar Footer (Only if others are involved)
            if (item.claimantsCount > 0) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.paleGray),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildClaimedByAvatars(context),
                  const Spacer(),
                  if (isClaimedByMe && isShared)
                    Text(
                      "Your share: ${AppConstants.currencySymbol}${item.getShareForUser(currentUserId!).toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepBerry,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // === NEW COMPONENT: The Split Button ===
  Widget _buildSplitButton(BuildContext context, bool isShared) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSplit,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isShared ? AppColors.lightBerry : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isShared ? AppColors.deepBerry.withOpacity(0.3) : Colors.transparent,
            ),
          ),
          child: Icon(
            Icons.call_split, // The universal "Branch/Split" icon
            size: 20,
            color: isShared ? AppColors.deepBerry : AppColors.darkFig.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  // === NEW COMPONENT: The Claim Toggle ===
  Widget _buildClaimButton(BuildContext context, bool isClaimedByMe) {
    return Material(
      color: isClaimedByMe ? AppColors.deepBerry : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onClaimToggle,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isClaimedByMe ? AppColors.deepBerry : AppColors.paleGray,
              width: 1.5,
            ),
          ),
          child: Text(
            isClaimedByMe ? "Mine" : "Claim",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isClaimedByMe ? AppColors.snow : AppColors.darkFig,
            ),
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
              displayName: '?',
              // initials: '?',
              paymentStatus: PaymentStatus.owing,
            ),
          );

          return Transform.translate(
            offset: Offset(index * -8.0, 0), // Overlap effect
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.snow, width: 2),
              ),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: claim.userId == currentUserId
                    ? AppColors.deepBerry
                    : AppColors.paleGray,
                child: Text(
                  participant.initials,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: claim.userId == currentUserId
                        ? AppColors.snow
                        : AppColors.darkFig,
                  ),
                ),
              ),
            ),
          );
        }),
        if (overflow > 0)
          Transform.translate(
            offset: Offset(claimants.length * -8.0, 0),
            child: CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.lightCrust,
              child: Text(
                '+$overflow',
                style: const TextStyle(fontSize: 9, color: AppColors.darkFig),
              ),
            ),
          ),
      ],
    );
  }
}