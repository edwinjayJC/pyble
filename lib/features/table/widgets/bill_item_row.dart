import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For FontFeature

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/constants/app_constants.dart';

// Feature Imports
import '../models/bill_item.dart';
import '../models/participant.dart';

class BillItemRow extends StatelessWidget {
  final BillItem item;
  final List<Participant> participants;
  final String? currentUserId;
  final bool isHost;
  final int? displayIndex;

  final VoidCallback? onClaimToggle;
  final VoidCallback? onSplit;

  const BillItemRow({
    super.key,
    required this.item,
    required this.participants,
    this.currentUserId,
    this.isHost = false,
    this.displayIndex,
    this.onClaimToggle,
    this.onSplit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isClaimedByMe =
        currentUserId != null && item.isClaimedByUser(currentUserId!);
    final isShared = item.claimantsCount > 1;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      // FIX: Use Surface Color (Snow vs Ink)
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.allMd,
        side: BorderSide(
          // FIX: Use Primary for active, Divider for inactive
          color: isClaimedByMe ? colorScheme.primary : theme.dividerColor,
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
                if (displayIndex != null) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '#$displayIndex',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                // 1. Item Details (Left Side)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.description,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface, // Dark Fig / White
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${AppConstants.currencySymbol}${item.price.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface.withOpacity(0.6),
                              fontFeatures: [
                                const FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          if (isShared) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                // FIX: Use divider color for neutral background
                                color: theme.dividerColor.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "÷${item.claimantsCount}",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
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
                    _buildSplitButton(context, isShared),
                    const SizedBox(width: 8),
                    _buildClaimButton(context, isClaimedByMe),
                  ],
                ),
              ],
            ),

            // 3. Avatar Footer
            if (item.claimantsCount > 0) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildClaimedByAvatars(context),
                  const Spacer(),
                  if (isClaimedByMe && isShared)
                    Text(
                      "Your share: ${AppConstants.currencySymbol}${item.getShareForUser(currentUserId!).toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
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

  // === THEME-AWARE SPLIT BUTTON ===
  Widget _buildSplitButton(BuildContext context, bool isShared) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSplit,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            // Active: Tinted Primary. Inactive: Transparent
            color: isShared
                ? colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isShared
                  ? colorScheme.primary.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Icon(
            Icons.call_split,
            size: 20,
            // Active: Primary. Inactive: Faded Text Color
            color: isShared
                ? colorScheme.primary
                : colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  // === THEME-AWARE CLAIM BUTTON ===
  Widget _buildClaimButton(BuildContext context, bool isClaimedByMe) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isClaimedByMe ? colorScheme.primary : Colors.transparent,
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
              color: isClaimedByMe ? colorScheme.primary : theme.dividerColor,
              width: 1.5,
            ),
          ),
          child: Text(
            isClaimedByMe ? "Mine" : "Claim",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              // Active: OnPrimary (White/Black). Inactive: OnSurface (Fig/White)
              color: isClaimedByMe
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  // === THEME-AWARE AVATARS ===
  Widget _buildClaimedByAvatars(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              paymentStatus: PaymentStatus.owing,
            ),
          );

          return Transform.translate(
            offset: Offset(index * -8.0, 0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Border matches the Card background to create "cutout" effect
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              child: CircleAvatar(
                radius: 12,
                backgroundImage: participant.avatarUrl != null
                    ? NetworkImage(participant.avatarUrl!)
                    : null,
                backgroundColor: claim.userId == currentUserId
                    ? colorScheme.primary
                    : theme.dividerColor,
                child: participant.avatarUrl == null
                    ? Text(
                        participant.initials,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: claim.userId == currentUserId
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                      )
                    : null,
              ),
            ),
          );
        }),
        if (overflow > 0)
          Transform.translate(
            offset: Offset(claimants.length * -8.0, 0),
            child: CircleAvatar(
              radius: 12,
              backgroundColor: theme.dividerColor,
              child: Text(
                '+$overflow',
                style: TextStyle(fontSize: 9, color: colorScheme.onSurface),
              ),
            ),
          ),
      ],
    );
  }
}
