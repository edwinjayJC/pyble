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
import '../models/split_request.dart';
import '../models/join_request.dart';
import '../models/blocked_user.dart';
import '../widgets/bill_item_row.dart';
import '../widgets/complex_split_sheet.dart';
import '../widgets/split_request_sheet.dart';
import '../models/participant.dart';

class ClaimScreen extends ConsumerStatefulWidget {
  final String tableId;

  const ClaimScreen({super.key, required this.tableId});

  @override
  ConsumerState<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends ConsumerState<ClaimScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableDataAsync = ref.watch(currentTableProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isHost = ref.watch(isHostProvider);
    final theme = Theme.of(context);

    ref.listen<TableStatus?>(tableStatusProvider, (previous, next) {
      final movedToCollection =
          next == TableStatus.collecting ||
          next == TableStatus.pendingPayments ||
          next == TableStatus.readyForHostSettlement;
      if (previous == TableStatus.claiming && movedToCollection) {
        ref.read(currentTableProvider.notifier).stopPolling();
        if (isHost) {
          context.go('/table/${widget.tableId}/dashboard');
        } else {
          context.go('/table/${widget.tableId}/payment');
        }
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(
        context,
        tableDataAsync.valueOrNull?.table.code,
        isHost,
        tableDataAsync.valueOrNull,
      ),
      body: tableDataAsync.when(
        data: (tableData) {
          if (tableData == null) return const Center(child: Text('No Data'));

          if (tableData.table.status == TableStatus.collecting ||
              tableData.table.status == TableStatus.pendingPayments ||
              tableData.table.status == TableStatus.readyForHostSettlement) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(currentTableProvider.notifier).stopPolling();
              if (isHost)
                context.go('/table/${widget.tableId}/dashboard');
              else
                context.go('/table/${widget.tableId}/payment');
            });
            return const Center(child: CircularProgressIndicator());
          }

          if (tableData.table.status == TableStatus.settled) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => context.go('/home'),
            );
            return const Center(child: CircularProgressIndicator());
          }

          final myTotal = _calculateUserTotal(tableData.items, currentUser?.id);
          final unclaimedCount = tableData.items
              .where((i) => !i.isClaimed)
              .length;
          // Calculate total bill for the footer context
          final totalBill = tableData.items.fold(
            0.0,
            (sum, item) => sum + item.price,
          );
          final filteredItems = tableData.items.isEmpty
              ? <({BillItem item, int displayIndex})>[]
              : _filterItemsWithIndex(tableData.items);

          return Column(
            children: [
              if (tableData.items.isNotEmpty) _buildSearchBar(context),
              Expanded(
                child: tableData.items.isEmpty
                    ? _buildEmptyState(context, isHost)
                    : filteredItems.isEmpty
                        ? _buildNoResultsState(context)
                        : ListView.builder(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.sm,
                              bottom: AppSpacing.xl,
                            ),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final entry = filteredItems[index];
                              final item = entry.item;
                              return BillItemRow(
                                item: item,
                                displayIndex: entry.displayIndex,
                                participants: tableData.participants,
                                currentUserId: currentUser?.id,
                                isHost: isHost,
                                onClaimToggle: () => _handleClaimToggle(item.id),
                                onSplit: () => _showSplitSheet(
                                  item,
                                  tableData.participants,
                                ),
                              );
                            },
                          ),
              ),
              _buildStickyFooter(
                context,
                myTotal,
                totalBill,
                unclaimedCount,
                isHost,
                tableData.items,
              ),
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    String? tableCode,
    bool isHost,
    dynamic tableData,
  ) {
    final theme = Theme.of(context);

    return AppBar(
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
        // Join Requests Button (for host only)
        if (isHost)
          Consumer(
            builder: (context, ref, child) {
              final requestsAsync = ref.watch(
                pendingJoinRequestsProvider(widget.tableId),
              );
              return requestsAsync.when(
                data: (requests) {
                  if (requests.isEmpty) return const SizedBox.shrink();
                  return Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.person_add,
                          color: AppColors.lushGreen,
                        ),
                        onPressed: () =>
                            _showJoinRequestsSheet(context, requests),
                        tooltip: 'Join Requests',
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.lushGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${requests.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        // Split Requests Button (for non-hosts)
        if (!isHost)
          Consumer(
            builder: (context, ref, child) {
              final requestsAsync = ref.watch(
                pendingSplitRequestsProvider(widget.tableId),
              );
              return requestsAsync.when(
                data: (requests) {
                  if (requests.isEmpty) return const SizedBox.shrink();
                  return Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.notifications,
                          color: AppColors.warmSpice,
                        ),
                        onPressed: () =>
                            _showSplitRequestsSheet(context, requests),
                        tooltip: 'Split Requests',
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.warmSpice,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${requests.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        if (isHost)
          IconButton(
            icon: Icon(Icons.edit_note, color: theme.colorScheme.primary),
            onPressed: () => context.push('/table/${widget.tableId}/edit'),
            tooltip: 'Edit Bill',
          ),
        IconButton(
          icon: Icon(Icons.people_outline, color: theme.colorScheme.onSurface),
          onPressed: () => _showParticipantsSheet(context),
          tooltip: 'View Participants',
        ),
        if (isHost)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface),
            onSelected: (value) {
              switch (value) {
                case 'invite':
                  context.go('/table/${widget.tableId}/invite');
                  break;
                case 'scan':
                  context.go('/table/${widget.tableId}/scan');
                  break;
                case 'blocked':
                  _showBlockedUsersSheet(context);
                  break;
                case 'cancel':
                  _confirmCancelTable(context);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'invite',
                child: ListTile(
                  leading: Icon(Icons.qr_code),
                  title: Text('Show QR Code'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'scan',
                child: ListTile(
                  leading: Icon(Icons.document_scanner),
                  title: Text('Scan More Items'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'blocked',
                child: ListTile(
                  leading: Icon(Icons.block, color: theme.colorScheme.error),
                  title: Text('Blocked Users'),
                  trailing: (tableData?.blockedUsers.isNotEmpty ?? false)
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${tableData?.blockedUsers.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'cancel',
                child: ListTile(
                  leading: Icon(Icons.cancel, color: theme.colorScheme.error),
                  title: Text(
                    'Cancel Table',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SizedBox(
            width: double.infinity,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by item # or name',
                prefixIcon: Icon(Icons.search, color: theme.hintColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.allMd,
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.allMd,
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.allMd,
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
            ),
          ),
        ),
      ),
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
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          if (isHost) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/table/${widget.tableId}/scan'),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Scan Bill"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: theme.disabledColor),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "No items match your search",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.close),
              label: const Text("Clear search"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStickyFooter(
    BuildContext context,
    double myTotal,
    double totalBill,
    int unclaimedCount,
    bool isHost,
    List<BillItem> items,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
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
                  InkWell(
                    onTap: () => _showParticipantsSheet(context),
                    borderRadius: BorderRadius.circular(20),
                    child: _buildProgressRing(context, items),
                  ),
                ],
              ),
              if (isHost) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: unclaimedCount > 0
                        ? () => _showUnclaimedDialog(unclaimedCount)
                        : () => _showGratuitySheet(
                            context,
                            totalBill,
                          ), // NEW ACTION
                    style: ElevatedButton.styleFrom(
                      backgroundColor: unclaimedCount > 0
                          ? colorScheme.error.withOpacity(0.15) // Tonal Alert
                          : colorScheme.primary, // Ready
                      foregroundColor: unclaimedCount > 0
                          ? colorScheme.error
                          : colorScheme.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          unclaimedCount > 0
                              ? Icons.warning_amber_rounded
                              : Icons.receipt_long,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          unclaimedCount > 0
                              ? "Review $unclaimedCount Unclaimed Items"
                              : "Add Tip & Lock Bill", // Updated Text
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
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
    final activeColor = isComplete
        ? AppColors.lushGreen
        : theme.colorScheme.primary;

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
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // === LOGIC ===

  List<({BillItem item, int displayIndex})> _filterItemsWithIndex(
    List<BillItem> items,
  ) {
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      return items.asMap().entries
          .map(
            (entry) => (item: entry.value, displayIndex: entry.key + 1),
          )
          .toList();
    }

    final normalizedQuery = query.toLowerCase();
    final numericPortion = normalizedQuery.startsWith('#')
        ? normalizedQuery.substring(1)
        : normalizedQuery;
    final parsedIndex = int.tryParse(numericPortion);

    return items.asMap().entries
        .where((entry) {
          final displayIndex = entry.key + 1;
          final matchesIndex =
              parsedIndex != null && displayIndex == parsedIndex;
          final matchesDescription = entry.value.description
              .toLowerCase()
              .contains(normalizedQuery);
          return matchesIndex || matchesDescription;
        })
        .map(
          (entry) => (item: entry.value, displayIndex: entry.key + 1),
        )
        .toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _handleClaimToggle(String itemId) {
    ref.read(currentTableProvider.notifier).claimItem(itemId);
    HapticFeedback.lightImpact();
  }

  void _showSplitSheet(BillItem item, List<Participant> participants) {
    final currentUser = ref.read(currentUserProvider);
    final isHost = ref.read(isHostProvider);

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
          onSplit: (userIds) async {
            if (currentUser == null) return;

            // Separate into self and others
            final selfSelected = userIds.contains(currentUser.id);
            final otherUserIds = userIds
                .where((id) => id != currentUser.id)
                .toList();

            // Check if host is already claimed on this item
            final hostAlreadyClaimed = item.isClaimedByUser(currentUser.id);

            // If host is adding other participants, create split requests
            if (isHost && otherUserIds.isNotEmpty) {
              try {
                // Handle host's own claim first
                if (selfSelected && !hostAlreadyClaimed) {
                  // Host selected themselves and wasn't already claimed - add claim
                  await ref
                      .read(currentTableProvider.notifier)
                      .claimItem(item.id);
                } else if (!selfSelected && hostAlreadyClaimed) {
                  // Host deselected themselves but was claimed - remove claim
                  await ref
                      .read(currentTableProvider.notifier)
                      .claimItem(item.id);
                }
                // If selfSelected && hostAlreadyClaimed, do nothing (already claimed)
                // If !selfSelected && !hostAlreadyClaimed, do nothing (already not claimed)

                // Create split requests for other participants
                final requests = await ref
                    .read(currentTableProvider.notifier)
                    .requestSplit(itemId: item.id, userIds: otherUserIds);

                // Force refresh table data to get latest state
                await ref
                    .read(currentTableProvider.notifier)
                    .loadTable(widget.tableId, showLoading: false);

                // Invalidate split requests provider to refresh notifications
                ref.invalidate(pendingSplitRequestsProvider(widget.tableId));

                if (mounted) {
                  final requestCount = requests.length;
                  if (requestCount > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Split requests sent to $requestCount participant${requestCount > 1 ? 's' : ''}. Waiting for approval.',
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    // Requests already exist for these users
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Split requests already pending for selected participants.',
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              } catch (e) {
                // Refresh to get correct state even on error
                await ref
                    .read(currentTableProvider.notifier)
                    .loadTable(widget.tableId, showLoading: false);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating split request: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            } else {
              // Participant can only claim for themselves, or host selected only themselves
              // Use the regular split flow
              ref
                  .read(currentTableProvider.notifier)
                  .splitItemAcrossUsers(item.id, userIds);
            }
          },
        ),
      ),
    );
  }

  void _showSplitRequestsSheet(
    BuildContext context,
    List<SplitRequest> requests,
  ) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) => SplitRequestSheet(
          requests: requests,
          onRespond: (requestId, action) async {
            try {
              await ref
                  .read(currentTableProvider.notifier)
                  .respondToSplitRequest(requestId: requestId, action: action);

              // Refresh the split requests
              ref.invalidate(pendingSplitRequestsProvider(widget.tableId));

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      action == 'approve'
                          ? 'Split request accepted'
                          : 'Split request declined',
                    ),
                    backgroundColor: action == 'approve'
                        ? AppColors.lushGreen
                        : theme.colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _showJoinRequestsSheet(
    BuildContext context,
    List<JoinRequest> requests,
  ) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.person_add, color: AppColors.lushGreen),
                    const SizedBox(width: 12),
                    Text(
                      "Join Requests",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lushGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${requests.length}',
                        style: TextStyle(
                          color: AppColors.lushGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _buildJoinRequestTile(context, request);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinRequestTile(BuildContext context, JoinRequest request) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lushGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                child: Text(
                  request.initials,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "Wants to join",
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Block button
              IconButton(
                onPressed: () => _blockAndRejectUser(context, request),
                icon: Icon(Icons.block, color: colorScheme.error),
                tooltip: 'Block User',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondToJoinRequest(
                    context,
                    request,
                    'reject',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                  child: const Text("Decline"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondToJoinRequest(
                    context,
                    request,
                    'accept',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lushGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Accept"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respondToJoinRequest(
    BuildContext context,
    JoinRequest request,
    String action,
  ) async {
    try {
      await ref
          .read(joinRequestNotifierProvider(widget.tableId).notifier)
          .respondToRequest(request.id, action);

      if (mounted) {
        Navigator.pop(context); // Close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'accept'
                  ? '${request.displayName} joined the table!'
                  : 'Request declined',
            ),
            backgroundColor:
                action == 'accept' ? AppColors.lushGreen : null,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _blockAndRejectUser(
    BuildContext context,
    JoinRequest request,
  ) async {
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User?'),
        content: Text(
          'Block ${request.displayName}? They won\'t be able to request to join this table again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(joinRequestNotifierProvider(widget.tableId).notifier)
          .blockUser(request.userId);

      if (mounted) {
        Navigator.pop(context); // Close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${request.displayName} has been blocked'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmRemoveParticipant(Participant participant) async {
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant?'),
        content: Text(
          'Remove ${participant.displayName} from the table? They will need to request to join again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Use block to remove (API removes participant when blocked)
      await ref
          .read(joinRequestNotifierProvider(widget.tableId).notifier)
          .blockUser(participant.userId);

      // Immediately unblock so they can request again
      await ref
          .read(joinRequestNotifierProvider(widget.tableId).notifier)
          .unblockUser(participant.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${participant.displayName} removed from table'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmBlockParticipant(Participant participant) async {
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Participant?'),
        content: Text(
          'Block ${participant.displayName}? They will be removed and cannot request to join this table again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(joinRequestNotifierProvider(widget.tableId).notifier)
          .blockUser(participant.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${participant.displayName} has been blocked'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  void _showBlockedUsersSheet(BuildContext context) {
    final theme = Theme.of(context);
    final tableData = ref.read(currentTableProvider).valueOrNull;
    final blockedUsers = tableData?.blockedUsers ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.block, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Text(
                      "Blocked Users",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (blockedUsers.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${blockedUsers.length}',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: blockedUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: theme.disabledColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No blocked users",
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: blockedUsers.length,
                        itemBuilder: (context, index) {
                          final user = blockedUsers[index];
                          return _buildBlockedUserTile(context, user);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedUserTile(
    BuildContext context,
    BlockedUser user,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.error.withOpacity(0.1),
            child: Text(
              user.initials,
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => _unblockUser(context, user),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.lushGreen,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }

  Future<void> _unblockUser(
    BuildContext context,
    BlockedUser user,
  ) async {
    try {
      await ref
          .read(joinRequestNotifierProvider(widget.tableId).notifier)
          .unblockUser(user.userId);

      // Refresh table data to update blocked users list
      await ref
          .read(currentTableProvider.notifier)
          .loadTable(widget.tableId, showLoading: false);

      if (mounted) {
        Navigator.pop(context); // Close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.displayName} has been unblocked'),
            backgroundColor: AppColors.lushGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showParticipantsSheet(BuildContext context) {
    final tableData = ref.read(currentTableProvider).valueOrNull;
    if (tableData == null) return;
    final theme = Theme.of(context);
    final isHost = ref.read(isHostProvider);

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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Who is here?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    "${tableData.participants.length} Guests",
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
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
                  final isHostUser = p.userId == tableData.table.hostUserId;
                  final currentUser = ref.read(currentUserProvider);
                  final isMe = p.userId == currentUser?.id;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.1,
                      ),
                      backgroundImage: p.avatarUrl != null
                          ? NetworkImage(p.avatarUrl!)
                          : null,
                      child: p.avatarUrl == null
                          ? Text(
                              p.initials,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      p.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    trailing: isHostUser
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "HOST",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          )
                        : (isHost && !isMe)
                            ? PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                                onSelected: (value) {
                                  Navigator.pop(context); // Close sheet first
                                  switch (value) {
                                    case 'remove':
                                      _confirmRemoveParticipant(p);
                                      break;
                                    case 'block':
                                      _confirmBlockParticipant(p);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person_remove,
                                          size: 20,
                                          color: theme.colorScheme.error,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Remove from table',
                                          style: TextStyle(
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'block',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.block,
                                          size: 20,
                                          color: theme.colorScheme.error,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Block user',
                                          style: TextStyle(
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : null,
                  );
                },
              ),
            ),
            if (isHost)
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/table/${widget.tableId}/invite');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.person_add),
                    label: const Text("Invite More People"),
                  ),
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
        content: Text("There are still $count items that nobody has claimed."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Back"),
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

  // === THE AWARD WINNING GRATUITY SHEET ===
  void _showGratuitySheet(BuildContext context, double billTotal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Needed for proper keyboard handling
      backgroundColor: Colors.transparent,
      builder: (context) => GratuitySheet(
        billTotal: billTotal,
        onConfirm: (tipAmount) {
          // When confirmed, lock the table with the selected tip
          _lockBill(tipAmount);
        },
      ),
    );
  }

  Future<void> _splitRemainingItems() async {
    final tableData = ref.read(currentTableProvider).valueOrNull;
    if (tableData == null) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final items = tableData.items;
    final participants = tableData.participants;
    final orphans = items.where((i) => !i.isClaimed).toList();

    if (orphans.isEmpty) return;

    // Get other participant IDs (excluding host)
    final otherUserIds = participants
        .map((p) => p.userId)
        .where((id) => id != currentUser.id)
        .toList();

    int totalRequestsSent = 0;

    try {
      for (var item in orphans) {
        // 1. Claim the item for the host immediately
        await ref.read(currentTableProvider.notifier).claimItem(item.id);

        // 2. Create split requests for other participants if there are any
        if (otherUserIds.isNotEmpty) {
          final requests = await ref
              .read(currentTableProvider.notifier)
              .requestSplit(itemId: item.id, userIds: otherUserIds);
          totalRequestsSent += requests.length;
        }
      }

      // Force refresh table data to get latest state
      await ref
          .read(currentTableProvider.notifier)
          .loadTable(widget.tableId, showLoading: false);

      // Invalidate split requests provider to refresh notifications for participants
      ref.invalidate(pendingSplitRequestsProvider(widget.tableId));

      if (mounted) {
        if (totalRequestsSent > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Split ${orphans.length} items among all. $totalRequestsSent request${totalRequestsSent > 1 ? 's' : ''} sent for approval.',
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Split ${orphans.length} items. You are the only participant.',
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      // Refresh to get correct state even on error
      await ref
          .read(currentTableProvider.notifier)
          .loadTable(widget.tableId, showLoading: false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error splitting items: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // Modified _lockBill to accept an optional tip
  Future<void> _lockBill(double tipAmount) async {
    HapticFeedback.mediumImpact();
    // Assuming lockTable now accepts a tipAmount parameter.
    // If your backend isn't ready, you can pass 0.0 for now,
    // but the UI flow is ready for the feature.
    await ref
        .read(currentTableProvider.notifier)
        .lockTable(tipAmount: tipAmount);
  }

  Future<void> _confirmCancelTable(BuildContext context) async {
    // ... (Keep existing cancellation logic)
    final theme = Theme.of(context);
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Table?'),
        content: const Text('This will stop the session for everyone.'),
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
      if (mounted) context.go('/home');
    } catch (e) {
      // Handle error
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

// ==========================================
// NEW: GRATUITY BOTTOM SHEET
// ==========================================

class GratuitySheet extends StatefulWidget {
  final double billTotal;
  final Function(double) onConfirm;

  const GratuitySheet({
    super.key,
    required this.billTotal,
    required this.onConfirm,
  });

  @override
  State<GratuitySheet> createState() => _GratuitySheetState();
}

class _GratuitySheetState extends State<GratuitySheet> {
  int _selectedPercent = 10; // Default 10%
  final TextEditingController _customController = TextEditingController();

  double get _tipAmount {
    if (_selectedPercent == -1) {
      return double.tryParse(_customController.text) ?? 0.0;
    }
    return widget.billTotal * (_selectedPercent / 100);
  }

  double get _finalTotal => widget.billTotal + _tipAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding =
        mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom + 24;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Add Gratuity",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Select a tip for the group. This will be split proportionally.",
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 1. Tip Percentages (Segmented Control)
            Row(
              children: [
                _buildTipButton(10),
                const SizedBox(width: 12),
                _buildTipButton(15),
                const SizedBox(width: 12),
                _buildTipButton(20),
                const SizedBox(width: 12),
                _buildCustomButton(),
              ],
            ),

            if (_selectedPercent == -1) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: "Custom Tip Amount",
                  prefixText: "\$ ",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}), // Refresh math
              ),
            ],

            const SizedBox(height: 24),

            // 2. The Math Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                children: [
                  _buildRow("Subtotal", widget.billTotal, theme),
                  const SizedBox(height: 8),
                  _buildRow("Tip", _tipAmount, theme, isBold: true),
                  const Divider(height: 24),
                  _buildRow("Grand Total", _finalTotal, theme, isTotal: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Lock Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onConfirm(_tipAmount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepBerry,
                  foregroundColor: AppColors.snow,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Confirm & Lock Bill",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipButton(int percent) {
    final isSelected = _selectedPercent == percent;
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPercent = percent;
            HapticFeedback.selectionClick();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor,
              width: 1.5,
            ),
          ),
          child: Text(
            "$percent%",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomButton() {
    final isSelected = _selectedPercent == -1;
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPercent = -1;
            HapticFeedback.selectionClick();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor,
              width: 1.5,
            ),
          ),
          child: Text(
            "Custom",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    double value,
    ThemeData theme, {
    bool isBold = false,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isBold || isTotal ? FontWeight.bold : FontWeight.normal,
            color: theme.colorScheme.onSurface.withOpacity(isTotal ? 1.0 : 0.7),
          ),
        ),
        Text(
          "${AppConstants.currencySymbol}${value.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: isTotal ? 20 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
