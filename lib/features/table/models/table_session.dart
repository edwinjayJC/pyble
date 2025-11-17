enum TableStatus {
  claiming,
  collecting,
  settled,
  cancelled;

  factory TableStatus.fromString(String value) {
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
  final String? title;
  final DateTime createdAt;
  final DateTime? closedAt;

  const TableSession({
    required this.id,
    required this.code,
    required this.hostUserId,
    required this.status,
    this.title,
    required this.createdAt,
    this.closedAt,
  });

  factory TableSession.fromJson(Map<String, dynamic> json) {
    return TableSession(
      id: json['id'] as String? ?? '',
      code: json['tableCode'] as String? ?? json['code'] as String? ?? '',
      hostUserId: json['hostUserId'] as String? ?? '',
      status: TableStatus.fromString(json['status'] as String? ?? 'claiming'),
      title: json['title'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      closedAt: json['closedAt'] != null
          ? DateTime.parse(json['closedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tableCode': code,
      'hostUserId': hostUserId,
      'status': status.name,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
    };
  }

  TableSession copyWith({
    String? id,
    String? code,
    String? hostUserId,
    TableStatus? status,
    String? title,
    DateTime? createdAt,
    DateTime? closedAt,
  }) {
    return TableSession(
      id: id ?? this.id,
      code: code ?? this.code,
      hostUserId: hostUserId ?? this.hostUserId,
      status: status ?? this.status,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  bool get isHost => false; // Will be determined by provider
  bool get isClaiming => status == TableStatus.claiming;
  bool get isCollecting => status == TableStatus.collecting;
  bool get isSettled => status == TableStatus.settled;
}

