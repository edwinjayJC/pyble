import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyble/core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart'; // Keep for specific accents if needed
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/bill_item.dart';
import '../models/participant.dart';

class ComplexSplitSheet extends StatefulWidget {
  final BillItem item;
  final List<Participant> participants;
  final Function(List<String> userIds) onSplit;

  const ComplexSplitSheet({
    super.key,
    required this.item,
    required this.participants,
    required this.onSplit,
  });

  @override
  State<ComplexSplitSheet> createState() => _ComplexSplitSheetState();
}

class _ComplexSplitSheetState extends State<ComplexSplitSheet> {
  late Set<String> _selectedUserIds;

  @override
  void initState() {
    super.initState();
    // Pre-select current claimants.
    _selectedUserIds = widget.item.claimedBy.map((c) => c.userId).toSet();
  }

  double get _splitAmount {
    if (_selectedUserIds.isEmpty) return 0.0;
    return widget.item.price / _selectedUserIds.length;
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedUserIds.length == widget.participants.length) {
        _selectedUserIds.clear();
      } else {
        _selectedUserIds = widget.participants.map((p) => p.userId).toSet();
      }
      HapticFeedback.lightImpact();
    });
  }

  void _toggleParticipant(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
      HapticFeedback.selectionClick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final allSelected = _selectedUserIds.length == widget.participants.length;

    return Container(
      decoration: BoxDecoration(
        // FIX: Adapt Surface Color (Snow vs Ink)
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Handle Bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                // FIX: Use Divider Color
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 2. Header Section (Item Info)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Split Item',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${AppConstants.currencySymbol}${widget.item.price.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: theme.dividerColor),

          // 3. "Select All" Toggle
          InkWell(
            onTap: _toggleSelectAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    allSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: allSelected
                        ? colorScheme.primary
                        : theme.dividerColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    allSelected ? "Deselect All" : "Select Everyone",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Scrollable List of Users
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.participants.length,
              itemBuilder: (context, index) {
                final participant = widget.participants[index];
                final isSelected = _selectedUserIds.contains(
                  participant.userId,
                );

                return _buildParticipantRow(context, participant, isSelected);
              },
            ),
          ),

          // 5. Sticky Footer (Summary & Action)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Math Breakdown
                if (_selectedUserIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      // FIX: Use primary with opacity for tint
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: AppRadius.allMd,
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.pie_chart,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedUserIds.length} people',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${AppConstants.currencySymbol}${_splitAmount.toStringAsFixed(2)} / each',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [const FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.dividerColor),
                          foregroundColor: colorScheme.onSurface,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _selectedUserIds.isEmpty
                            ? null
                            : () {
                                widget.onSplit(_selectedUserIds.toList());
                                Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          disabledBackgroundColor: theme.disabledColor,
                        ),
                        child: const Text('Confirm Split'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantRow(
    BuildContext context,
    Participant participant,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _toggleParticipant(participant.userId),
        borderRadius: AppRadius.allMd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // FIX: Adaptive selection color
            color: isSelected
                ? colorScheme.primary.withOpacity(0.1)
                : colorScheme.surface,
            borderRadius: AppRadius.allMd,
            border: Border.all(
              color: isSelected ? colorScheme.primary : theme.dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Avatar with Checkmark overlay
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: participant.avatarUrl != null
                        ? NetworkImage(participant.avatarUrl!)
                        : null,
                    backgroundColor: isSelected
                        ? colorScheme.surface
                        : theme.dividerColor,
                    child: participant.avatarUrl == null
                        ? Text(
                            participant.initials,
                            style: TextStyle(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  if (isSelected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.check,
                          size: 10,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Name
              Expanded(
                child: Text(
                  participant.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              ),

              // Individual Amount (Optional - helps visualization)
              if (isSelected && _selectedUserIds.isNotEmpty)
                Text(
                  '${AppConstants.currencySymbol}${_splitAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: colorScheme.primary.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
