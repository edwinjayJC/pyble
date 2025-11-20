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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentData = ref.read(currentTableProvider).valueOrNull;
      if (currentData?.table.id == widget.tableId) {
        ref.read(currentTableProvider.notifier).refreshTable(widget.tableId);
      } else {
        ref.read(currentTableProvider.notifier).loadTable(widget.tableId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tableDataAsync = ref.watch(currentTableProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isHost = ref.watch(isHostProvider);
    final theme = Theme.of(context);

    ref.listen<TableStatus?>(tableStatusProvider, (previous, next) {
      if (previous == TableStatus.claiming && next == TableStatus.collecting) {
        ref.read(currentTableProvider.notifier).stopPolling();
        if (isHost) {
          context.go('/table/${widget.tableId}/dashboard');
        } else {
          context.go('/table/${widget.tableId}/payment');
        }
      }
    });

    return Scaffold(
      // FIX: Adapt background color (Light Crust vs Dark Plum)
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(
        context,
        tableDataAsync.valueOrNull?.table.code,
        isHost,
      ),
      body: tableDataAsync.when(
        data: (tableData) {
          if (tableData == null) return const Center(child: Text('No Data'));

          if (tableData.table.status == TableStatus.collecting) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(currentTableProvider.notifier).stopPolling();
              if (isHost) {
                context.go('/table/${widget.tableId}/dashboard');
              } else {
                context.go('/table/${widget.tableId}/payment');
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          if (tableData.table.status == TableStatus.settled) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/home');
            });
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Table Settled', style: TextStyle(color: theme.colorScheme.onSurface)),
                ],
              ),
            );
          }

          if (tableData.table.status != TableStatus.claiming) {
            return const Center(child: CircularProgressIndicator());
          }

          final myTotal = _calculateUserTotal(tableData.items, currentUser?.id);
          final unclaimedCount = tableData.items.where((i) => !i.isClaimed).length;

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
        loading: () => Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, String? tableCode, bool isHost) {
    final theme = Theme.of(context);
    return AppBar(
      // FIX: Adapt surface color (Snow vs Ink)
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
        onPressed: () {
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
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (tableCode != null)
            Row(
              children: [
                Text(
                  'Code: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                SelectableText(
                  tableCode,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
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
          icon: Icon(Icons.people_outline, color: theme.colorScheme.onSurface),
          onPressed: () => _showParticipantsSheet(context),
          tooltip: 'View Participants',
        ),
        if (isHost)
          IconButton(
            icon: Icon(Icons.qr_code_2_outlined,
                color: theme.colorScheme.onSurface),
            tooltip: 'Show Table QR',
            onPressed: () => context.go('/table/${widget.tableId}/invite'),
          ),
        if (isHost)
          IconButton(
            icon: Icon(Icons.document_scanner_outlined,
                color: theme.colorScheme.onSurface),
            tooltip: 'Scan Bill',
            onPressed: () => context.go('/table/${widget.tableId}/scan'),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isHost) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: theme.disabledColor),
          const SizedBox(height: AppSpacing.md),
          Text(
            isHost ? "Scan a receipt to start" : "Waiting for Host...",
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter(BuildContext context, double myTotal,
      int unclaimedCount, bool isHost, List<BillItem> items) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        // FIX: Adapt Footer background
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        "${AppConstants.currencySymbol}${myTotal.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  _buildProgressRing(context, items),
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
                          ? colorScheme.onSurface.withOpacity(0.12)
                          : colorScheme.primary,
                      foregroundColor: unclaimedCount > 0
                          ? colorScheme.onSurface.withOpacity(0.6)
                          : colorScheme.onPrimary,
                      elevation: unclaimedCount > 0 ? 0 : 2,
                    ),
                    child: Text(
                      unclaimedCount > 0
                          ? "$unclaimedCount Unclaimed Items Remaining"
                          : "Lock Bill & Collect",
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _confirmCancelTable(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          colorScheme.onSurface.withOpacity(0.7),
                      side: BorderSide(
                        color: colorScheme.onSurface.withOpacity(0.2),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    child: const Text('Cancel Table'),
                  ),
                ),
              ] else if (unclaimedCount > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "Waiting for group to finish claiming...",
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.5),
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

  Widget _buildProgressRing(BuildContext context, List<BillItem> items) {
    final theme = Theme.of(context);
    if (items.isEmpty) return const SizedBox();

    final claimed = items.where((i) => i.isClaimed).length;
    final progress = claimed / items.length;

    final isComplete = progress == 1.0;
    final activeColor = isComplete ? AppColors.lushGreen : theme.colorScheme.primary;

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: theme.dividerColor,
            color: activeColor,
            strokeWidth: 4,
          ),
          Center(
            child: isComplete
                ? Icon(Icons.check, size: 20, color: activeColor)
                : Text(
              "${(progress * 100).toInt()}%",
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface
              ),
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

  void _showParticipantsSheet(BuildContext context) {
    final tableData = ref.read(currentTableProvider).valueOrNull;
    if (tableData == null) return;

    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Who is here?",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: tableData.participants.length,
                separatorBuilder: (ctx, i) =>
                    Divider(height: 1, color: theme.dividerColor),
                itemBuilder: (context, index) {
                  final p = tableData.participants[index];
                  final isHost = p.userId == tableData.table.hostUserId;
                  return ListTile(
                    leading: CircleAvatar(
                      // FIX: Use themed background for avatars
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      backgroundImage: p.avatarUrl != null
                          ? NetworkImage(p.avatarUrl!)
                          : null,
                      child: p.avatarUrl == null
                          ? Text(p.initials,
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold))
                          : null,
                    ),
                    title: Text(
                      p.displayName,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface),
                    ),
                    trailing: isHost
                        ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text("HOST",
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
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
    final theme = Theme.of(context);
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
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Finalize Bill?"),
        content: const Text(
            "This will lock claims and send payment requests to all guests."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary
            ),
            child: const Text("Lock & Collect"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(currentTableProvider.notifier).lockTable();
    }
  }

  Future<void> _confirmCancelTable(BuildContext context) async {
    final theme = Theme.of(context);
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Table?'),
        content: const Text(
          'This will stop the session and remove the table for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Keep Table',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('Cancel Table'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    try {
      final repository = ref.read(tableRepositoryProvider);
      await repository.cancelTable(widget.tableId);
      ref.read(currentTableProvider.notifier).clearTable();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Table cancelled'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling table: $e'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
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
