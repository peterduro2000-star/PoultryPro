import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription_entitlement.dart';
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

  SyncService({
    DatabaseService? db,
    SupabaseAuthService? auth,
  })  : _db = db ?? DatabaseService(),
        _auth = auth ?? SupabaseAuthService();

  SupabaseClient get _client => Supabase.instance.client;

  SyncState _state = SyncState.idle;
  String? _lastError;
  DateTime? _lastSyncedAt;
  DateTime? _lastReconciliationAt;
  int _pendingCount = 0;
  bool _disposed = false;

  /// Last entitlement handed to a lifecycle call. Decouples [SyncService] from
  /// [LicenseProvider]: it is plain input, never imported or read back.
  SubscriptionEntitlement? _entitlement;

  /// Fired once after a reconciliation (push → download → merge) completes so
  /// the app can reload its providers from the freshly merged SQLite store.
  /// Awaited while the mutex is still held, so the reload can never interleave
  /// with a later reconciliation.
  FutureOr<void> Function()? onReconcileComplete;

  Timer? _debounceTimer;
  Timer? _periodicTimer;
  bool _syncInProgress = false;

  /// Guards reconciliation so it only runs once per authenticated user/session.
  String? _reconciledForUserId;

  static const Duration _debounceInterval = Duration(seconds: 5);
  static const Duration _periodicInterval = Duration(minutes: 5);

  SyncState get state => _state;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  DateTime? get lastReconciliationAt => _lastReconciliationAt;
  int get pendingCount => _pendingCount;
  bool get isSyncing => _state == SyncState.syncing;
  bool get hasError => _state == SyncState.error;
  bool get isHealthy => _state == SyncState.idle && _lastError == null;

  bool get isAnonymous => _auth.isAnonymous;

  bool _canUseCloud() =>
      _entitlement != null && FeatureGate.canUseCloud(_entitlement!);

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Drives the full reconciliation pipeline for an authenticated, verified
  /// user. The caller (AuthProvider via LicenseProvider) must load and confirm
  /// the entitlement and pass it here — [SyncService] never reads it itself.
  ///
  ///   1. push any pending local queue
  ///   2. download the cloud snapshot for the user
  ///   3. merge into SQLite (incremental, id-keyed, never wipes/enqueues)
  ///   4. (awaited) notify providers to reload from the merged store
  ///   5. start background sync
  ///
  /// The mutex ([_syncInProgress]) is held for the ENTIRE sequence above —
  /// including the provider reload — so two reconciliations can never interleave
  /// a later merge with an earlier reload. Runs at most once per user id.
  Future<void> onAuthenticated(
    User user, {
    required SubscriptionEntitlement entitlement,
  }) async {
    _entitlement = entitlement;
    final eligible = !user.isAnonymous && FeatureGate.canUseCloud(entitlement);
    if (!eligible) {
      debugPrint('SyncService.onAuthenticated: not eligible (user=${user.id})');
      stopAndClear();
      return;
    }
    if (_reconciledForUserId == user.id) {
      debugPrint('SyncService.onAuthenticated: already reconciled for '
          '${user.id} — skipping');
      startPeriodicSync();
      return;
    }
    if (_syncInProgress) {
      debugPrint('SyncService.onAuthenticated: mutex held by another '
          'reconciliation — skipping');
      return;
    }
    debugPrint('SyncService.onAuthenticated: starting lifecycle for '
        '${user.id}');
    _syncInProgress = true;
    _setState(SyncState.syncing);
    try {
      await _reconcileCore();
      _reconciledForUserId = user.id;
      // Reload providers UNDER the lock so a later reconciliation cannot
      // interleave its merge with this reload.
      await onReconcileComplete?.call();
    } catch (e, st) {
      _lastError = e.toString();
      debugPrint('SyncService.onAuthenticated error: $e\n$st');
      _setState(SyncState.error);
    } finally {
      _syncInProgress = false;
      await _refreshPendingCount();
      startPeriodicSync();
    }
  }

  /// Best-effort flush + teardown on sign-out so no previous-account data
  /// lingers. The caller is responsible for pushing pending changes before
  /// this is invoked; we additionally attempt a final flush when eligible.
  Future<void> onSignOut() async {
    if (_canUseCloud() && !_syncInProgress && _auth.isAuthenticated) {
      unawaited(syncNow());
    }
    stopAndClear();
    _entitlement = null;
    _reconciledForUserId = null;
  }

  /// Completely stops the sync service and clears all of its state.
  /// Called on sign-out so no anonymous/previous-account data lingers.
  void stopAndClear() {
    stopPeriodicSync();
    _syncInProgress = false;
    _state = SyncState.idle;
    _lastError = null;
    _lastSyncedAt = null;
    _lastReconciliationAt = null;
    _pendingCount = 0;
    notifyListeners();
  }

  /// Starts a background periodic reconciliation (push → download → merge) so
  /// changes made on other devices are pulled in without a restart. A realtime
  /// listener can replace this later; the periodic fallback stays as backup.
  void startPeriodicSync() {
    stopPeriodicSync();
    if (!_canUseCloud()) return;
    _periodicTimer = Timer.periodic(_periodicInterval, (_) {
      unawaited(reconcileState());
    });
    debugPrint('SyncService: background sync started');
  }

  void stopPeriodicSync() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    stopPeriodicSync();
    super.dispose();
  }

  // ─── Push-only trigger ─────────────────────────────────────────────────────

  /// Pushes any pending local queue to Supabase. Safe to call any time
  /// (manual "Sync" button, auto-upload, sign-out flush). Does not download.
  Future<void> syncNow() async {
    debugPrint("SYNC user = ${Supabase.instance.client.auth.currentUser?.id}");
    if (_syncInProgress) return;
    // Anonymous users must never use cloud sync.
    if (_auth.isAnonymous) return;
    if (!_auth.isAuthenticated) return;
    if (!_canUseCloud()) return;

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

  // ─── Reconciliation (push → download → merge) ──────────────────────────────

  /// Core reconciliation (push → download → merge). Does NOT manage the mutex;
  /// callers ([reconcileState], [onAuthenticated]) must hold [_syncInProgress]
  /// for the whole critical section so nothing can interleave.
  Future<bool> _reconcileCore() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    // Step 1: push local unsynced changes FIRST (offline-first). Doing this
    // before the download guarantees a newer cloud record can never clobber a
    // local pending edit — the edit is uploaded before we read the snapshot.
    await _processPendingQueue();

    // Step 2: download the full cloud snapshot for this user.
    final data = <String, dynamic>{};
    for (final entry in _supabaseTables.entries) {
      final localTable = entry.key;
      final supabaseTable = entry.value;

      final rows = await _client
          .from(supabaseTable)
          .select()
          .eq('user_id', userId);

      final localRows = rows
          .whereType<Map<String, dynamic>>()
          .map((r) => _toCamelCase(localTable, r))
          .toList();

      data[localTable] = localRows;
    }

    // Step 3: merge intelligently into SQLite (never wipes, never enqueues).
    await _db.mergeCloudSnapshot(data);

    _lastReconciliationAt = DateTime.now();
    _lastError = null;
    _setState(SyncState.idle);
    return true;
  }

  /// Brings local SQLite and the cloud back into agreement for the current
  /// verified user. Runs whenever a verified session becomes active or changes
  /// (boot, OTP verification, sign-in, account switch, reinstall) — NOT on
  /// every JWT refresh. Acquires [_syncInProgress] for the whole push+pull
  /// critical section. Used by the periodic background timer.
  Future<bool> reconcileState() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    if (!_canUseCloud()) return false;

    // Re-read defensively — currentUser can be null during cold start.
    if (Supabase.instance.client.auth.currentUser?.id == null) return false;

    if (_syncInProgress) return false;
    _syncInProgress = true;
    _setState(SyncState.syncing);

    try {
      return await _reconcileCore();
    } catch (e, st) {
      _lastError = e.toString();
      debugPrint('SyncService reconcile error: $e\n$st');
      _setState(SyncState.error);
      return false;
    } finally {
      _syncInProgress = false;
      await _refreshPendingCount();
    }
  }

  void scheduleSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceInterval, () {
      _debounceTimer = null;
      if (_syncInProgress) {
        // Reconciliation owns the mutex. Re-arm so this edit is pushed once
        // the lock is released — the queue entry is already persisted, so the
        // change is never lost and never races the in-flight reconcile.
        scheduleSync();
        return;
      }
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
