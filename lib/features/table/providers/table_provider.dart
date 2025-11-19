import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../repository/table_repository.dart';
import '../models/table_session.dart';
import '../models/participant.dart';
import '../models/bill_item.dart' show BillItem, ClaimedBy;

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
      final tableData = TableData(
        table: table,
        participants: [],
        items: [],
      );
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

  Future<void> joinTableByCode(String code) async {
    final repository = ref.read(tableRepositoryProvider);
    state = const AsyncValue.loading();

    try {
      final table = await repository.joinTableByCode(code);
      final tableData = TableData(
        table: table,
        participants: [],
        items: [],
      );
      state = AsyncValue.data(tableData);
      _startPolling(table.id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
      state = AsyncValue.data(TableData(
        table: currentData.table,
        participants: currentData.participants,
        items: updatedItems,
        subTotal: currentData.subTotal + price,
        tax: currentData.tax,
        tip: currentData.tip,
      ));
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

  Future<void> lockTable() async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    try {
      final updatedTable = await repository.lockTable(currentData.table.id);

      // Calculate total owed for each participant based on their claims
      final updatedParticipants = currentData.participants.map((participant) {
        double totalOwed = 0.0;
        for (final item in currentData.items) {
          totalOwed += item.getShareForUser(participant.userId);
        }
        return participant.copyWith(totalOwed: totalOwed);
      }).toList();

      state = AsyncValue.data(TableData(
        table: updatedTable,
        participants: updatedParticipants,
        items: currentData.items,
        subTotal: currentData.subTotal,
        tax: currentData.tax,
        tip: currentData.tip,
      ));
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
          final newClaimedBy =
              item.claimedBy.where((c) => c.userId != currentUser.id).toList();
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

  Future<void> settleTable() async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    try {
      final updatedTable = await repository.settleTable(currentData.table.id);
      state = AsyncValue.data(TableData(
        table: updatedTable,
        participants: currentData.participants,
        items: currentData.items,
        subTotal: currentData.subTotal,
        tax: currentData.tax,
        tip: currentData.tip,
      ));
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

// History tables list (settled and cancelled tables)
final historyTablesProvider = FutureProvider<List<TableSession>>((ref) async {
  final repository = ref.watch(tableRepositoryProvider);

  // Fetch both history (settled) and active (which may include cancelled) tables
  final historyTables = await repository.getHistoryTables();
  final activeTables = await repository.getActiveTables();

  // Filter active tables to only include cancelled ones
  final cancelledTables = activeTables
      .where((table) => table.status == TableStatus.cancelled)
      .toList();

  // Combine settled and cancelled tables
  final allHistoryTables = [...historyTables, ...cancelledTables];

  // Remove duplicates (in case a table appears in both lists)
  final uniqueTables = <String, TableSession>{};
  for (final table in allHistoryTables) {
    uniqueTables[table.id] = table;
  }

  return uniqueTables.values.toList();
});

// Check if current user is a host of any active table
final isHostOfActiveTableProvider = FutureProvider<bool>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return false;

  final activeTables = await ref.watch(activeTablesProvider.future);
  return activeTables.any((table) => table.hostUserId == currentUser.id);
});
