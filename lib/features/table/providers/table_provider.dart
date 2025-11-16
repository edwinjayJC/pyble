import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/api_provider.dart';
import '../models/table_session.dart';
import '../models/bill_item.dart';
import '../models/item_claim.dart';
import '../models/participant.dart';
import '../repository/table_repository.dart';

final tableRepositoryProvider = Provider<TableRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TableRepository(apiClient);
});

// Current table state
final currentTableProvider =
    AsyncNotifierProvider<CurrentTableNotifier, TableSession?>(
        CurrentTableNotifier.new);

class CurrentTableNotifier extends AsyncNotifier<TableSession?> {
  @override
  Future<TableSession?> build() async {
    return null;
  }

  Future<TableSession> createTable() async {
    final repository = ref.read(tableRepositoryProvider);
    final table = await repository.createTable();
    state = AsyncData(table);
    return table;
  }

  Future<void> loadTableById(String tableId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(tableRepositoryProvider);
      return await repository.getTableById(tableId);
    });
  }

  Future<void> loadTableByCode(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(tableRepositoryProvider);
      return await repository.getTableByCode(code);
    });
  }

  Future<void> checkForActiveTable() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(tableRepositoryProvider);
      return await repository.getActiveTable();
    });
  }

  Future<Participant> joinTable(String code) async {
    final repository = ref.read(tableRepositoryProvider);
    final participant = await repository.joinTable(code);
    // Load the table after joining
    await loadTableByCode(code);
    return participant;
  }

  Future<void> lockTable() async {
    final currentTable = state.value;
    if (currentTable == null) throw Exception('No active table');

    final repository = ref.read(tableRepositoryProvider);
    final updatedTable = await repository.lockTable(currentTable.id);
    state = AsyncData(updatedTable);
  }

  void clear() {
    state = const AsyncData(null);
  }
}

// Bill items for current table
final tableItemsProvider =
    AsyncNotifierProvider<TableItemsNotifier, List<BillItem>>(
        TableItemsNotifier.new);

class TableItemsNotifier extends AsyncNotifier<List<BillItem>> {
  Timer? _pollingTimer;

  @override
  Future<List<BillItem>> build() async {
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    return [];
  }

  Future<void> loadItems(String tableId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(tableRepositoryProvider);
      return await repository.getTableItems(tableId);
    });
  }

  Future<BillItem> addItem({
    required String tableId,
    required String description,
    required double price,
  }) async {
    final repository = ref.read(tableRepositoryProvider);
    final item = await repository.addItem(
      tableId: tableId,
      description: description,
      price: price,
    );

    // Update state optimistically
    final currentItems = state.value ?? [];
    state = AsyncData([...currentItems, item]);

    return item;
  }

  Future<List<BillItem>> scanBill({
    required String tableId,
    required Uint8List imageBytes,
  }) async {
    final repository = ref.read(tableRepositoryProvider);
    final items = await repository.scanBill(
      tableId: tableId,
      imageBytes: imageBytes,
    );

    state = AsyncData(items);
    return items;
  }

  void startPolling(String tableId, {Duration interval = const Duration(seconds: 5)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) async {
      await loadItems(tableId);
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void clear() {
    stopPolling();
    state = const AsyncData([]);
  }
}

// Claims for current table
final tableClaimsProvider =
    AsyncNotifierProvider<TableClaimsNotifier, List<ItemClaim>>(
        TableClaimsNotifier.new);

class TableClaimsNotifier extends AsyncNotifier<List<ItemClaim>> {
  Timer? _pollingTimer;

  @override
  Future<List<ItemClaim>> build() async {
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    return [];
  }

  Future<void> loadClaims(String tableId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(tableRepositoryProvider);
      return await repository.getTableClaims(tableId);
    });
  }

  Future<ItemClaim> claimItem(String billItemId) async {
    final repository = ref.read(tableRepositoryProvider);
    final claim = await repository.claimItem(billItemId: billItemId);

    // Update state optimistically
    final currentClaims = state.value ?? [];
    state = AsyncData([...currentClaims, claim]);

    return claim;
  }

  Future<void> unclaimItem(String claimId) async {
    final repository = ref.read(tableRepositoryProvider);
    await repository.unclaimItem(claimId);

    // Update state optimistically
    final currentClaims = state.value ?? [];
    state = AsyncData(currentClaims.where((c) => c.id != claimId).toList());
  }

  Future<List<ItemClaim>> splitItem({
    required String billItemId,
    required List<String> userIds,
  }) async {
    final repository = ref.read(tableRepositoryProvider);
    final claims = await repository.splitItem(
      billItemId: billItemId,
      userIds: userIds,
    );

    // Update state - remove old claims for this item, add new ones
    final currentClaims = state.value ?? [];
    final filteredClaims =
        currentClaims.where((c) => c.billItemId != billItemId).toList();
    state = AsyncData([...filteredClaims, ...claims]);

    return claims;
  }

  void startPolling(String tableId, {Duration interval = const Duration(seconds: 5)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) async {
      await loadClaims(tableId);
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void clear() {
    stopPolling();
    state = const AsyncData([]);
  }
}

// Participants for current table
final tableParticipantsProvider =
    AsyncNotifierProvider<TableParticipantsNotifier, List<Participant>>(
        TableParticipantsNotifier.new);

class TableParticipantsNotifier extends AsyncNotifier<List<Participant>> {
  Timer? _pollingTimer;

  @override
  Future<List<Participant>> build() async {
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    return [];
  }

  Future<void> loadParticipants(String tableId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(tableRepositoryProvider);
      return await repository.getTableParticipants(tableId);
    });
  }

  void startPolling(String tableId, {Duration interval = const Duration(seconds: 5)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) async {
      await loadParticipants(tableId);
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void clear() {
    stopPolling();
    state = const AsyncData([]);
  }
}
