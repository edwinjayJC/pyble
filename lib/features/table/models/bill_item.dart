class BillItem {
  final String id;
  final String tableId;
  final String description;
  final double price;

  const BillItem({
    required this.id,
    required this.tableId,
    required this.description,
    required this.price,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: json['id'] as String,
      tableId: json['tableId'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tableId': tableId,
      'description': description,
      'price': price,
    };
  }

  BillItem copyWith({
    String? id,
    String? tableId,
    String? description,
    double? price,
  }) {
    return BillItem(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      description: description ?? this.description,
      price: price ?? this.price,
    );
  }
}
