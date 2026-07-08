import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/license_provider.dart';
import '../services/database_service.dart';
import '../services/feature_gate.dart';
import '../services/supabase_auth_service.dart';

/// Maps local SQLite table names → Supabase table names.
/// Local uses camelCase columns; Supabase uses snake_case.
const Map<String, String> _supabaseTables = {
  'flocks':        'flocks',
  'expenses':      'expenses',
  'sales':         'sales',
  'daily_records': 'daily_records',
  'stock':         'stock',
  'health_events': 'health_events',
};

/// Maps local camelCase column names → Supabase snake_case column names
/// for each table. Only columns that differ need to be listed.
const Map<String, Map<String, String>> _columnMap = {
  'flocks': {
    'birdCount':        'bird_count',
    'initialBirdCount': 'initial_bird_count',
    'costPerBird':      'cost_per_bird',
    'startDate':        'start_date',
    'ageAtStocking':    'age_at_stocking',
    'housingType':      'housing_type',
    'createdAt':        'created_at',
    'updatedAt':        'updated_at',
    'lastModified':     'last_modified',
    'syncStatus':       'sync_status',
    'serverId':         'server_id',
  },
  'expenses': {
    'flockId':       'flock_id',
    'paymentMethod': 'payment_method',
    'createdAt':     'created_at',
    'updatedAt':     'updated_at',
    'lastModified':  'last_modified',
    'syncStatus':    'sync_status',
    'serverId':      'server_id',
  },
  'sales': {
    'flockId':       'flock_id',
    'saleType':      'sale_type',
    'pricePerUnit':  'price_per_unit',
    'totalAmount':   'total_amount',
    'buyerName':     'buyer_name',
    'paymentMethod': 'payment_method',
    'createdAt':     'created_at',
    'updatedAt':     'updated_at',
    'lastModified':  'last_modified',
    'syncStatus':    'sync_status',
    'serverId':      'server_id',
  },
  'daily_records': {
    'flockId':             'flock_id',
    'feedGiven':           'feed_given',
    'waterGiven':          'water_given',
    'eggsCollected':       'eggs_collected',
    'mortalityCount':      'mortality_count',
    'averageWeight':       'average_weight',
    'healthObservations':  'health_observations',
    'createdAt':           'created_at',
    'updatedAt':           'updated_at',
    'lastModified':        'last_modified',
    'syncStatus':          'sync_status',
    'serverId':            'server_id',
  },
  'stock': {
    'flockId':          'flock_id',
    'itemType':         'item_type',
    'itemName':         'item_name',
    'minThreshold':     'min_threshold',
    'costPerUnit':      'cost_per_unit',
    'supplier':         'supplier',
    'lastRestockDate':  'last_restock_date',
    'expiryDate':       'expiry_date',
    'createdAt':        'created_at',
    'updatedAt':        'updated_at',
    'lastModified':     'last_modified',
    'syncStatus':       'sync_status',
    'serverId':         'server_id',
  },
  'health_events': {
    'flockId':        'flock_id',
    'eventType':      'event_type',
    'affectedBirds':  'affected_birds',
    'photoPath':      'photo_path',
    'createdAt':      'created_at',
    'updatedAt':      'updated_at',
    'lastModified':   'last_modified',
    'syncStatus':     'sync_status',
    'serverId':       'server_id',
  },
};

enum SyncState { idle, syncing, error }

class SyncService extends ChangeNotifier {
  final DatabaseService _db;
  final SupabaseAuthService _auth;
  LicenseProvider? _license;

  SyncService({
    DatabaseService? db,
    SupabaseAuthService? auth,
  })  : _db = db ?? DatabaseService(),
        _auth = auth ?? SupabaseAuthService();

  SupabaseClient get _client => Supabase.instance.client;

  SyncState _state = SyncState.idle;
  String? _lastError;
  DateTime? _lastSyncedAt;
  int _pendingCount = 0;
  bool _disposed = false;

  Timer? _debounceTimer;
  bool _syncInProgress = false;

  static const Duration _debounceInterval = Duration(seconds: 5);

  SyncState get state => _state;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get pendingCount => _pendingCount;
  bool get isSyncing => _state == SyncState.syncing;
  bool get hasError => _state == SyncState.error;
  bool get isHealthy => _state == SyncState.idle && _lastError == null;

  void setLicense(LicenseProvider license) {
    _license = license;
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Call once from main.dart after auth is initialised.
  void startPeriodicSync() {
    debugPrint('SyncService: event-driven sync initialised');
  }

  void stopPeriodicSync() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    stopPeriodicSync();
    super.dispose();
  }

  // ─── Public trigger ────────────────────────────────────────────────────────

  Future<void> syncNow() async {
    if (_syncInProgress) return;
    if (!_auth.isAuthenticated) return;
    final entitlement = _license?.entitlement;
    if (entitlement == null || !FeatureGate.canUseCloud(entitlement)) return;

    _syncInProgress = true;
    _setState(SyncState.syncing);

    try {
      await _processPendingQueue();
      _lastSyncedAt = DateTime.now();
      _lastError = null;
      _setState(SyncState.idle);
    } catch (e, st) {
      _lastError = e.toString();
      debugPrint('SyncService error: $e\n$st');
      _setState(SyncState.error);
    } finally {
      _syncInProgress = false;
      await _refreshPendingCount();
    }
  }

