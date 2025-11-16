enum TableStatus {
  claiming,
  collecting,
  closed,
  cancelled;

  static TableStatus fromString(String value) {
    return TableStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TableStatus.claiming,
    );
  }
}

class TableSession {
  final String id;
  final String code;
  final String hostUserId;
  final TableStatus status;
  final DateTime createdAt;
  final DateTime? closedAt;

  const TableSession({
    required this.id,
    required this.code,
    required this.hostUserId,
    required this.status,
    required this.createdAt,
    this.closedAt,
  });

  factory TableSession.fromJson(Map<String, dynamic> json) {
    return TableSession(
      id: json['id'] as String,
      code: json['code'] as String,
      hostUserId: json['hostUserId'] as String,
      status: TableStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      closedAt: json['closedAt'] != null
          ? DateTime.parse(json['closedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'hostUserId': hostUserId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
    };
  }

  TableSession copyWith({
    String? id,
    String? code,
    String? hostUserId,
    TableStatus? status,
    DateTime? createdAt,
    DateTime? closedAt,
  }) {
    return TableSession(
      id: id ?? this.id,
      code: code ?? this.code,
      hostUserId: hostUserId ?? this.hostUserId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}
