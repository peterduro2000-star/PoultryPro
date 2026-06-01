// lib/models/expense.dart

/// Canonical category constants for expenses.
/// Always use these constants — never raw strings — so that DB queries,
/// filters, and UI labels stay in sync across the entire codebase.
class ExpenseCategory {
  ExpenseCategory._();

  static const String feed       = 'feed';
  static const String chicks     = 'chicks';
  static const String vaccine    = 'vaccine';
  static const String medication = 'medication'; // was 'medicine' in v1 — see fromMap fallback
  static const String labor      = 'labor';
  static const String utilities  = 'utilities';
  static const String equipment  = 'equipment';
  static const String other      = 'other';

  /// All valid categories in display order.
  static const List<String> all = [
    feed,
    chicks,
    vaccine,
    medication,
    labor,
    utilities,
    equipment,
    other,
  ];

  /// Human-readable labels keyed by constant.
  static const Map<String, String> labels = {
    feed:       'Feed',
    chicks:     'Chicks / Day-Old Birds',
    vaccine:    'Vaccine',
    medication: 'Medication',
    labor:      'Labor',
    utilities:  'Utilities',
    equipment:  'Equipment',
    other:      'Other',
  };

  /// Returns the display label for a category string.
  /// Falls back gracefully to the raw value if unknown.
  static String labelFor(String category) =>
      labels[category] ?? _capitalize(category);

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Normalises legacy DB values to current constants.
  /// Extend this map whenever a rename happens in future migrations.
  static String normalise(String raw) {
    const legacyMap = <String, String>{
      'medicine': medication, // v1 -> v2 rename
    };
    return legacyMap[raw.toLowerCase().trim()] ?? raw;
  }
}

/// Canonical payment method constants shared between Expense and Sale.
class PaymentMethod {
  PaymentMethod._();

  static const String cash        = 'cash';
  static const String mobileMoney = 'mobile_money';
  static const String bank        = 'bank';

  static const List<String> all = [cash, mobileMoney, bank];

  static const Map<String, String> labels = {
    cash:        'Cash',
    mobileMoney: 'Mobile Money',
    bank:        'Bank Transfer',
  };

  static String labelFor(String method) =>
      labels[method] ?? method;
}

class Expense {
  final String id;
  final String flockId;

  /// Use [ExpenseCategory] constants — never raw strings.
  final String category;

  final String description;
  final double amount;
  final String date; // ISO 8601 date string (yyyy-MM-dd)

  /// Use [PaymentMethod] constants.
  final String? paymentMethod;

  final String? notes;
  final String createdAt;
  final String updatedAt;

  // --- Sync metadata ---
  final String? lastModified; // ISO 8601 UTC string
  final String syncStatus;   // 'local' | 'pending' | 'synced' | 'conflict'
  final String? serverId;    // Supabase row id once synced
  final bool deleted;        // soft-delete flag

  const Expense({
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

  // --- Serialisation ---

  Map<String, dynamic> toMap() => {
        'id':            id,
        'flockId':       flockId,
        'category':      category,
        'description':   description,
        'amount':        amount,
        'date':          date,
        'paymentMethod': paymentMethod,
        'notes':         notes,
        'createdAt':     createdAt,
        'updatedAt':     updatedAt,
        'lastModified':  lastModified,
        'syncStatus':    syncStatus,
        'serverId':      serverId,
        'deleted':       deleted ? 1 : 0,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id:            map['id'] as String,
        flockId:       map['flockId'] as String,
        // normalise() handles the legacy 'medicine' -> 'medication' rename
        // so old DB rows are corrected at read time without a full migration.
        category:      ExpenseCategory.normalise(map['category'] as String),
        description:   map['description'] as String,
        amount:        (map['amount'] as num).toDouble(),
        date:          map['date'] as String,
        paymentMethod: map['paymentMethod'] as String?,
        notes:         map['notes'] as String?,
        createdAt:     map['createdAt'] as String,
        updatedAt:     map['updatedAt'] as String,
        lastModified:  map['lastModified'] as String?,
        syncStatus:    map['syncStatus'] as String? ?? 'local',
        serverId:      map['serverId'] as String?,
        deleted:       (map['deleted'] as int? ?? 0) == 1,
      );

  // --- Copy ---

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
      id:            id            ?? this.id,
      flockId:       flockId       ?? this.flockId,
      category:      category      ?? this.category,
      description:   description   ?? this.description,
      amount:        amount        ?? this.amount,
      date:          date          ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes:         notes         ?? this.notes,
      createdAt:     createdAt     ?? this.createdAt,
      updatedAt:     updatedAt     ?? this.updatedAt,
      lastModified:  lastModified  ?? this.lastModified,
      syncStatus:    syncStatus    ?? this.syncStatus,
      serverId:      serverId      ?? this.serverId,
      deleted:       deleted       ?? this.deleted,
    );
  }

  // --- Helpers ---

  /// Formatted amount with NGN symbol.
  String get formattedAmount => '\u20a6${amount.toStringAsFixed(0)}';

  /// Human-readable category label.
  String get categoryLabel => ExpenseCategory.labelFor(category);

  /// Human-readable payment method label.
  String get paymentMethodLabel =>
      paymentMethod != null ? PaymentMethod.labelFor(paymentMethod!) : '\u2014';

  @override
  String toString() =>
      'Expense(id: $id, flockId: $flockId, category: $category, '
      'amount: $amount, date: $date)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Expense && other.id == id);

  @override
  int get hashCode => id.hashCode;
}