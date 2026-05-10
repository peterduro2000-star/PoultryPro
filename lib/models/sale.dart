class Sale {
  final String id;
  final String flockId;
  final String saleType; // 'eggs', 'birds', 'manure'
  final double quantity;
  final String unit; // 'crates', 'units', 'kg'
  final double pricePerUnit;
  final double totalAmount;
  final String date;
  final String? buyerName;
  final String? paymentMethod; // 'cash', 'mobile_money', 'bank'
  final String? notes;
  final String createdAt;
  final String updatedAt;

  // ─── Sync metadata ───────────────────────────────────────────────────────
  final String? lastModified;
  final String syncStatus;
  final String? serverId;
  final bool deleted;

  Sale({
    required this.id,
    required this.flockId,
    required this.saleType,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.date,
    this.buyerName,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.lastModified,
    this.syncStatus = 'local',
    this.serverId,
    this.deleted = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'flockId': flockId,
        'saleType': saleType,
        'quantity': quantity,
        'unit': unit,
        'pricePerUnit': pricePerUnit,
        'totalAmount': totalAmount,
        'date': date,
        'buyerName': buyerName,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        // Sync metadata
        'lastModified': lastModified,
        'syncStatus': syncStatus,
        'serverId': serverId,
        'deleted': deleted ? 1 : 0,
      };

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id: map['id'] as String,
        flockId: map['flockId'] as String,
        saleType: map['saleType'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        unit: map['unit'] as String,
        pricePerUnit: (map['pricePerUnit'] as num).toDouble(),
        totalAmount: (map['totalAmount'] as num).toDouble(),
        date: map['date'] as String,
        buyerName: map['buyerName'] as String?,
        paymentMethod: map['paymentMethod'] as String?,
        notes: map['notes'] as String?,
        createdAt: map['createdAt'] as String,
        updatedAt: map['updatedAt'] as String,
        // Sync metadata
        lastModified: map['lastModified'] as String?,
        syncStatus: map['syncStatus'] as String? ?? 'local',
        serverId: map['serverId'] as String?,
        deleted: (map['deleted'] as int? ?? 0) == 1,
      );

  Sale copyWith({
    String? id,
    String? flockId,
    String? saleType,
    double? quantity,
    String? unit,
    double? pricePerUnit,
    double? totalAmount,
    String? date,
    String? buyerName,
    String? paymentMethod,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? lastModified,
    String? syncStatus,
    String? serverId,
    bool? deleted,
  }) {
    return Sale(
      id: id ?? this.id,
      flockId: flockId ?? this.flockId,
      saleType: saleType ?? this.saleType,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      buyerName: buyerName ?? this.buyerName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModified: lastModified ?? this.lastModified,
      syncStatus: syncStatus ?? this.syncStatus,
      serverId: serverId ?? this.serverId,
      deleted: deleted ?? this.deleted,
    );
  }
}
