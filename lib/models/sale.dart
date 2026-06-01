// lib/models/sale.dart
import 'expense.dart'; // imports PaymentMethod

/// Canonical sale type constants.
/// Always use these constants — never raw strings.
class SaleType {
  SaleType._();

  static const String eggs      = 'eggs';
  static const String birds     = 'birds';
  static const String manure    = 'manure';
  static const String byproduct = 'byproduct';

  /// All valid sale types in display order.
  static const List<String> all = [eggs, birds, manure, byproduct];

  /// Human-readable labels keyed by constant.
  static const Map<String, String> labels = {
    eggs:      'Eggs',
    birds:     'Live Birds',
    manure:    'Manure',
    byproduct: 'By-product',
  };

  /// Returns the display label for a saleType string.
  static String labelFor(String saleType) =>
      labels[saleType] ?? _capitalize(saleType);

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Canonical unit constants.
/// Units are paired with sale types — e.g. eggs use 'crates',
/// birds use 'units', manure/byproduct use 'kg' or 'bags'.
class SaleUnit {
  SaleUnit._();

  static const String crates = 'crates';
  static const String units  = 'units';
  static const String kg     = 'kg';
  static const String bags   = 'bags';
  static const String litres = 'litres';

  static const List<String> all = [crates, units, kg, bags, litres];

  static const Map<String, String> labels = {
    crates: 'Crates',
    units:  'Units',
    kg:     'Kilograms (kg)',
    bags:   'Bags',
    litres: 'Litres',
  };

  static String labelFor(String unit) => labels[unit] ?? unit;

  /// Suggested units for a given sale type.
  static List<String> forSaleType(String saleType) {
    switch (saleType) {
      case SaleType.eggs:
        return [crates, units];
      case SaleType.birds:
        return [units, kg];
      case SaleType.manure:
        return [bags, kg];
      case SaleType.byproduct:
        return [kg, litres, units];
      default:
        return all;
    }
  }
}

class Sale {
  final String id;
  final String flockId;

  /// Use [SaleType] constants — never raw strings.
  final String saleType;

  final double quantity;

  /// Use [SaleUnit] constants.
  final String unit;

  final double pricePerUnit;
  final double totalAmount;
  final String date; // ISO 8601 date string (yyyy-MM-dd)
  final String? buyerName;

  /// Use [PaymentMethod] constants (imported from expense.dart).
  final String? paymentMethod;

  final String? notes;
  final String createdAt;
  final String updatedAt;

  // --- Sync metadata ---
  final String? lastModified; // ISO 8601 UTC string
  final String syncStatus;   // 'local' | 'pending' | 'synced' | 'conflict'
  final String? serverId;    // Supabase row id once synced
  final bool deleted;        // soft-delete flag

  const Sale({
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

  // --- Serialisation ---

  Map<String, dynamic> toMap() => {
        'id':            id,
        'flockId':       flockId,
        'saleType':      saleType,
        'quantity':      quantity,
        'unit':          unit,
        'pricePerUnit':  pricePerUnit,
        'totalAmount':   totalAmount,
        'date':          date,
        'buyerName':     buyerName,
        'paymentMethod': paymentMethod,
        'notes':         notes,
        'createdAt':     createdAt,
        'updatedAt':     updatedAt,
        'lastModified':  lastModified,
        'syncStatus':    syncStatus,
        'serverId':      serverId,
        'deleted':       deleted ? 1 : 0,
      };

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id:            map['id'] as String,
        flockId:       map['flockId'] as String,
        saleType:      map['saleType'] as String,
        quantity:      (map['quantity'] as num).toDouble(),
        unit:          map['unit'] as String,
        pricePerUnit:  (map['pricePerUnit'] as num).toDouble(),
        totalAmount:   (map['totalAmount'] as num).toDouble(),
        date:          map['date'] as String,
        buyerName:     map['buyerName'] as String?,
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
      id:            id            ?? this.id,
      flockId:       flockId       ?? this.flockId,
      saleType:      saleType      ?? this.saleType,
      quantity:      quantity      ?? this.quantity,
      unit:          unit          ?? this.unit,
      pricePerUnit:  pricePerUnit  ?? this.pricePerUnit,
      totalAmount:   totalAmount   ?? this.totalAmount,
      date:          date          ?? this.date,
      buyerName:     buyerName     ?? this.buyerName,
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

  /// Whether this sale reduces the live bird count in the flock.
  bool get reducesBirdCount => saleType == SaleType.birds;

  /// Formatted total with NGN symbol.
  String get formattedTotal => '\u20a6${totalAmount.toStringAsFixed(0)}';

  /// Formatted price per unit with NGN symbol.
  String get formattedPricePerUnit => '\u20a6${pricePerUnit.toStringAsFixed(0)}';

  /// Human-readable sale type label.
  String get saleTypeLabel => SaleType.labelFor(saleType);

  /// Human-readable unit label.
  String get unitLabel => SaleUnit.labelFor(unit);

  /// Human-readable payment method label.
  String get paymentMethodLabel =>
      paymentMethod != null ? PaymentMethod.labelFor(paymentMethod!) : '\u2014';

  @override
  String toString() =>
      'Sale(id: $id, flockId: $flockId, saleType: $saleType, '
      'quantity: $quantity $unit, total: $totalAmount, date: $date)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Sale && other.id == id);

  @override
  int get hashCode => id.hashCode;
}