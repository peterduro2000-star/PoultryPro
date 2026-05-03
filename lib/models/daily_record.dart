class DailyRecord {
  final String id;
  final String flockId;
  final String date;
  final double? feedGiven; // kg
  final double? waterGiven; // liters
  final int? eggsCollected;
  final int? mortalityCount;
  final double? averageWeight; // in kg per bird
  final String? healthObservations;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  // ─── New sync metadata fields ───────────────────────────────────────────
  final String? lastModified;
  final String syncStatus;
  final String? serverId;
  final bool deleted;

  DailyRecord({
    required this.id,
    required this.flockId,
    required this.date,
    this.feedGiven,
    this.waterGiven,
    this.eggsCollected,
    this.mortalityCount,
    this.averageWeight,
    this.healthObservations,
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
        'date': date,
        'feedGiven': feedGiven,
        'waterGiven': waterGiven,
        'eggsCollected': eggsCollected,
        'mortalityCount': mortalityCount,
        'averageWeight': averageWeight,
        'healthObservations': healthObservations,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        // Sync metadata
        'lastModified': lastModified,
        'syncStatus': syncStatus,
        'serverId': serverId,
        'deleted': deleted ? 1 : 0,
      };

  factory DailyRecord.fromMap(Map<String, dynamic> map) => DailyRecord(
        id: map['id'] as String,
        flockId: map['flockId'] as String,
        date: map['date'] as String,
        feedGiven: map['feedGiven'] != null ? (map['feedGiven'] as num).toDouble() : null,
        waterGiven: map['waterGiven'] != null ? (map['waterGiven'] as num).toDouble() : null,
        eggsCollected: map['eggsCollected'] as int?,
        mortalityCount: map['mortalityCount'] as int?,
        averageWeight: map['averageWeight'] != null ? (map['averageWeight'] as num).toDouble() : null,
        healthObservations: map['healthObservations'] as String?,
        notes: map['notes'] as String?,
        createdAt: map['createdAt'] as String,
        updatedAt: map['updatedAt'] as String,
        // Sync metadata
        lastModified: map['lastModified'] as String?,
        syncStatus: map['syncStatus'] as String? ?? 'local',
        serverId: map['serverId'] as String?,
        deleted: (map['deleted'] as int? ?? 0) == 1,
      );

  DailyRecord copyWith({
    String? id,
    String? flockId,
    String? date,
    double? feedGiven,
    double? waterGiven,
    int? eggsCollected,
    int? mortalityCount,
    double? averageWeight,
    String? healthObservations,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? lastModified,
    String? syncStatus,
    String? serverId,
    bool? deleted,
  }) {
    return DailyRecord(
      id: id ?? this.id,
      flockId: flockId ?? this.flockId,
      date: date ?? this.date,
      feedGiven: feedGiven ?? this.feedGiven,
      waterGiven: waterGiven ?? this.waterGiven,
      eggsCollected: eggsCollected ?? this.eggsCollected,
      mortalityCount: mortalityCount ?? this.mortalityCount,
      averageWeight: averageWeight ?? this.averageWeight,
      healthObservations: healthObservations ?? this.healthObservations,
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