import '../utils/currency_formatter.dart';

enum TransactionType { income, expense }

enum TransactionCategory {
  feed,
  chicks,
  vaccine,
  medication,
  eggs,
  meat,
  birds,
  equipment,
  labor,
  utilities,
  sales,
  other
}

class Transaction {
  final String? id; // nullable as per your original
  final String?
      flockId; // nullable (e.g. general farm expense not tied to one flock)
  final String type; // 'income' or 'expense'
  final String category; // from TransactionCategory enum
  final String description;
  final double amount;
  final double? quantity;
  final double? unitPrice;
  final DateTime date;

  // ─── Sync metadata (added for cloud/offline sync) ────────────────────────
  final String? lastModified; // ISO 8601 string (UTC)
  final String syncStatus; // 'local', 'pending', 'synced', 'conflict'
  final String? serverId; // Firestore/Supabase document ID
  final bool deleted; // soft delete flag

  Transaction({
    this.id,
    this.flockId,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    this.quantity,
    this.unitPrice,
    required this.date,
    this.lastModified,
    this.syncStatus = 'local',
    this.serverId,
    this.deleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'flockId': flockId,
      'type': type,
      'category': category,
      'description': description,
      'amount': amount,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'date': date.toIso8601String(),
      // Sync metadata
      'lastModified': lastModified,
      'syncStatus': syncStatus,
      'serverId': serverId,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String?,
      flockId: map['flockId'] as String?,
      type: map['type'] as String,
      category: map['category'] as String,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      quantity:
          map['quantity'] != null ? (map['quantity'] as num).toDouble() : null,
      unitPrice: map['unitPrice'] != null
          ? (map['unitPrice'] as num).toDouble()
          : null,
      date: DateTime.parse(map['date'] as String),
      // Sync metadata
      lastModified: map['lastModified'] as String?,
      syncStatus: map['syncStatus'] as String? ?? 'local',
      serverId: map['serverId'] as String?,
      deleted: (map['deleted'] as int? ?? 0) == 1,
    );
  }

  Transaction copyWith({
    String? id,
    String? flockId,
    String? type,
    String? category,
    String? description,
    double? amount,
    double? quantity,
    double? unitPrice,
    DateTime? date,
    String? lastModified,
    String? syncStatus,
    String? serverId,
    bool? deleted,
  }) {
    return Transaction(
      id: id ?? this.id,
      flockId: flockId ?? this.flockId,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      date: date ?? this.date,
      lastModified: lastModified ?? this.lastModified,
      syncStatus: syncStatus ?? this.syncStatus,
      serverId: serverId ?? this.serverId,
      deleted: deleted ?? this.deleted,
    );
  }

  // Optional helper: formatted amount with ₦ symbol (Nigeria-specific)
  String get formattedAmount => CurrencyFormatter.format(amount);

  // Quick check if this is income
  bool get isIncome => type == TransactionType.income.name;
}
