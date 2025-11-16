import 'dart:typed_data';
import '../../../core/api/api_client.dart';
import '../models/table_session.dart';
import '../models/bill_item.dart';
import '../models/item_claim.dart';
import '../models/participant.dart';

class TableRepository {
  final ApiClient _apiClient;

  TableRepository(this._apiClient);

  Future<TableSession?> getActiveTable() async {
    try {
      return await _apiClient.get<TableSession>(
        '/tables/active',
        fromJson: (json) => TableSession.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      // No active table
      return null;
    }
  }

  Future<TableSession> createTable() async {
    return _apiClient.post<TableSession>(
      '/tables',
      fromJson: (json) => TableSession.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<TableSession> getTableByCode(String code) async {
    return _apiClient.get<TableSession>(
      '/tables/code/$code',
      fromJson: (json) => TableSession.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<TableSession> getTableById(String tableId) async {
    return _apiClient.get<TableSession>(
      '/tables/$tableId',
      fromJson: (json) => TableSession.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<Participant> joinTable(String code) async {
    return _apiClient.post<Participant>(
      '/tables/code/$code/join',
      fromJson: (json) => Participant.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<BillItem>> getTableItems(String tableId) async {
    return _apiClient.get<List<BillItem>>(
      '/tables/$tableId/items',
      fromJson: (json) => (json as List)
          .map((item) => BillItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<BillItem> addItem({
    required String tableId,
    required String description,
    required double price,
  }) async {
    return _apiClient.post<BillItem>(
      '/tables/$tableId/items',
      body: {
        'description': description,
        'price': price,
      },
      fromJson: (json) => BillItem.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<BillItem>> scanBill({
    required String tableId,
    required Uint8List imageBytes,
  }) async {
    // Note: This would typically use multipart form data
    // For now, we'll send as base64
    final base64Image = String.fromCharCodes(imageBytes);
    return _apiClient.post<List<BillItem>>(
      '/tables/$tableId/scan',
      body: {
        'image': base64Image,
      },
      fromJson: (json) => (json as List)
          .map((item) => BillItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<ItemClaim>> getTableClaims(String tableId) async {
    return _apiClient.get<List<ItemClaim>>(
      '/tables/$tableId/claims',
      fromJson: (json) => (json as List)
          .map((claim) => ItemClaim.fromJson(claim as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<ItemClaim> claimItem({
    required String billItemId,
  }) async {
    return _apiClient.post<ItemClaim>(
      '/claims',
      body: {
        'billItemId': billItemId,
      },
      fromJson: (json) => ItemClaim.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> unclaimItem(String claimId) async {
    await _apiClient.delete('/claims/$claimId');
  }

  Future<List<ItemClaim>> splitItem({
    required String billItemId,
    required List<String> userIds,
  }) async {
    return _apiClient.post<List<ItemClaim>>(
      '/claims/split',
      body: {
        'billItemId': billItemId,
        'userIds': userIds,
      },
      fromJson: (json) => (json as List)
          .map((claim) => ItemClaim.fromJson(claim as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<ItemClaim>> splitItemAmongAll(String itemId) async {
    return _apiClient.post<List<ItemClaim>>(
      '/items/$itemId/split-all',
      fromJson: (json) => (json as List)
          .map((claim) => ItemClaim.fromJson(claim as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<TableSession> lockTable(String tableId) async {
    return _apiClient.put<TableSession>(
      '/tables/$tableId/lock',
      fromJson: (json) => TableSession.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<Participant>> getTableParticipants(String tableId) async {
    return _apiClient.get<List<Participant>>(
      '/tables/$tableId/participants',
      fromJson: (json) => (json as List)
          .map((p) => Participant.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
