import 'dart:convert';
import 'dart:typed_data';
import '../../../core/api/api_client.dart';
import '../models/table_session.dart';
import '../models/participant.dart';
import '../models/bill_item.dart';

class TableData {
  final TableSession table;
  final List<Participant> participants;
  final List<BillItem> items;
  final double subTotal;
  final double tax;
  final double tip;

  const TableData({
    required this.table,
    required this.participants,
    required this.items,
    this.subTotal = 0.0,
    this.tax = 0.0,
    this.tip = 0.0,
  });

  factory TableData.fromJson(Map<String, dynamic> json) {
    final tableJson = Map<String, dynamic>.from(json);
    final participantsList = (json['participants'] as List<dynamic>?)
            ?.map((e) => Participant.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((e) => BillItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return TableData(
      table: TableSession.fromJson(tableJson),
      participants: participantsList,
      items: itemsList,
      subTotal: (json['subTotal'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      tip: (json['tip'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory TableData.empty() {
    return TableData(
      table: TableSession(
        id: '',
        code: '',
        hostUserId: '',
        status: TableStatus.claiming,
        createdAt: DateTime.now(),
      ),
      participants: [],
      items: [],
    );
  }

  TableData copyWith({
    TableSession? table,
    List<Participant>? participants,
    List<BillItem>? items,
    double? subTotal,
    double? tax,
    double? tip,
  }) {
    return TableData(
      table: table ?? this.table,
      participants: participants ?? this.participants,
      items: items ?? this.items,
      subTotal: subTotal ?? this.subTotal,
      tax: tax ?? this.tax,
      tip: tip ?? this.tip,
    );
  }
}

class TableRepository {
  final ApiClient apiClient;

  TableRepository({required this.apiClient});

  Future<List<TableSession>> getActiveTables() async {
    try {
      return await apiClient.get(
        '/tables/active',
        parser: (data) {
          if (data == null) return [];
          final tables = data as List<dynamic>;
          return tables
              .map((e) => TableSession.fromJson(e as Map<String, dynamic>))
              .toList();
        },
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
  }

  Future<TableSession?> getActiveTable() async {
    final tables = await getActiveTables();
    return tables.isEmpty ? null : tables.first;
  }

  Future<List<TableSession>> getHistoryTables() async {
    try {
      return await apiClient.get(
        '/tables/history',
        parser: (data) {
          if (data == null) return [];
          final tables = data as List<dynamic>;
          return tables
              .map((e) => TableSession.fromJson(e as Map<String, dynamic>))
              .toList();
        },
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
  }

  Future<TableSession> createTable({String? title}) async {
    return await apiClient.post(
      '/tables',
      body: {
        if (title != null) 'title': title,
      },
      parser: (data) {
        // API returns { "table": SplitTable, "signalRNegotiationPayload": {...} }
        final tableData = data['table'] as Map<String, dynamic>;
        return TableSession.fromJson(tableData);
      },
    );
  }

  Future<TableData> getTableData(String tableId) async {
    return await apiClient.get(
      '/tables/$tableId',
      parser: (data) => TableData.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<TableSession> joinTableByCode(String code) async {
    return await apiClient.post(
      '/tables/$code/join',
      parser: (data) {
        // API returns { "table": SplitTable, "signalRNegotiationPayload": {...} }
        final tableData = data['table'] as Map<String, dynamic>;
        return TableSession.fromJson(tableData);
      },
    );
  }

  Future<BillItem> addItem({
    required String tableId,
    required String description,
    required double price,
  }) async {
    return await apiClient.put(
      '/tables/$tableId/item',
      body: {
        'name': description,
        'price': price,
      },
      parser: (data) => BillItem.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<BillItem> updateItem({
    required String tableId,
    required String itemId,
    required String description,
    required double price,
  }) async {
    return await apiClient.put(
      '/tables/$tableId/items/$itemId',
      body: {
        'name': description,
        'price': price,
      },
      parser: (data) {
        // API returns { message: "...", table: {...} }
        // Extract the updated item from the table
        final tableData = data['table'] as Map<String, dynamic>;
        final items = tableData['items'] as List<dynamic>;
        final updatedItem = items.firstWhere(
          (item) => item['itemId'] == itemId,
          orElse: () => items.last, // Fallback to last item
        );
        return BillItem.fromJson(updatedItem as Map<String, dynamic>);
      },
    );
  }

  Future<void> deleteItem({
    required String tableId,
    required String itemId,
  }) async {
    await apiClient.delete(
      '/tables/$tableId/items/$itemId',
      parser: (_) {},
    );
  }

  Future<void> clearAllItems({
    required String tableId,
  }) async {
    await apiClient.delete(
      '/tables/$tableId/items',
      parser: (_) {},
    );
  }

  /// Scans a bill image and adds items to the table
  /// Returns the number of items detected
  /// Note: Items are saved to the table on the backend,
  /// use getTableData() to fetch the updated items
  Future<int> scanBill({
    required String tableId,
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final base64Image = base64Encode(imageBytes);

    return await apiClient.post(
      '/tables/$tableId/scan',
      body: {
        'image': base64Image,
        'mimeType': mimeType,
      },
      parser: (data) {
        // API returns { message: 'Bill scanned successfully', itemCount: N }
        return (data['itemCount'] as num?)?.toInt() ?? 0;
      },
    );
  }

  Future<TableSession> lockTable(String tableId) async {
    return await apiClient.put(
      '/tables/$tableId/lock',
      parser: (data) => TableSession.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<TableSession> settleTable(String tableId) async {
    return await apiClient.put(
      '/tables/$tableId/settle',
      parser: (data) => TableSession.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> cancelTable(String tableId) async {
    await apiClient.put(
      '/tables/$tableId/cancel',
      parser: (_) {},
    );
  }

  String getJoinLink(String tableCode) {
    return 'pyble://join?code=$tableCode';
  }

  // Phase 2: Claiming methods
  Future<void> claimItem({
    required String tableId,
    required String itemId,
    required String action, // "claim" or "unclaim"
  }) async {
    await apiClient.put(
      '/tables/$tableId/claim',
      body: {
        'itemId': itemId,
        'action': action,
      },
      parser: (_) {},
    );
  }

  Future<void> splitItemAcrossUsers({
    required String tableId,
    required String itemId,
    required List<String> userIds,
  }) async {
    // First unclaim all existing claims, then claim for selected users
    for (final userId in userIds) {
      await apiClient.put(
        '/tables/$tableId/claim',
        body: {
          'itemId': itemId,
          'action': 'claim',
          'userId': userId,
        },
        parser: (_) {},
      );
    }
  }
}

