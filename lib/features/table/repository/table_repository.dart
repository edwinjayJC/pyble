import 'dart:convert';
import 'dart:typed_data';
import '../../../core/api/api_client.dart';
import '../models/table_session.dart';
import '../models/participant.dart';
import '../models/bill_item.dart';
import '../models/split_request.dart';
import '../models/join_request.dart';
import '../models/blocked_user.dart';

/// Result of attempting to join a table
class JoinTableResult {
  final TableSession? table;
  final bool requestPending;
  final String? requestId;
  final String? message;

  const JoinTableResult({
    this.table,
    this.requestPending = false,
    this.requestId,
    this.message,
  });

  bool get isSuccess => table != null;
  bool get isPending => requestPending;
}

class TableData {
  final TableSession table;
  final List<Participant> participants;
  final List<BillItem> items;
  final List<BlockedUser> blockedUsers;
  final double subTotal;
  final double tax;
  final double tip;
  final double totalBillAmountZar;
  final double totalTipAmountZar;
  final double restaurantTotalDueZar;

  const TableData({
    required this.table,
    required this.participants,
    required this.items,
    this.blockedUsers = const [],
    this.subTotal = 0.0,
    this.tax = 0.0,
    this.tip = 0.0,
    this.totalBillAmountZar = 0.0,
    this.totalTipAmountZar = 0.0,
    this.restaurantTotalDueZar = 0.0,
  });

