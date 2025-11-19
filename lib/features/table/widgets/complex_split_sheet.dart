import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyble/core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
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
    // If nobody claimed it yet, pre-select NOBODY (let user choose).
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
    final allSelected = _selectedUserIds.length == widget.participants.length;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: AppColors.paleGray,
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkFig,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.darkFig.withOpacity(0.7),
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
                        color: AppColors.darkFig.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${AppConstants.currencySymbol}${widget.item.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepBerry,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.paleGray),

          // 3. "Select All" Toggle
          InkWell(
            onTap: _toggleSelectAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    allSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: allSelected ? AppColors.deepBerry : AppColors.paleGray,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    allSelected ? "Deselect All" : "Select Everyone",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkFig,
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
                final isSelected = _selectedUserIds.contains(participant.userId);

                return _buildParticipantRow(participant, isSelected);
              },
            ),
          ),

          // 5. Sticky Footer (Summary & Action)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.snow,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                      color: AppColors.lightBerry,
                      borderRadius: AppRadius.allMd,
                      border: Border.all(color: AppColors.deepBerry.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pie_chart,
                                size: 16, color: AppColors.deepBerry),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedUserIds.length} people',
                              style: const TextStyle(
                                color: AppColors.deepBerry,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${AppConstants.currencySymbol}${_splitAmount.toStringAsFixed(2)} / each',
                          style: const TextStyle(
                            color: AppColors.deepBerry,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
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
                          side: const BorderSide(color: AppColors.paleGray),
                          foregroundColor: AppColors.darkFig,
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
                          backgroundColor: AppColors.deepBerry,
                          disabledBackgroundColor: AppColors.paleGray,
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

  Widget _buildParticipantRow(Participant participant, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _toggleParticipant(participant.userId),
        borderRadius: AppRadius.allMd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.lightBerry.withOpacity(0.5) : AppColors.snow,
            borderRadius: AppRadius.allMd,
            border: Border.all(
              color: isSelected ? AppColors.deepBerry : AppColors.paleGray,
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
                    backgroundColor: isSelected ? AppColors.snow : AppColors.paleGray,
                    child: participant.avatarUrl == null
                        ? Text(
                      participant.initials,
                      style: TextStyle(
                        color: isSelected ? AppColors.deepBerry : AppColors.darkFig,
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
                        decoration: const BoxDecoration(
                          color: AppColors.deepBerry,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(
                            Icons.check,
                            size: 10,
                            color: Colors.white
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
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.deepBerry : AppColors.darkFig,
                  ),
                ),
              ),

              // Individual Amount (Optional - helps visualization)
              if (isSelected && _selectedUserIds.isNotEmpty)
                Text(
                  '${AppConstants.currencySymbol}${_splitAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.deepBerry.withOpacity(0.8),
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