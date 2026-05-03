class Bird {
  final String id;
  final String flockId;
  final int age; // in weeks
  final int count;
  final String type; // 'chick', 'grower', 'layer', 'broiler'
  final String purchaseDate;
  final double costPerBird;
  final String status; // 'alive', 'sold', 'culled'
  final String createdAt;
  final String updatedAt;

  // ─── Sync metadata ───────────────────────────────────────────────────────
  final String? lastModified;
  final String syncStatus;
  final String? serverId;
  final bool deleted;

  Bird({
    required this.id,
    required this.flockId,
    required this.age,
    required this.count,
    required this.type,
    required this.purchaseDate,
    required this.costPerBird,
    required this.status,
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
        'age': age,
        'count': count,
        'type': type,
        'purchaseDate': purchaseDate,
        'costPerBird': costPerBird,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        // Sync metadata
        'lastModified': lastModified,
        'syncStatus': syncStatus,
        'serverId': serverId,
        'deleted': deleted ? 1 : 0,
      };

  factory Bird.fromMap(Map<String, dynamic> map) => Bird(
        id: map['id'] as String,
        flockId: map['flockId'] as String,
        age: map['age'] as int,
        count: map['count'] as int,
        type: map['type'] as String,
        purchaseDate: map['purchaseDate'] as String,
        costPerBird: (map['costPerBird'] as num).toDouble(),
        status: map['status'] as String,
        createdAt: map['createdAt'] as String,
        updatedAt: map['updatedAt'] as String,
        // Sync metadata
        lastModified: map['lastModified'] as String?,
        syncStatus: map['syncStatus'] as String? ?? 'local',
        serverId: map['serverId'] as String?,
        deleted: (map['deleted'] as int? ?? 0) == 1,
      );

  Bird copyWith({
    String? id,
    String? flockId,
    int? age,
    int? count,
    String? type,
    String? purchaseDate,
    double? costPerBird,
    String? status,
    String? createdAt,
    String? updatedAt,
    String? lastModified,
    String? syncStatus,
    String? serverId,
    bool? deleted,
  }) {
    return Bird(
      id: id ?? this.id,
      flockId: flockId ?? this.flockId,
      age: age ?? this.age,
      count: count ?? this.count,
      type: type ?? this.type,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      costPerBird: costPerBird ?? this.costPerBird,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModified: lastModified ?? this.lastModified,
      syncStatus: syncStatus ?? this.syncStatus,
      serverId: serverId ?? this.serverId,
      deleted: deleted ?? this.deleted,
    );
  }
}