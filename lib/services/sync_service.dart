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
  /// Triggers an immediate sync. Subsequent syncs are event-driven
  /// (app resume, manual refresh, or debounced data changes).
  void startPeriodicSync() {
    // No periodic timer — sync is now event-driven.
    debugPrint('SyncService: event-driven sync initialised');
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ─── Public trigger ────────────────────────────────────────────────────────

  /// Triggers a sync cycle immediately. Safe to call multiple times —
  /// concurrent calls are no-ops while a sync is already in progress.
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

  /// Debounced sync trigger. Resets a 5-second timer on each call.
  /// Use this after local data changes so rapid writes only trigger
  /// one sync cycle.
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
          serverId: payload['id'] as String, // same id — we control the PK
        );
      } catch (e) {
        debugPrint('SyncService: failed entry $queueId — $e');
        await _db.markQueueEntryFailed(queueId, e.toString(), attempts);
      }
    }

    // Housekeeping — prune old synced entries weekly
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

  /// Converts a local camelCase payload map to Supabase snake_case,
  /// adds user_id, and strips SQLite-only fields.
  Map<String, dynamic> _toSnakeCase(
    String table,
    Map<String, dynamic> local,
    String userId,
  ) {
    final columnRenames = _columnMap[table] ?? {};
    final result = <String, dynamic>{'user_id': userId};

    // Fields we never send to Supabase
    const stripFields = {'syncStatus', 'serverId', 'lastSyncedAt', 'version'};

    for (final entry in local.entries) {
      if (stripFields.contains(entry.key)) continue;
      final supabaseKey = columnRenames[entry.key] ?? entry.key;

      // Convert SQLite integers back to booleans for Supabase boolean columns
      dynamic value = entry.value;
      if (entry.key == 'deleted' && value is int) {
        value = value == 1;
      }

      result[supabaseKey] = value;
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