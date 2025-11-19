import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/supabase_provider.dart';

// Feature Imports
import '../providers/table_provider.dart';
import '../models/table_session.dart';
import '../models/bill_item.dart';
import '../widgets/bill_item_row.dart';
import '../widgets/complex_split_sheet.dart';
import '../models/participant.dart';

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
    // Load table data - provider handles polling automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentData = ref.read(currentTableProvider).valueOrNull;
      if (currentData?.table.id == widget.tableId) {
        // Same table already loaded, refresh silently without loading indicator
        ref.read(currentTableProvider.notifier).refreshTable(widget.tableId);
      } else {
        // Different table or no data, load with loading indicator
        ref.read(currentTableProvider.notifier).loadTable(widget.tableId);
      }
    });
  }

  @override
  void dispose() {
    // Stop polling when leaving the screen
    ref.read(currentTableProvider.notifier).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableDataAsync = ref.watch(currentTableProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isHost = ref.watch(isHostProvider);

    ref.listen<TableStatus?>(tableStatusProvider, (previous, next) {
      if (previous == TableStatus.claiming && next == TableStatus.collecting) {
        // Provider handles polling cleanup automatically
        if (isHost) {
          context.go('/table/${widget.tableId}/dashboard');
        } else {
          context.go('/table/${widget.tableId}/payment');
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.lightCrust,
      appBar: _buildAppBar(context, tableDataAsync.valueOrNull?.table.code),
      body: tableDataAsync.when(
        data: (tableData) {
          if (tableData == null) return const Center(child: Text('No Data'));

          // Redirect if table is in collecting status
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/home');
            });
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('Table Settled'),
                ],
              ),
            );
          }

          // Only show the claiming UI if status is claiming
          if (tableData.table.status != TableStatus.claiming) {
            return const Center(child: CircularProgressIndicator());
          }

          final myTotal = _calculateUserTotal(tableData.items, currentUser?.id);
          final unclaimedCount =
              tableData.items.where((i) => !i.isClaimed).length;

          return Column(
            children: [
              Expanded(
                child: tableData.items.isEmpty
                    ? _buildEmptyState(context, isHost)
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                            top: AppSpacing.sm, bottom: AppSpacing.xl),
                        itemCount: tableData.items.length,
                        itemBuilder: (context, index) {
                          final item = tableData.items[index];
                          return BillItemRow(
                            item: item,
                            participants: tableData.participants,
                            currentUserId: currentUser?.id,
                            isHost: isHost,
                            onClaimToggle: () => _handleClaimToggle(item.id),
                            onSplit: () =>
                                _showSplitSheet(item, tableData.participants),
                          );
                        },
                      ),
              ),
              _buildStickyFooter(
                  context, myTotal, unclaimedCount, isHost, tableData.items),
            ],
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.deepBerry)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  // --- FIXED: Explicit Back Button ---
  PreferredSizeWidget _buildAppBar(BuildContext context, String? tableCode) {
    return AppBar(
      backgroundColor: AppColors.snow,
      elevation: 0,
      centerTitle: false,
      // THE FIX: Explicit Leading Button
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.darkFig),
        onPressed: () {
          // Try to pop, if stack empty, go home
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Items',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.darkFig,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (tableCode != null)
            Row(
              children: [
                Text(
                  'Code: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.darkFig.withOpacity(0.6),
                      ),
                ),
                SelectableText(
                  tableCode,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.deepBerry,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                ),
              ],
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.people_outline, color: AppColors.darkFig),
          onPressed: () => _showParticipantsSheet(context),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isHost) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: AppColors.paleGray),
          const SizedBox(height: AppSpacing.md),
          Text(
            isHost ? "Scan a receipt to start" : "Waiting for Host...",
            style: TextStyle(color: AppColors.darkFig.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter(BuildContext context, double myTotal,
      int unclaimedCount, bool isHost, List<BillItem> items) {
    return Container(
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
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "YOUR SHARE",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkFig.withOpacity(0.5),
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        "${AppConstants.currencySymbol}${myTotal.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepBerry,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  _buildProgressRing(items),
                ],
              ),
              if (isHost) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: unclaimedCount > 0
                        ? () => _showUnclaimedDialog(unclaimedCount)
                        : _lockBill,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: unclaimedCount > 0
                          ? AppColors.paleGray
                          : AppColors.deepBerry,
                      foregroundColor: unclaimedCount > 0
                          ? AppColors.darkFig.withOpacity(0.5)
                          : AppColors.snow,
                      elevation: unclaimedCount > 0 ? 0 : 2,
                    ),
                    child: Text(
                      unclaimedCount > 0
                          ? "$unclaimedCount Unclaimed Items Remaining"
                          : "Lock Bill & Collect",
                    ),
                  ),
                ),
              ] else if (unclaimedCount > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "Waiting for group to finish claiming...",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.darkFig.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRing(List<BillItem> items) {
    if (items.isEmpty) return const SizedBox();
    final claimed = items.where((i) => i.isClaimed).length;
    final progress = claimed / items.length;

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: AppColors.paleGray,
            color: progress == 1.0 ? AppColors.lushGreen : AppColors.deepBerry,
            strokeWidth: 4,
          ),
          Center(
            child: progress == 1.0
                ? const Icon(Icons.check, size: 20, color: AppColors.lushGreen)
                : Text(
                    "${(progress * 100).toInt()}%",
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  void _handleClaimToggle(String itemId) {
    ref.read(currentTableProvider.notifier).claimItem(itemId);
    HapticFeedback.lightImpact();
  }

  void _showSplitSheet(BillItem item, List<Participant> participants) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => ComplexSplitSheet(
          item: item,
          participants: participants,
          onSplit: (userIds) {
            ref
                .read(currentTableProvider.notifier)
                .splitItemAcrossUsers(item.id, userIds);
          },
        ),
      ),
    );
  }

  // --- FIXED: Implemented Participants Sheet ---
  void _showParticipantsSheet(BuildContext context) {
    final tableData = ref.read(currentTableProvider).valueOrNull;
    if (tableData == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.snow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Who is here?",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkFig),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: tableData.participants.length,
                separatorBuilder: (ctx, i) =>
                    const Divider(height: 1, color: AppColors.paleGray),
                itemBuilder: (context, index) {
                  final p = tableData.participants[index];
                  final isHost = p.userId == tableData.table.hostUserId;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.lightBerry,
                      backgroundImage: p.avatarUrl != null
                          ? NetworkImage(p.avatarUrl!)
                          : null,
                      child: p.avatarUrl == null
                          ? Text(p.initials,
                              style: const TextStyle(
                                  color: AppColors.deepBerry,
                                  fontWeight: FontWeight.bold))
                          : null,
                    ),
                    title: Text(
                      p.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkFig),
                    ),
                    trailing: isHost
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.deepBerry.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text("HOST",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.deepBerry)),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnclaimedDialog(int count) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Unclaimed Items"),
        content: Text(
            "There are still $count items that nobody has claimed. You must assign them or split them among all diners before locking."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Go Back"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _splitRemainingItems();
            },
            child: const Text("Split Remaining All"),
          ),
        ],
      ),
    );
  }

  Future<void> _splitRemainingItems() async {
    final items = ref.read(currentTableProvider).value!.items;
    final orphans = items.where((i) => !i.isClaimed).toList();
    for (var item in orphans) {
      await ref
          .read(currentTableProvider.notifier)
          .splitItemAmongAllDiners(item.id);
    }
  }

  Future<void> _lockBill() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Finalize Bill?"),
        content: const Text(
            "This will lock claims and send payment requests to all guests."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel",
                style: TextStyle(color: AppColors.darkFig)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.deepBerry),
            child: const Text("Lock & Collect"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(currentTableProvider.notifier).lockTable();
    }
  }

  double _calculateUserTotal(List<BillItem> items, String? userId) {
    if (userId == null) return 0.0;
    double total = 0.0;
    for (final item in items) {
      total += item.getShareForUser(userId);
    }
    return total;
  }
}
