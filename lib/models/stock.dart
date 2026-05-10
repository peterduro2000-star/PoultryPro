class Stock {
  final String id;
  final String flockId;
  final String itemType;
  final String itemName;
  final double quantity;
  final String unit;
  final double minThreshold;
  final double costPerUnit;
  final String? supplier;
  final String? lastRestockDate;
  final String? expiryDate;
  final String createdAt;
  final String updatedAt;
  final String? lastModified;
  final String syncStatus;
  final String? serverId;
  final bool deleted;

  Stock({
    required this.id,
    required this.flockId,
    required this.itemType,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.minThreshold,
    required this.costPerUnit,
    this.supplier,
    this.lastRestockDate,
    this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
    this.lastModified,
    this.syncStatus = 'local',
    this.serverId,
    this.deleted = false,
  });

  bool get isLow => quantity <= minThreshold;
  bool get isLowStock => quantity <= minThreshold;
  double get totalValue => quantity * costPerUnit;

  Map<String, dynamic> toMap() => {
        'id': id,
        'flockId': flockId,
        'itemType': itemType,
        'itemName': itemName,
        'quantity': quantity,
        'unit': unit,
        'minThreshold': minThreshold,
        'costPerUnit': costPerUnit,
        'supplier': supplier,
        'lastRestockDate': lastRestockDate,
        'expiryDate': expiryDate,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'lastModified': lastModified,
        'syncStatus': syncStatus,
        'serverId': serverId,
        'deleted': deleted ? 1 : 0,
      };

  factory Stock.fromMap(Map<String, dynamic> map) => Stock(
        id: map['id'] as String,
        flockId: map['flockId'] as String,
        itemType: map['itemType'] as String,
        itemName: map['itemName'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        unit: map['unit'] as String,
        minThreshold: (map['minThreshold'] as num).toDouble(),
        costPerUnit: (map['costPerUnit'] as num).toDouble(),
        supplier: map['supplier'] as String?,
        lastRestockDate: map['lastRestockDate'] as String?,
        expiryDate: map['expiryDate'] as String?,
        createdAt: map['createdAt'] as String,
        updatedAt: map['updatedAt'] as String,
        lastModified: map['lastModified'] as String?,
        syncStatus: map['syncStatus'] as String? ?? 'local',
        serverId: map['serverId'] as String?,
        deleted: (map['deleted'] as int? ?? 0) == 1,
      );

  Stock copyWith({
    String? id,
    String? flockId,
    String? itemType,
    String? itemName,
    double? quantity,
    String? unit,
    double? minThreshold,
    double? costPerUnit,
    String? supplier,
    String? lastRestockDate,
    String? expiryDate,
    String? createdAt,
    String? updatedAt,
    String? lastModified,
    String? syncStatus,
    String? serverId,
    bool? deleted,
  }) =>
      Stock(
        id: id ?? this.id,
        flockId: flockId ?? this.flockId,
        itemType: itemType ?? this.itemType,
        itemName: itemName ?? this.itemName,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        minThreshold: minThreshold ?? this.minThreshold,
        costPerUnit: costPerUnit ?? this.costPerUnit,
        supplier: supplier ?? this.supplier,
        lastRestockDate: lastRestockDate ?? this.lastRestockDate,
        expiryDate: expiryDate ?? this.expiryDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
        serverId: serverId ?? this.serverId,
        deleted: deleted ?? this.deleted,
      );
}