  factory TableData.fromJson(Map<String, dynamic> json) {
    final tableJson = Map<String, dynamic>.from(json);
    final participantsList =
        (json['participants'] as List<dynamic>?)
            ?.map((e) => Participant.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final itemsList =
        (json['items'] as List<dynamic>?)
            ?.map((e) => BillItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final blockedUsersList =
        (json['blockedUsers'] as List<dynamic>?)
            ?.map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return TableData(
      table: TableSession.fromJson(tableJson),
      participants: participantsList,
      items: itemsList,
      blockedUsers: blockedUsersList,
      subTotal: (json['subTotal'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      tip: (json['tip'] as num?)?.toDouble() ?? 0.0,
      totalBillAmountZar:
          (json['totalBillAmountZar'] as num?)?.toDouble() ?? 0.0,
      totalTipAmountZar: (json['totalTipAmountZar'] as num?)?.toDouble() ?? 0.0,
      restaurantTotalDueZar:
          (json['restaurantTotalDueZar'] as num?)?.toDouble() ?? 0.0,
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
      blockedUsers: [],
      totalBillAmountZar: 0.0,
      totalTipAmountZar: 0.0,
      restaurantTotalDueZar: 0.0,
    );
  }

  TableData copyWith({
    TableSession? table,
    List<Participant>? participants,
    List<BillItem>? items,
    List<BlockedUser>? blockedUsers,
    double? subTotal,
    double? tax,
    double? tip,
    double? totalBillAmountZar,
    double? totalTipAmountZar,
    double? restaurantTotalDueZar,
  }) {
    return TableData(
      table: table ?? this.table,
      participants: participants ?? this.participants,
      items: items ?? this.items,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      subTotal: subTotal ?? this.subTotal,
      tax: tax ?? this.tax,
      tip: tip ?? this.tip,
      totalBillAmountZar: totalBillAmountZar ?? this.totalBillAmountZar,
      totalTipAmountZar: totalTipAmountZar ?? this.totalTipAmountZar,
      restaurantTotalDueZar:
          restaurantTotalDueZar ?? this.restaurantTotalDueZar,
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
      body: {if (title != null) 'title': title},
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

  Future<JoinTableResult> joinTableByCode(String code) async {
    try {
      return await apiClient.post(
        '/tables/$code/join',
        parser: (data) {
          // Check if this is a pending request response (202)
          if (data['requestPending'] == true) {
            return JoinTableResult(
              requestPending: true,
              requestId: data['requestId'] as String?,
              message: data['message'] as String?,
            );
          }
          // API returns { "table": SplitTable, "signalRNegotiationPayload": {...} }
          final tableData = data['table'] as Map<String, dynamic>;
          return JoinTableResult(
            table: TableSession.fromJson(tableData),
          );
        },
      );
    } on ApiException catch (e) {
      // Handle 202 Accepted (join request pending)
      if (e.statusCode == 202) {
        return JoinTableResult(
          requestPending: true,
          message: e.message,
        );
      }
      // Handle 409 Conflict (already pending)
      if (e.statusCode == 409 && e.message.contains('pending')) {
        return JoinTableResult(
          requestPending: true,
          message: e.message,
        );
      }
      rethrow;
    }
  }

  Future<BillItem> addItem({
    required String tableId,
    required String description,
    required double price,
  }) async {
    return await apiClient.put(
      '/tables/$tableId/item',
      body: {'name': description, 'price': price},
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
      body: {'name': description, 'price': price},
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
    await apiClient.delete('/tables/$tableId/items/$itemId', parser: (_) {});
  }

  Future<void> clearAllItems({required String tableId}) async {
    await apiClient.delete('/tables/$tableId/items', parser: (_) {});
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
      body: {'image': base64Image, 'mimeType': mimeType},
      parser: (data) {
        // API returns { message: 'Bill scanned successfully', itemCount: N }
        return (data['itemCount'] as num?)?.toInt() ?? 0;
      },
    );
  }

  Future<TableSession> lockTable(
    String tableId, {
    double tipAmount = 0.0,
  }) async {
    return await apiClient.put(
      '/tables/$tableId/lock',
      body: {
        'tipAmount': tipAmount, // Send the tip to the backend
      },
      parser: (data) => TableSession.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<TableSession> unlockTable(String tableId) async {
    return await apiClient.put(
      '/tables/$tableId/unlock',
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
    await apiClient.put('/tables/$tableId/cancel', parser: (_) {});
  }

  Future<void> leaveTable(String tableId) async {
    await apiClient.post('/tables/$tableId/leave', parser: (_) {});
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
      body: {'itemId': itemId, 'action': action},
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
        body: {'itemId': itemId, 'action': 'claim', 'userId': userId},
        parser: (_) {},
      );
    }
  }

  // Split Request methods (for host-initiated splits that require participant approval)

  /// Host requests to split an item with participants
  /// Returns the created split requests
  Future<List<SplitRequest>> requestSplit({
    required String tableId,
    required String itemId,
    required List<String> userIds,
  }) async {
    return await apiClient.post(
      '/tables/$tableId/items/$itemId/request-split',
      body: {'userIds': userIds},
      parser: (data) {
        final requests = data['requests'] as List<dynamic>? ?? [];
        return requests
            .map((e) => SplitRequest.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// Get pending split requests for current user on this table
  Future<List<SplitRequest>> getSplitRequests(String tableId) async {
    return await apiClient.get(
      '/tables/$tableId/split-requests',
      parser: (data) {
        if (data == null) return [];
        final requests = data as List<dynamic>;
        return requests
            .map((e) => SplitRequest.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// Participant responds to a split request (approve or reject)
  Future<SplitRequest> respondToSplitRequest({
    required String tableId,
    required String requestId,
    required String action, // "approve" or "reject"
  }) async {
    return await apiClient.put(
      '/tables/$tableId/split-requests/$requestId/respond',
      body: {'action': action},
      parser: (data) {
        final request = data['request'] as Map<String, dynamic>;
        return SplitRequest.fromJson(request);
      },
    );
  }

  // Join Request methods (for non-friends requesting to join)

  /// Get pending join requests for a table (host only)
  Future<List<JoinRequest>> getJoinRequests(String tableId) async {
    return await apiClient.get(
      '/tables/$tableId/join-requests',
      parser: (data) {
        if (data == null) return [];
        final requests = data as List<dynamic>;
        return requests
            .map((e) => JoinRequest.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// Host responds to a join request (accept or reject)
  Future<JoinRequest> respondToJoinRequest({
    required String tableId,
    required String requestId,
    required String action, // "accept" or "reject"
  }) async {
    return await apiClient.put(
      '/tables/$tableId/join-requests/$requestId',
      body: {'action': action},
      parser: (data) {
        final request = data['request'] as Map<String, dynamic>;
        return JoinRequest.fromJson(request);
      },
    );
  }

  // Block/Unblock methods

  /// Block a user from the table (host only)
  Future<void> blockUser({
    required String tableId,
    required String userId,
  }) async {
    await apiClient.put(
      '/tables/$tableId/block/$userId',
      parser: (_) {},
    );
  }

  /// Unblock a user from the table (host only)
  Future<void> unblockUser({
    required String tableId,
    required String userId,
  }) async {
    await apiClient.delete(
      '/tables/$tableId/block/$userId',
      parser: (_) {},
    );
  }
}
