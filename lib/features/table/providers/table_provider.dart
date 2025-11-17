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

  Future<void> loadTable(String tableId) async {
    final repository = ref.read(tableRepositoryProvider);
    state = const AsyncValue.loading();

    try {
      final tableData = await repository.getTableData(tableId);
      state = AsyncValue.data(tableData);
      _startPolling(tableId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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

  Future<void> lockTable() async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    try {
      final updatedTable = await repository.lockTable(currentData.table.id);
      state = AsyncValue.data(TableData(
        table: updatedTable,
        participants: currentData.participants,
        items: currentData.items,
        subTotal: currentData.subTotal,
        tax: currentData.tax,
        tip: currentData.tip,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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

  Future<void> splitItemAcrossUsers(
      String itemId, List<String> userIds) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);

    // Optimistic update
    final updatedItems = currentData.items.map((item) {
      if (item.id == itemId) {
        final sharePerPerson = item.price / userIds.length;
        final newClaimedBy = userIds
            .map((userId) =>
                ClaimedBy(userId: userId, share: sharePerPerson))
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
