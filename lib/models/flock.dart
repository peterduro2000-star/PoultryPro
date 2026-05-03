class Flock {
  final String id;
  final String name;
  final String type;
  final int birdCount;
  final int initialBirdCount;
  final double costPerBird;
  final String startDate; // date stocked (when you bought them)
  final int ageAtStocking; // age in days when purchased (0 = day-old chicks)
  final String status;
  final String? breed;
  final String? source;
  final String? housingType;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  // ─── New sync metadata fields ───────────────────────────────────────────
  final String? lastModified; // ISO 8601 string
  final String syncStatus;
  final String? serverId;
  final bool deleted;

  Flock({
    required this.id,
    required this.name,
    required this.type,
    required this.birdCount,
    required this.initialBirdCount,
    required this.costPerBird,
    required this.startDate,
    this.ageAtStocking = 0,
    required this.status,
    this.breed,
    this.source,
    this.housingType,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.lastModified,
    this.syncStatus = 'local',
    this.serverId,
    this.deleted = false,
  });

  double get initialCost => initialBirdCount * costPerBird;

  // Current age in days
  int get currentAgeDays {
    final stocked = DateTime.tryParse(startDate) ?? DateTime.now();
    final daysSinceStocking = DateTime.now().difference(stocked).inDays;
    return ageAtStocking + daysSinceStocking;
  }

  // Current age in weeks
  int get currentAgeWeeks => currentAgeDays ~/ 7;

  // Human readable age string
  String get ageDisplay {
    final days = currentAgeDays;
    final weeks = currentAgeWeeks;
    if (days < 7) return '$days day${days == 1 ? '' : 's'} old';
    if (weeks < 12) {
      return '$weeks week${weeks == 1 ? '' : 's'} old ($days days)';
    }
    final months = days ~/ 30;
    return '$months month${months == 1 ? '' : 's'} old ($weeks weeks)';
  }

  // Vaccination schedule based on bird type and current age
  List<VaccinationMilestone> get vaccinationSchedule {
    if (type.toLowerCase().contains('broiler')) {
      return [
        VaccinationMilestone(
            day: 1,
            name: 'Newcastle + IB (Hitchner B1)',
            done: currentAgeDays >= 1),
        VaccinationMilestone(
            day: 7, name: 'Gumboro (IBD) 1st dose', done: currentAgeDays >= 7),
        VaccinationMilestone(
            day: 14,
            name: 'Newcastle (Lasota) + Gumboro 2nd dose',
            done: currentAgeDays >= 14),
        VaccinationMilestone(
            day: 21, name: 'Newcastle booster', done: currentAgeDays >= 21),
        VaccinationMilestone(
            day: 28,
            name: 'Fowl Pox (if endemic area)',
            done: currentAgeDays >= 28),
      ];
    } else {
      // Layers / Noiler / Local
      return [
        VaccinationMilestone(
            day: 1,
            name: 'Marek\'s Disease (hatchery)',
            done: currentAgeDays >= 1),
        VaccinationMilestone(
            day: 7,
            name: 'Newcastle + IB (Hitchner B1)',
            done: currentAgeDays >= 7),
        VaccinationMilestone(
            day: 14,
            name: 'Gumboro (IBD) 1st dose',
            done: currentAgeDays >= 14),
        VaccinationMilestone(
            day: 21,
            name: 'Gumboro 2nd dose + Newcastle',
            done: currentAgeDays >= 21),
        VaccinationMilestone(
            day: 28, name: 'Fowl Pox', done: currentAgeDays >= 28),
        VaccinationMilestone(
            day: 42,
            name: 'Newcastle (Lasota) booster',
            done: currentAgeDays >= 42),
        VaccinationMilestone(
            day: 63,
            name: 'Newcastle + IB + EDS (76)',
            done: currentAgeDays >= 63),
        VaccinationMilestone(
            day: 112,
            name: 'Pre-lay Newcastle booster (wk 16)',
            done: currentAgeDays >= 112),
      ];
    }
  }

  // Next upcoming vaccination
  VaccinationMilestone? get nextVaccination {
    final upcoming = vaccinationSchedule.where((v) => !v.done).toList();
    return upcoming.isEmpty ? null : upcoming.first;
  }

  // Production stage
  String get productionStage {
    final weeks = currentAgeWeeks;
    if (type.toLowerCase().contains('broiler')) {
      if (weeks < 2) return 'Brooding';
      if (weeks < 4) return 'Growing';
      if (weeks < 6) return 'Finishing';
      return 'Ready for harvest';
    } else {
      if (weeks < 8) return 'Brooding / Chick';
      if (weeks < 18) return 'Grower / Pullet';
      if (weeks < 72) return 'Laying';
      return 'Spent — consider culling';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'birdCount': birdCount,
        'initialBirdCount': initialBirdCount,
        'costPerBird': costPerBird,
        'startDate': startDate,
        'ageAtStocking': ageAtStocking,
        'status': status,
        'breed': breed,
        'source': source,
        'housingType': housingType,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        // Sync metadata
        'lastModified': lastModified,
        'syncStatus': syncStatus,
        'serverId': serverId,
        'deleted': deleted ? 1 : 0,
      };

  factory Flock.fromMap(Map<String, dynamic> map) => Flock(
        id: map['id'] as String,
        name: map['name'] as String,
        type: map['type'] as String,
        birdCount: map['birdCount'] as int,
        initialBirdCount: (map['initialBirdCount'] as num?)?.toInt() ??
            (map['birdCount'] as num).toInt(),
        costPerBird: (map['costPerBird'] as num).toDouble(),
        startDate: map['startDate'] as String,
        ageAtStocking: (map['ageAtStocking'] as num?)?.toInt() ?? 0,
        status: map['status'] as String,
        breed: map['breed'] as String?,
        source: map['source'] as String?,
        housingType: map['housingType'] as String?,
        notes: map['notes'] as String?,
        createdAt: map['createdAt'] as String,
        updatedAt: map['updatedAt'] as String,
        // Sync metadata
        lastModified: map['lastModified'] as String?,
        syncStatus: map['syncStatus'] as String? ?? 'local',
        serverId: map['serverId'] as String?,
        deleted: (map['deleted'] as int? ?? 0) == 1,
      );

  Flock copyWith({
    String? id,
    String? name,
    String? type,
    int? birdCount,
    int? initialBirdCount,
    double? costPerBird,
    String? startDate,
    int? ageAtStocking,
    String? status,
    String? breed,
    String? source,
    String? housingType,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? lastModified,
    String? syncStatus,
    String? serverId,
    bool? deleted,
  }) {
    return Flock(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      birdCount: birdCount ?? this.birdCount,
      initialBirdCount: initialBirdCount ?? this.initialBirdCount,
      costPerBird: costPerBird ?? this.costPerBird,
      startDate: startDate ?? this.startDate,
      ageAtStocking: ageAtStocking ?? this.ageAtStocking,
      status: status ?? this.status,
      breed: breed ?? this.breed,
      source: source ?? this.source,
      housingType: housingType ?? this.housingType,
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
// ─── Vaccination Milestone ────────────────────────────────────────────────────

class VaccinationMilestone {
  final int day;
  final String name;
  final bool done;

  const VaccinationMilestone({
    required this.day,
    required this.name,
    required this.done,
  });

  int daysUntil(int currentAgeDays) => (day - currentAgeDays).clamp(0, 9999);
}
