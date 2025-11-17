import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../repository/table_repository.dart';
import '../models/table_session.dart';
import '../models/participant.dart';
import '../models/bill_item.dart';

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
