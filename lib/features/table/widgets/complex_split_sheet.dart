import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
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
    // Pre-select current claimants
    _selectedUserIds = widget.item.claimedBy.map((c) => c.userId).toSet();
  }

  double get _splitAmount {
    if (_selectedUserIds.isEmpty) return 0.0;
    return widget.item.price / _selectedUserIds.length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                    ),
                  ],
                ),
              ),
              Text(
                '\$${widget.item.price.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepBerry,
                    ),
              ),
            ],
          ),
          const Divider(height: 32),
          Text(
            'Select who shared this item:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.darkFig,
                ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.participants.length,
              itemBuilder: (context, index) {
                final participant = widget.participants[index];
                final isSelected = _selectedUserIds.contains(participant.userId);

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedUserIds.add(participant.userId);
                      } else {
                        _selectedUserIds.remove(participant.userId);
                      }
                    });
                  },
                  title: Text(
                    participant.displayName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: AppColors.darkFig,
                    ),
                  ),
                  subtitle: isSelected && _selectedUserIds.isNotEmpty
                      ? Text(
                          '\$${_splitAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppColors.deepBerry.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                  secondary: CircleAvatar(
                    backgroundColor: isSelected ? AppColors.lightBerry : AppColors.paleGray,
                    child: Text(
                      participant.initials,
                      style: TextStyle(
                        color: isSelected ? AppColors.deepBerry : AppColors.darkFig,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  activeColor: AppColors.deepBerry,
                  checkColor: AppColors.snow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedUserIds.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightBerry.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedUserIds.length} ${_selectedUserIds.length == 1 ? 'person' : 'people'} selected',
                    style: const TextStyle(
                      color: AppColors.deepBerry,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '\$${_splitAmount.toStringAsFixed(2)} each',
                    style: const TextStyle(
                      color: AppColors.deepBerry,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedUserIds.isEmpty
                      ? null
                      : () {
                          widget.onSplit(_selectedUserIds.toList());
                          Navigator.pop(context);
                        },
                  child: const Text('Split'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
