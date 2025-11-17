import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/supabase_provider.dart';
import '../providers/table_provider.dart';
import '../widgets/bill_item_row.dart';
import '../widgets/complex_split_sheet.dart';
import '../models/table_session.dart';

class ClaimScreen extends ConsumerStatefulWidget {
  final String tableId;

  const ClaimScreen({super.key, required this.tableId});

  @override
  ConsumerState<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends ConsumerState<ClaimScreen> {
  @override
  void initState() {
    super.initState();
    // Load table data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentTableProvider.notifier).loadTable(widget.tableId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tableDataAsync = ref.watch(currentTableProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isHost = ref.watch(isHostProvider);

    // Listen for status changes and navigate to payment screens
    ref.listen<TableStatus?>(tableStatusProvider, (previous, next) {
      if (previous == TableStatus.claiming && next == TableStatus.collecting) {
        // Table was locked, navigate to appropriate screen
        if (isHost) {
          context.go('/table/${widget.tableId}/dashboard');
        } else {
          context.go('/table/${widget.tableId}/payment');
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim Items'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          if (tableDataAsync.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () => _showParticipantsSheet(context),
              tooltip: 'View Participants',
            ),
        ],
      ),
      body: tableDataAsync.when(
        data: (tableData) {
          if (tableData == null) {
            return const Center(child: Text('No table data'));
          }

          // Redirect if already in collecting status
          if (tableData.table.status == TableStatus.collecting) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (isHost) {
                context.go('/table/${widget.tableId}/dashboard');
              } else {
                context.go('/table/${widget.tableId}/payment');
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          // Redirect if settled
          if (tableData.table.status == TableStatus.settled) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 64, color: AppColors.lushGreen),
                  const SizedBox(height: 16),
                  Text(
                    'Table Settled',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('This table has been settled.'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Table info header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.lightBerry.withOpacity(0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Table: ${tableData.table.code}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.deepBerry,
                              ),
                        ),
                        const Spacer(),
                        _buildStatusChip(tableData.table.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tableData.participants.length} participants',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.darkFig.withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ),

              // Instructions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.lightCrust,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.darkFig),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tableData.table.status == TableStatus.claiming
                            ? 'Tap items to claim. Long press to split with others.'
                            : 'Bill is locked. Waiting for payment.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.darkFig.withOpacity(0.8),
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bill items list
              Expanded(
                child: tableData.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: AppColors.darkFig.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items yet',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.darkFig.withOpacity(0.5),
                                  ),
                            ),
                            if (isHost)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Scan or add items to the bill',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppColors.darkFig.withOpacity(0.5),
                                      ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await ref.read(currentTableProvider.notifier).loadTable(widget.tableId);
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: tableData.items.length,
                          itemBuilder: (context, index) {
                            final item = tableData.items[index];
                            return BillItemRow(
                              item: item,
                              participants: tableData.participants,
                              currentUserId: currentUser?.id,
                              isHost: isHost,
                              onTap: tableData.table.status == TableStatus.claiming
                                  ? () => _onItemTap(item.id)
                                  : null,
                              onLongPress: tableData.table.status == TableStatus.claiming
                                  ? () => _onItemLongPress(item, tableData.participants)
                                  : null,
                            );
                          },
                        ),
                      ),
              ),

              // Summary footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.snow,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Subtotal',
                      '\$${tableData.items.fold(0.0, (sum, item) => sum + item.price).toStringAsFixed(2)}',
                    ),
                    if (currentUser != null) ...[
                      const Divider(height: 16),
                      _buildSummaryRow(
                        'Your Total',
                        '\$${_calculateUserTotal(tableData.items, currentUser.id).toStringAsFixed(2)}',
                        isBold: true,
                      ),
                    ],
                    if (isHost && tableData.table.status == TableStatus.claiming) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _hasUnclaimedItems(tableData.items)
                              ? null
                              : () => _lockBill(),
                          child: const Text('Lock Bill & Start Collection'),
                        ),
                      ),
                      if (_hasUnclaimedItems(tableData.items))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'All items must be claimed before locking',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.warmSpice,
                                ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.warmSpice),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(currentTableProvider.notifier).loadTable(widget.tableId);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(TableStatus status) {
    Color color;
    String text;
    switch (status) {
      case TableStatus.claiming:
        color = AppColors.lushGreen;
        text = 'Claiming';
        break;
      case TableStatus.collecting:
        color = AppColors.warmSpice;
        text = 'Collecting';
        break;
      case TableStatus.settled:
        color = AppColors.darkFig;
        text = 'Settled';
        break;
      case TableStatus.cancelled:
        color = AppColors.paleGray;
        text = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: AppColors.darkFig,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? AppColors.deepBerry : AppColors.darkFig,
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }

  double _calculateUserTotal(List items, String userId) {
    double total = 0.0;
    for (final item in items) {
      total += item.getShareForUser(userId);
    }
    return total;
  }

  bool _hasUnclaimedItems(List items) {
    return items.any((item) => !item.isClaimed);
  }

  void _onItemTap(String itemId) {
    ref.read(currentTableProvider.notifier).claimItem(itemId);
  }

  void _onItemLongPress(item, participants) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => ComplexSplitSheet(
          item: item,
          participants: participants,
          onSplit: (userIds) {
            ref.read(currentTableProvider.notifier).splitItemAcrossUsers(item.id, userIds);
          },
        ),
      ),
    );
  }

  void _showParticipantsSheet(BuildContext context) {
    final tableData = ref.read(currentTableProvider).valueOrNull;
    if (tableData == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participants',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...tableData.participants.map((p) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.lightBerry,
                    child: Text(
                      p.initials,
                      style: const TextStyle(
                        color: AppColors.deepBerry,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(p.displayName),
                  subtitle: Text('\$${p.totalOwed.toStringAsFixed(2)} owed'),
                  trailing: p.userId == tableData.table.hostUserId
                      ? const Chip(
                          label: Text('Host'),
                          backgroundColor: AppColors.lightBerry,
                        )
                      : null,
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _lockBill() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lock Bill?'),
        content: const Text(
          'Once locked, no more claims can be made. Participants will be asked to pay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lock Bill'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(currentTableProvider.notifier).lockTable();
    }
  }
}
