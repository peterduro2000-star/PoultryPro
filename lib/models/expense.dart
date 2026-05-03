class Expense {
  final String id;
  final String flockId;
  final String category; // 'feed', 'medicine', 'labor', 'utilities', 'equipment', 'other'
  final String description;
  final double amount;
  final String date;
  final String? paymentMethod; // 'cash', 'mobile_money', 'bank'
  final String? notes;
  final String createdAt;
  final String updatedAt;

  // ─── Sync metadata ───────────────────────────────────────────────────────
  final String? lastModified;
  final String syncStatus;
  final String? serverId;
  final bool deleted;

  Expense({
    required this.id,
    required this.flockId,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
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
        'category': category,
        'description': description,
        'amount': amount,
        'date': date,
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

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as String,
        flockId: map['flockId'] as String,
        category: map['category'] as String,
        description: map['description'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: map['date'] as String,
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

  Expense copyWith({
    String? id,
    String? flockId,
    String? category,
    String? description,
    double? amount,
    String? date,
    String? paymentMethod,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? lastModified,
    String? syncStatus,
    String? serverId,
    bool? deleted,
  }) {
    return Expense(
      id: id ?? this.id,
      flockId: flockId ?? this.flockId,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
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