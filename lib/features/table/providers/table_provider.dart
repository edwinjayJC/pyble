import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../repository/table_repository.dart';
import '../models/table_session.dart';
import '../models/participant.dart';
import '../models/bill_item.dart' show BillItem, ClaimedBy;
import '../models/split_request.dart';
import '../models/join_request.dart';

final tableRepositoryProvider = Provider<TableRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TableRepository(apiClient: apiClient);
});

// Current active table state
final currentTableProvider =
    AsyncNotifierProvider<CurrentTableNotifier, TableData?>(() {
      return CurrentTableNotifier();
    });

class CurrentTableNotifier extends AsyncNotifier<TableData?> {
  Timer? _pollingTimer;

  @override
  Future<TableData?> build() async {
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    return null;
  }

  Future<void> createTable({String? title}) async {
    final repository = ref.read(tableRepositoryProvider);
    state = const AsyncValue.loading();

    try {
      final table = await repository.createTable(title: title);
      final tableData = TableData(table: table, participants: [], items: []);
      state = AsyncValue.data(tableData);
      _startPolling(table.id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> loadTable(String tableId, {bool showLoading = true}) async {
    final repository = ref.read(tableRepositoryProvider);

    if (showLoading) {
      state = const AsyncValue.loading();
    }

    try {
      final tableData = await repository.getTableData(tableId);
      state = AsyncValue.data(tableData);
      _startPolling(tableId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Silently refresh table data without showing loading indicator
  Future<void> refreshTable(String tableId) async {
    final repository = ref.read(tableRepositoryProvider);

    try {
      final tableData = await repository.getTableData(tableId);
      state = AsyncValue.data(tableData);
      _startPolling(tableId);
    } catch (e) {
      // Silently fail, keep current state
    }
  }

  /// Join a table by code
  /// Returns a JoinTableResult indicating success or pending request
  Future<JoinTableResult> joinTableByCode(String code) async {
    final repository = ref.read(tableRepositoryProvider);
    state = const AsyncValue.loading();

    try {
      final result = await repository.joinTableByCode(code);

      if (result.isSuccess && result.table != null) {
        final tableData = TableData(table: result.table!, participants: [], items: []);
        state = AsyncValue.data(tableData);
        _startPolling(result.table!.id);
      } else {
        // Request is pending, clear the loading state
        state = const AsyncValue.data(null);
      }

      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> addItem({
    required String description,
    required double price,
  }) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    try {
      final newItem = await repository.addItem(
        tableId: currentData.table.id,
        description: description,
        price: price,
      );

      final updatedItems = [...currentData.items, newItem];
      state = AsyncValue.data(
        TableData(
          table: currentData.table,
          participants: currentData.participants,
          items: updatedItems,
          subTotal: currentData.subTotal + price,
          tax: currentData.tax,
          tip: currentData.tip,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateItem({
    required String itemId,
    required String description,
    required double price,
  }) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    try {
      // Call the editItemOnTable API endpoint
      await repository.updateItem(
        tableId: currentData.table.id,
        itemId: itemId,
        description: description,
        price: price,
      );

      // Reload the table data to ensure consistency with backend
      // The backend recalculates subTotal, so we fetch the updated state
      await loadTable(currentData.table.id, showLoading: false);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteItem(String itemId) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    try {
      // Call the deleteItemFromTable API endpoint
      await repository.deleteItem(
        tableId: currentData.table.id,
        itemId: itemId,
      );

      // Reload the table data to ensure consistency with backend
      // The backend recalculates subTotal, so we fetch the updated state
      await loadTable(currentData.table.id, showLoading: false);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> clearAllItems() async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    try {
      // Call the clearTableItems API endpoint
      await repository.clearAllItems(tableId: currentData.table.id);

      // Reload the table data to ensure consistency with backend
      // The backend resets items, subTotal, tax, and tip
      await loadTable(currentData.table.id, showLoading: false);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> lockTable({double tipAmount = 0.0}) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    try {
      // Pass tip amount to backend - it will calculate proportional distribution
      await repository.lockTable(currentData.table.id, tipAmount: tipAmount);

      // Reload table data from backend to get correct totalOwed values
      // (backend calculates proportional tip distribution for each participant)
      final tableData = await repository.getTableData(currentData.table.id);
      state = AsyncValue.data(tableData);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> unlockTable() async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    try {
      final updatedTable = await repository.unlockTable(currentData.table.id);

      state = AsyncValue.data(
        TableData(
          table: updatedTable,
          participants: currentData.participants,
          items: currentData.items,
          subTotal: currentData.subTotal,
          tax: currentData.tax,
          tip: currentData.tip,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Phase 2: Claiming methods
  Future<void> claimItem(String itemId) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final repository = ref.read(tableRepositoryProvider);

    // Optimistic update
    final updatedItems = currentData.items.map((item) {
      if (item.id == itemId) {
        final alreadyClaimed = item.isClaimedByUser(currentUser.id);
        if (alreadyClaimed) {
          // Remove claim
          final newClaimedBy = item.claimedBy
              .where((c) => c.userId != currentUser.id)
              .toList();
          return item.copyWith(claimedBy: newClaimedBy);
        } else {
          // Add claim
          final newClaimedBy = [
            ...item.claimedBy,
            ClaimedBy(
              userId: currentUser.id,
              share: item.price / (item.claimantsCount + 1),
            ),
          ];
          // Recalculate shares
          final sharePerPerson = item.price / newClaimedBy.length;
          final adjustedClaimedBy = newClaimedBy
              .map((c) => ClaimedBy(userId: c.userId, share: sharePerPerson))
              .toList();
          return item.copyWith(claimedBy: adjustedClaimedBy);
        }
      }
      return item;
    }).toList();

    state = AsyncValue.data(currentData.copyWith(items: updatedItems));

    try {
      final item = currentData.items.firstWhere((i) => i.id == itemId);
      final action = item.isClaimedByUser(currentUser.id) ? 'unclaim' : 'claim';
      await repository.claimItem(
        tableId: currentData.table.id,
        itemId: itemId,
        action: action,
      );
    } catch (e) {
      // Revert on error
      state = AsyncValue.data(currentData);
      rethrow;
    }
  }

  Future<void> splitItemAcrossUsers(String itemId, List<String> userIds) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    // Optimistic update
    final updatedItems = currentData.items.map((item) {
      if (item.id == itemId) {
        final sharePerPerson = item.price / userIds.length;
        final newClaimedBy = userIds
            .map((userId) => ClaimedBy(userId: userId, share: sharePerPerson))
            .toList();
        return item.copyWith(claimedBy: newClaimedBy);
      }
      return item;
    }).toList();

    state = AsyncValue.data(currentData.copyWith(items: updatedItems));

    try {
      await repository.splitItemAcrossUsers(
        tableId: currentData.table.id,
        itemId: itemId,
        userIds: userIds,
      );
    } catch (e) {
      // Revert on error
      state = AsyncValue.data(currentData);
      rethrow;
    }
  }

  Future<void> splitItemAmongAllDiners(String itemId) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    // Get all participant user IDs
    final allUserIds = currentData.participants.map((p) => p.userId).toList();

    if (allUserIds.isEmpty) return;

    await splitItemAcrossUsers(itemId, allUserIds);
  }

  // Split Request methods (for host-initiated splits that require participant approval)

  /// Host requests to split an item with specific participants
  /// This creates pending requests that participants must approve
  Future<List<SplitRequest>> requestSplit({
    required String itemId,
    required List<String> userIds,
  }) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return [];

    final repository = ref.read(tableRepositoryProvider);

    try {
      final requests = await repository.requestSplit(
        tableId: currentData.table.id,
        itemId: itemId,
        userIds: userIds,
      );
      return requests;
    } catch (e) {
      rethrow;
    }
  }

  /// Participant responds to a split request
  Future<void> respondToSplitRequest({
    required String requestId,
    required String action, // "approve" or "reject"
  }) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    try {
      await repository.respondToSplitRequest(
        tableId: currentData.table.id,
        requestId: requestId,
        action: action,
      );

      // Refresh table data to reflect the change if approved
      if (action == 'approve') {
        await loadTable(currentData.table.id, showLoading: false);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> settleTable() async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    try {
      final updatedTable = await repository.settleTable(currentData.table.id);
      state = AsyncValue.data(
        TableData(
          table: updatedTable,
          participants: currentData.participants,
          items: currentData.items,
          subTotal: currentData.subTotal,
          tax: currentData.tax,
          tip: currentData.tip,
        ),
      );
      stopPolling(); // Stop polling once table is settled
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> cancelTable(String tableId) async {
    final repository = ref.read(tableRepositoryProvider);

    try {
      await repository.cancelTable(tableId);
      // Invalidate the active tables provider to refresh the list
      ref.invalidate(activeTablesProvider);
      // Clear current table if it's the one being cancelled
      final currentData = state.valueOrNull;
      if (currentData?.table.id == tableId) {
        clearTable();
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> leaveTable(String tableId) async {
    final repository = ref.read(tableRepositoryProvider);

    try {
      await repository.leaveTable(tableId);
      // Invalidate the active tables provider to refresh the list
      ref.invalidate(activeTablesProvider);
      // Clear current table if it's the one being left
      final currentData = state.valueOrNull;
      if (currentData?.table.id == tableId) {
        clearTable();
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  void _startPolling(String tableId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.tablePollingInterval),
      (_) => _pollTableData(tableId),
    );
  }

  Future<void> _pollTableData(String tableId) async {
    final repository = ref.read(tableRepositoryProvider);

    try {
      final tableData = await repository.getTableData(tableId);
      state = AsyncValue.data(tableData);

      // Also refresh split requests to check for new notifications
      ref.invalidate(pendingSplitRequestsProvider(tableId));
    } catch (e) {
      // Silently fail polling, keep current state
    }
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void clearTable() {
    stopPolling();
    state = const AsyncValue.data(null);
  }
}

// Helper providers
final isHostProvider = Provider<bool>((ref) {
  final currentTable = ref.watch(currentTableProvider).valueOrNull;
  final currentUser = ref.watch(currentUserProvider);

  if (currentTable == null || currentUser == null) return false;
  return currentTable.table.hostUserId == currentUser.id;
});

final tableParticipantsProvider = Provider<List<Participant>>((ref) {
  final tableData = ref.watch(currentTableProvider).valueOrNull;
  return tableData?.participants ?? [];
});

final tableBillItemsProvider = Provider<List<BillItem>>((ref) {
  final tableData = ref.watch(currentTableProvider).valueOrNull;
  return tableData?.items ?? [];
});

final tableStatusProvider = Provider<TableStatus?>((ref) {
  final tableData = ref.watch(currentTableProvider).valueOrNull;
  return tableData?.table.status;
});

// Active tables list
final activeTablesProvider = FutureProvider<List<TableSession>>((ref) async {
  final repository = ref.watch(tableRepositoryProvider);
  return await repository.getActiveTables();
});

// History tables list (settled tables only)
final historyTablesProvider = FutureProvider<List<TableSession>>((ref) async {
  final repository = ref.watch(tableRepositoryProvider);
  return await repository.getHistoryTables();
});

// Check if current user is a host of any active table
final isHostOfActiveTableProvider = FutureProvider<bool>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return false;

  final activeTables = await ref.watch(activeTablesProvider.future);
  return activeTables.any((table) => table.hostUserId == currentUser.id);
});

// Provider to fetch pending split requests for the current user
final pendingSplitRequestsProvider =
    FutureProvider.family<List<SplitRequest>, String>((ref, tableId) async {
      final repository = ref.watch(tableRepositoryProvider);
      return await repository.getSplitRequests(tableId);
    });

// Provider to get the count of pending split requests
final pendingSplitRequestsCountProvider =
    Provider.family<AsyncValue<int>, String>((ref, tableId) {
      final requestsAsync = ref.watch(pendingSplitRequestsProvider(tableId));
      return requestsAsync.whenData((requests) => requests.length);
    });

// Provider to fetch pending join requests for the host
final pendingJoinRequestsProvider =
    FutureProvider.family<List<JoinRequest>, String>((ref, tableId) async {
      final repository = ref.watch(tableRepositoryProvider);
      return await repository.getJoinRequests(tableId);
    });

// Provider to get the count of pending join requests
final pendingJoinRequestsCountProvider =
    Provider.family<AsyncValue<int>, String>((ref, tableId) {
      final requestsAsync = ref.watch(pendingJoinRequestsProvider(tableId));
      return requestsAsync.whenData((requests) => requests.length);
    });

// Notifier for managing join requests
class JoinRequestNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  final String tableId;

  JoinRequestNotifier(this.ref, this.tableId) : super(const AsyncValue.data(null));

  Future<void> respondToRequest(String requestId, String action) async {
    final repository = ref.read(tableRepositoryProvider);
    state = const AsyncValue.loading();

    try {
      await repository.respondToJoinRequest(
        tableId: tableId,
        requestId: requestId,
        action: action,
      );

      // Refresh the join requests and table data
      ref.invalidate(pendingJoinRequestsProvider(tableId));

      // If accepted, refresh table data to show new participant
      if (action == 'accept') {
        await ref.read(currentTableProvider.notifier).loadTable(tableId, showLoading: false);
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> blockUser(String userId) async {
    final repository = ref.read(tableRepositoryProvider);
    state = const AsyncValue.loading();

    try {
      await repository.blockUser(tableId: tableId, userId: userId);

      // Refresh data
      ref.invalidate(pendingJoinRequestsProvider(tableId));
      await ref.read(currentTableProvider.notifier).loadTable(tableId, showLoading: false);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> unblockUser(String userId) async {
    final repository = ref.read(tableRepositoryProvider);
    state = const AsyncValue.loading();

    try {
      await repository.unblockUser(tableId: tableId, userId: userId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final joinRequestNotifierProvider =
    StateNotifierProvider.family<JoinRequestNotifier, AsyncValue<void>, String>(
      (ref, tableId) => JoinRequestNotifier(ref, tableId),
    );
