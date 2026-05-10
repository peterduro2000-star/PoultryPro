class HealthEvent {
  final String id;
  final String flockId;
  final String date;
  final String
      eventType; // 'vaccination', 'treatment', 'disease', 'observation'
  final String description;
  final String? severity; // 'low', 'medium', 'high'
  final int? affectedBirds;
  final String? medicine;
  final String? dosage;
  final String? photoPath; // local path e.g. from image_picker
  final String? notes;
  final String createdAt;
  final String updatedAt;

  // ─── Sync metadata ───────────────────────────────────────────────────────
  final String? lastModified;
  final String syncStatus;
  final String? serverId;
  final bool deleted;

  HealthEvent({
    required this.id,
    required this.flockId,
    required this.date,
    required this.eventType,
    required this.description,
    this.severity,
    this.affectedBirds,
    this.medicine,
    this.dosage,
    this.photoPath,
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
        'eventType': eventType,
        'description': description,
        'severity': severity,
        'affectedBirds': affectedBirds,
        'medicine': medicine,
        'dosage': dosage,
        'photoPath': photoPath,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        // Sync metadata
        'lastModified': lastModified,
        'syncStatus': syncStatus,
        'serverId': serverId,
        'deleted': deleted ? 1 : 0,
      };

  factory HealthEvent.fromMap(Map<String, dynamic> map) => HealthEvent(
        id: map['id'] as String,
        flockId: map['flockId'] as String,
        date: map['date'] as String,
        eventType: map['eventType'] as String,
        description: map['description'] as String,
        severity: map['severity'] as String?,
        affectedBirds: map['affectedBirds'] as int?,
        medicine: map['medicine'] as String?,
        dosage: map['dosage'] as String?,
        photoPath: map['photoPath'] as String?,
        notes: map['notes'] as String?,
        createdAt: map['createdAt'] as String,
        updatedAt: map['updatedAt'] as String,
        // Sync metadata
        lastModified: map['lastModified'] as String?,
        syncStatus: map['syncStatus'] as String? ?? 'local',
        serverId: map['serverId'] as String?,
        deleted: (map['deleted'] as int? ?? 0) == 1,
      );

  HealthEvent copyWith({
    String? id,
    String? flockId,
    String? date,
    String? eventType,
    String? description,
    String? severity,
    int? affectedBirds,
    String? medicine,
    String? dosage,
    String? photoPath,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? lastModified,
    String? syncStatus,
    String? serverId,
    bool? deleted,
  }) {
    return HealthEvent(
      id: id ?? this.id,
      flockId: flockId ?? this.flockId,
      date: date ?? this.date,
      eventType: eventType ?? this.eventType,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      affectedBirds: affectedBirds ?? this.affectedBirds,
      medicine: medicine ?? this.medicine,
      dosage: dosage ?? this.dosage,
      photoPath: photoPath ?? this.photoPath,
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