  Future<void> downloadCloudData() async {
    if (_syncInProgress) return;
    final userId = _auth.currentUserId;
    if (userId == null) return;

    _syncInProgress = true;
    _setState(SyncState.syncing);

    try {
      final data = <String, dynamic>{};

      for (final entry in _supabaseTables.entries) {
        final localTable = entry.key;
        final supabaseTable = entry.value;

        final rows = await _client
            .from(supabaseTable)
            .select()
            .eq('user_id', userId);

        final localRows = (rows is List)
            ? rows
                .whereType<Map<String, dynamic>>()
                .map((r) => _toCamelCase(localTable, r))
                .toList()
            : <Map<String, dynamic>>[];

        data[localTable] = localRows;
      }

      await _db.importAllFromJson({
        'version': '4.0',
        'timestamp': DateTime.now().toIso8601String(),
        'appVersion': 'poultry_pro_v4',
        'data': data,
      });

      _lastSyncedAt = DateTime.now();
      _lastError = null;
      _setState(SyncState.idle);
    } catch (e, st) {
      _lastError = e.toString();
      debugPrint('SyncService download error: $e\n$st');
      _setState(SyncState.error);
    } finally {
      _syncInProgress = false;
      await _refreshPendingCount();
    }
  }

  void scheduleSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceInterval, () {
      _debounceTimer = null;
      unawaited(syncNow());
    });
  }

  // ─── Queue processing ──────────────────────────────────────────────────────

  Future<void> _processPendingQueue() async {
    final userId = _auth.currentUserId;
    if (userId == null) return;

    final entries = await _db.getPendingQueueEntries(limit: 100);
    if (entries.isEmpty) return;

    debugPrint('SyncService: processing ${entries.length} queue entries');

    for (final entry in entries) {
      if (_disposed) break;

      final queueId   = entry['id'] as String;
      final tableName = entry['tableName'] as String;
      final operation = entry['operation'] as String;
      final attempts  = (entry['attempts'] as int? ?? 0);
      final payloadJson = entry['payload'] as String;

      try {
        final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
        final supabaseTable = _supabaseTables[tableName];

        if (supabaseTable == null) {
          debugPrint('SyncService: unknown table "$tableName" — skipping');
          await _db.markQueueEntryFailed(
              queueId, 'Unknown table: $tableName', attempts);
          continue;
        }

        final snakePayload = _toSnakeCase(tableName, payload, userId);

        switch (operation) {
          case 'insert':
            await _upsertRecord(supabaseTable, snakePayload);
          case 'update':
            await _upsertRecord(supabaseTable, snakePayload);
          case 'delete':
            await _softDeleteRecord(supabaseTable, snakePayload);
          default:
            debugPrint('SyncService: unknown operation "$operation"');
        }

        await _db.markQueueEntrySuccess(queueId);
        await _db.markRecordSynced(
          table:    tableName,
          id:       payload['id'] as String,
          serverId: payload['id'] as String,
        );
      } catch (e) {
        debugPrint('SyncService: failed entry $queueId — $e');
        await _db.markQueueEntryFailed(queueId, e.toString(), attempts);
      }
    }

    await _db.pruneCompletedQueueEntries();
  }

  // ─── Supabase operations ───────────────────────────────────────────────────

  Future<void> _upsertRecord(
      String table, Map<String, dynamic> payload) async {
    await _client.from(table).upsert(payload);
  }

  Future<void> _softDeleteRecord(
      String table, Map<String, dynamic> payload) async {
    final id = payload['id'] as String?;
    if (id == null) return;
    await _client.from(table).update({'deleted': true}).eq('id', id);
  }

  // ─── Column name translation ───────────────────────────────────────────────

  Map<String, dynamic> _toSnakeCase(
    String table,
    Map<String, dynamic> local,
    String userId,
  ) {
    final columnRenames = _columnMap[table] ?? {};
    final result = <String, dynamic>{'user_id': userId};

    const stripFields = {'syncStatus', 'serverId', 'lastSyncedAt', 'version'};

    for (final entry in local.entries) {
      if (stripFields.contains(entry.key)) continue;
      final supabaseKey = columnRenames[entry.key] ?? entry.key;

      dynamic value = entry.value;
      if (entry.key == 'deleted' && value is int) {
        value = value == 1;
      }

      result[supabaseKey] = value;
    }

    return result;
  }

  Map<String, dynamic> _toCamelCase(
    String table,
    Map<String, dynamic> supabase,
  ) {
    final columnRenames = _columnMap[table] ?? {};
    final reverseRenames = <String, String>{};
    for (final entry in columnRenames.entries) {
      reverseRenames[entry.value] = entry.key;
    }

    final result = <String, dynamic>{};
    for (final entry in supabase.entries) {
      final localKey = reverseRenames[entry.key] ?? entry.key;
      dynamic value = entry.value;
      if (localKey == 'deleted' && value is bool) {
        value = value ? 1 : 0;
      }
      result[localKey] = value;
    }

    return result;
  }

  // ─── Pending count ─────────────────────────────────────────────────────────

  Future<void> _refreshPendingCount() async {
    try {
      final entries = await _db.getPendingQueueEntries(limit: 999);
      _pendingCount = entries.length;
      if (!_disposed) notifyListeners();
    } catch (_) {}
  }

  // ─── State management ──────────────────────────────────────────────────────

  void _setState(SyncState state) {
    _state = state;
    if (!_disposed) notifyListeners();
  }
}
