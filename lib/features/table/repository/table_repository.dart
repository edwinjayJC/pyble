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
}

class TableRepository {
  final ApiClient apiClient;

  TableRepository({required this.apiClient});

  Future<TableSession?> getActiveTable() async {
    try {
      return await apiClient.get(
        '/tables/active',
        parser: (data) {
          if (data == null) return null;
          return TableSession.fromJson(data as Map<String, dynamic>);
        },
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
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

  Future<List<BillItem>> scanBill({
    required String tableId,
    required Uint8List imageBytes,
  }) async {
    // For now, we'll use a simple base64 encoding
    // In production, you might use multipart form data
    final base64Image = Uri.encodeComponent(
      String.fromCharCodes(imageBytes),
    );

    return await apiClient.post(
      '/tables/$tableId/scan',
      body: {
        'image': base64Image,
      },
      parser: (data) {
        final items = data['items'] as List<dynamic>;
        return items
            .map((e) => BillItem.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<TableSession> lockTable(String tableId) async {
    return await apiClient.put(
      '/tables/$tableId/lock',
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
}
