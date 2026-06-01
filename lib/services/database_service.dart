// lib/services/database_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../constants/sync_status.dart';
import '../models/daily_record.dart';
import '../models/expense.dart';
import '../models/flock.dart';
import '../models/health_event.dart';
import '../models/sale.dart';
import '../models/stock.dart';

// ─── Custom exception (does NOT shadow sqflite.DatabaseException) ─────────────

class PoultryDbException implements Exception {
  final String message;
  const PoultryDbException(this.message);
  @override
  String toString() => 'PoultryDbException: $message';
}

// ─── Service ──────────────────────────────────────────────────────────────────

class DatabaseService {
  // Singleton
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static sqflite.Database? _database;

  // Bump this whenever _createTables or _onUpgrade changes.
  static const int _version = 9;
  static const String _dbName = 'poultry_pro_v4.db';

  // Prevents infinite recovery loops.
  static bool _recoveryAlreadyAttempted = false;

  // ─── Table registry ─────────────────────────────────────────────────────────

  /// Business-data tables. Used for export, import, and clear operations.
  static const Set<String> allowedTables = {
    'flocks',
    'expenses',
    'sales',
    'daily_records',
    'stock',
    'health_events',
  };

  /// All internal tables (business + infrastructure).
  static const Set<String> _allInternalTables = {
    ...allowedTables,
    'sync_queue',
    'sync_locks',
    'sync_logs',
    'meta',
  };

  /// Whitelist guard — prevents arbitrary table access from providers.
  void validateTable(String table) {
    if (!_allInternalTables.contains(table)) {
      throw ArgumentError('Invalid table access: "$table". '
          'Allowed tables: ${_allInternalTables.join(', ')}');
    }
  }

  // ─── Child-table map ────────────────────────────────────────────────────────

  /// Maps each parent table to its child tables that carry a flockId FK.
  /// Used by [deleteSoftTransactional] cascade logic.
  static const Map<String, List<String>> _childTables = {
    'flocks': [
      'expenses',
      'sales',
      'daily_records',
      'stock',
      'health_events',
    ],
  };

  /// Column name used to reference the parent in each child table.
  static const Map<String, String> _parentFkColumn = {
    'expenses':      'flockId',
    'sales':         'flockId',
    'daily_records': 'flockId',
    'stock':         'flockId',
    'health_events': 'flockId',
  };

  // ─── Database access ────────────────────────────────────────────────────────

  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initializeDatabase();
    return _database!;
  }

  Future<sqflite.Database> _initializeDatabase() async {
    final dbPath = await sqflite.getDatabasesPath();
    final path = join(dbPath, _dbName);
    try {
      return await sqflite.openDatabase(
        path,
        version: _version,
        onCreate: _createTables,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
        onOpen: _onOpen,
      );
    } catch (e) {
      debugPrint('CRITICAL: Database initialisation crashed: $e');
      return _handleDatabaseRecovery(path);
    }
  }

  Future<void> initialize() async => await database;

  // ─── PRAGMA configuration ───────────────────────────────────────────────────

  Future<void> _onConfigure(sqflite.Database db) async {
    // Foreign keys must be set in onConfigure
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Runs after the database is fully open
  // WAL and other PRAGMAs must NOT go in onConfigure on Android —
  // they must be set after the DB is open, in onOpen instead.
  Future<void> _onOpen(sqflite.Database db) async {
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA temp_store = MEMORY');
    await db.execute('PRAGMA busy_timeout = 8000');
  }

  // ─── Timestamp helper ───────────────────────────────────────────────────────

  String nowIso() => DateTime.now().toUtc().toIso8601String();

  // ─── DDL: Create tables ─────────────────────────────────────────────────────

  Future<void> _createTables(sqflite.Database db, int version) async {
    // Infrastructure tables
    await db.execute(
        'CREATE TABLE sync_locks (id TEXT PRIMARY KEY, lockedAt TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE sync_logs ('
        '  id TEXT PRIMARY KEY,'
        '  tableName TEXT NOT NULL,'
        '  operation TEXT NOT NULL,'
        '  status TEXT NOT NULL,'
        '  error TEXT,'
        '  createdAt TEXT NOT NULL'
        ')');
    await db.execute(
        'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
    await db.execute('''
      CREATE TABLE sync_queue (
        id          TEXT PRIMARY KEY,
        tableName   TEXT NOT NULL,
        recordId    TEXT NOT NULL,
        operation   TEXT NOT NULL,
        payload     TEXT NOT NULL,
        status      TEXT NOT NULL DEFAULT 'pending',
        priority    INTEGER DEFAULT 0,
        attempts    INTEGER DEFAULT 0,
        nextRetryAt TEXT NOT NULL,
        lastSyncedAt TEXT,
        lastError   TEXT,
        createdAt   TEXT NOT NULL
      )
    ''');

    // Business tables
    await db.execute('''
      CREATE TABLE flocks (
        id               TEXT PRIMARY KEY,
        name             TEXT NOT NULL,
        type             TEXT NOT NULL,
        birdCount        INTEGER NOT NULL,
        initialBirdCount INTEGER NOT NULL DEFAULT 0,
        costPerBird      REAL NOT NULL,
        startDate        TEXT NOT NULL,
        status           TEXT NOT NULL,
        ageAtStocking    INTEGER DEFAULT 0,
        breed            TEXT,
        source           TEXT,
        housingType      TEXT,
        notes            TEXT,
        createdAt        TEXT NOT NULL,
        updatedAt        TEXT NOT NULL,
        lastModified     TEXT,
        lastSyncedAt     TEXT,
        syncStatus       TEXT DEFAULT 'local',
        serverId         TEXT,
        deleted          INTEGER DEFAULT 0,
        version          INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id            TEXT PRIMARY KEY,
        flockId       TEXT NOT NULL,
        category      TEXT NOT NULL,
        description   TEXT NOT NULL,
        amount        REAL NOT NULL,
        date          TEXT NOT NULL,
        paymentMethod TEXT,
        notes         TEXT,
        createdAt     TEXT NOT NULL,
        updatedAt     TEXT NOT NULL,
        lastModified  TEXT,
        lastSyncedAt  TEXT,
        syncStatus    TEXT DEFAULT 'local',
        serverId      TEXT,
        deleted       INTEGER DEFAULT 0,
        version       INTEGER DEFAULT 1,
        FOREIGN KEY (flockId) REFERENCES flocks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id            TEXT PRIMARY KEY,
        flockId       TEXT NOT NULL,
        saleType      TEXT NOT NULL,
        quantity      REAL NOT NULL,
        unit          TEXT NOT NULL,
        pricePerUnit  REAL NOT NULL,
        totalAmount   REAL NOT NULL,
        date          TEXT NOT NULL,
        buyerName     TEXT,
        paymentMethod TEXT,
        notes         TEXT,
        createdAt     TEXT NOT NULL,
        updatedAt     TEXT NOT NULL,
        lastModified  TEXT,
        lastSyncedAt  TEXT,
        syncStatus    TEXT DEFAULT 'local',
        serverId      TEXT,
        deleted       INTEGER DEFAULT 0,
        version       INTEGER DEFAULT 1,
        FOREIGN KEY (flockId) REFERENCES flocks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_records (
        id                 TEXT PRIMARY KEY,
        flockId            TEXT NOT NULL,
        date               TEXT NOT NULL,
        feedGiven          REAL,
        waterGiven         REAL,
        eggsCollected      INTEGER,
        mortalityCount     INTEGER,
        averageWeight      REAL,
        healthObservations TEXT,
        notes              TEXT,
        createdAt          TEXT NOT NULL,
        updatedAt          TEXT NOT NULL,
        lastModified       TEXT,
        lastSyncedAt       TEXT,
        syncStatus         TEXT DEFAULT 'local',
        serverId           TEXT,
        deleted            INTEGER DEFAULT 0,
        version            INTEGER DEFAULT 1,
        FOREIGN KEY (flockId) REFERENCES flocks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE stock (
        id              TEXT PRIMARY KEY,
        flockId         TEXT NOT NULL,
        itemType        TEXT NOT NULL,
        itemName        TEXT NOT NULL,
        quantity        REAL NOT NULL,
        unit            TEXT NOT NULL,
        minThreshold    REAL NOT NULL,
        costPerUnit     REAL NOT NULL,
        supplier        TEXT,
        lastRestockDate TEXT,
        expiryDate      TEXT,
        createdAt       TEXT NOT NULL,
        updatedAt       TEXT NOT NULL,
        lastModified    TEXT,
        lastSyncedAt    TEXT,
        syncStatus      TEXT DEFAULT 'local',
        serverId        TEXT,
        deleted         INTEGER DEFAULT 0,
        version         INTEGER DEFAULT 1,
        FOREIGN KEY (flockId) REFERENCES flocks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE health_events (
        id           TEXT PRIMARY KEY,
        flockId      TEXT NOT NULL,
        date         TEXT NOT NULL,
        eventType    TEXT NOT NULL,
        description  TEXT NOT NULL,
        severity     TEXT,
        affectedBirds INTEGER,
        medicine     TEXT,
        dosage       TEXT,
        photoPath    TEXT,
        notes        TEXT,
        createdAt    TEXT NOT NULL,
        updatedAt    TEXT NOT NULL,
        lastModified TEXT,
        lastSyncedAt TEXT,
        syncStatus   TEXT DEFAULT 'local',
        serverId     TEXT,
        deleted      INTEGER DEFAULT 0,
        version      INTEGER DEFAULT 1,
        FOREIGN KEY (flockId) REFERENCES flocks(id) ON DELETE CASCADE
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _createIndexes(sqflite.Database db) async {
    // Sync queue lookup — most frequent SyncService query
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_queue_lookup '
        'ON sync_queue(status, nextRetryAt, priority DESC)');

    // Business table sync status — SyncService pending-record scan
    for (final table in allowedTables) {
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_${table}_sync_status '
          'ON $table(syncStatus)');
      // Prevents duplicate Supabase rows being pulled in as separate local rows
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_${table}_server_identity '
          'ON $table(serverId) WHERE serverId IS NOT NULL');
    }

    // Common query patterns
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_flocks_startDate '
        'ON flocks(startDate)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_daily_records_flock_date '
        'ON daily_records(flockId, date DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_flock_date '
        'ON expenses(flockId, date DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_flock_date '
        'ON sales(flockId, date DESC)');

    // Prevents two non-deleted daily records for same flock on same date
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_daily_record '
        'ON daily_records(flockId, date) WHERE deleted = 0');
  }

  // ─── DDL: Migrations ────────────────────────────────────────────────────────

  Future<void> _onUpgrade(
      sqflite.Database db, int oldVersion, int newVersion) async {

    // ── v6: 'medicine' → 'medication' category rename ─────────────────────────
    // The Expense.fromMap normalise() call fixes rows at read time (fallback).
    // This UPDATE fixes them permanently at the DB level so raw SQL GROUP BY
    // queries (e.g. finance reports) also return the correct category string.
    if (oldVersion < 6) {
      await db.execute('''
        UPDATE expenses
        SET category = 'medication'
        WHERE LOWER(TRIM(category)) = 'medicine'
      ''');
      debugPrint('DB migration v6: renamed medicine → medication in expenses');
    }

    // ── v7: nothing (reserved for future use) ──────────────────────────────────

    // ── v8: nothing (reserved for future use) ──────────────────────────────────

    // ── v9: sync infrastructure + version column ──────────────────────────────
    if (oldVersion < 9) {
      // Infrastructure tables
      await db.execute(
          'CREATE TABLE IF NOT EXISTS sync_locks '
          '(id TEXT PRIMARY KEY, lockedAt TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS sync_logs ('
          '  id TEXT PRIMARY KEY,'
          '  tableName TEXT NOT NULL,'
          '  operation TEXT NOT NULL,'
          '  status TEXT NOT NULL,'
          '  error TEXT,'
          '  createdAt TEXT NOT NULL'
          ')');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id           TEXT PRIMARY KEY,
          tableName    TEXT NOT NULL,
          recordId     TEXT NOT NULL,
          operation    TEXT NOT NULL,
          payload      TEXT NOT NULL,
          status       TEXT NOT NULL DEFAULT 'pending',
          priority     INTEGER DEFAULT 0,
          attempts     INTEGER DEFAULT 0,
          nextRetryAt  TEXT NOT NULL,
          lastSyncedAt TEXT,
          lastError    TEXT,
          createdAt    TEXT NOT NULL
        )
      ''');

      // Add new columns to existing business tables
      for (final table in allowedTables) {
        await _addColumnIfNotExists(db, table, 'lastSyncedAt', 'TEXT');
        await _addColumnIfNotExists(db, table, 'version', 'INTEGER DEFAULT 1');
      }

      // Back-fill version = 1 for all existing rows
      for (final table in allowedTables) {
        await db.execute(
            'UPDATE $table SET version = 1 WHERE version IS NULL');
      }

      await _createIndexes(db);
      debugPrint('DB migration v9: sync infrastructure added');
    }
  }

  Future<void> _addColumnIfNotExists(
      sqflite.Database db, String table, String column, String type) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    } on sqflite.DatabaseException catch (e) {
      // sqflite.DatabaseException — not our custom PoultryDbException
      if (!e.toString().contains('duplicate column name')) rethrow;
    }
  }

  // ─── Recovery ───────────────────────────────────────────────────────────────

  Future<sqflite.Database> _handleDatabaseRecovery(String dbPath) async {
    if (_recoveryAlreadyAttempted) {
      throw StateError(
          'CRITICAL: Recursive database recovery loop detected. '
          'Manual intervention required.');
    }
    _recoveryAlreadyAttempted = true;

    try {
      // Track recovery attempts in a separate manifest DB to detect loops
      // across app restarts (not just within a single session).
      final recoveryDb = await sqflite.openDatabase(
          join(dirname(dbPath), 'recovery_manifest.db'));
      await recoveryDb.execute(
          'CREATE TABLE IF NOT EXISTS flags (key TEXT PRIMARY KEY, value TEXT)');

      final history = await recoveryDb.query('flags',
          where: 'key = ?', whereArgs: ['err_v$_version']);
      if (history.isNotEmpty) {
        await recoveryDb.close();
        throw StateError(
            'CRITICAL: Auto-recovery threshold exceeded for schema v$_version. '
            'The database may be corrupt.');
      }

      await recoveryDb.insert(
        'flags',
        {'key': 'err_v$_version', 'value': nowIso()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await recoveryDb.close();
    } catch (e) {
      debugPrint('Recovery manifest write failed (non-fatal): $e');
    }

    debugPrint('Attempting database recovery for schema v$_version...');
    return sqflite.openDatabase(
      dbPath,
      version: _version,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ATOMIC OUTBOX TRANSACTION WRAPPERS
  // Every write (insert / update / soft-delete) is paired with a sync_queue
  // entry in a single SQLite transaction. Either both succeed or neither
  // does — guaranteeing the outbox is never out of sync with business data.
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> insertTransactional({
    required String table,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    validateTable(table);
    final db = await database;
    final now = nowIso();

    final payload = Map<String, dynamic>.from(data);
    payload['id']           = id;
    payload['syncStatus']   = SyncStatus.pending;
    payload['createdAt']    = now;
    payload['updatedAt']    = now;
    payload['lastModified'] = now;
    payload.putIfAbsent('version', () => 1);
    payload.putIfAbsent('deleted', () => 0);

    await db.transaction((txn) async {
      await txn.insert(table, payload,
          conflictAlgorithm: ConflictAlgorithm.fail);

      await txn.insert(
        'sync_queue',
        _buildQueueEntry(
          table:     table,
          id:        id,
          operation: 'insert',
          payload:   payload,
          now:       now,
        ),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> updateTransactional({
    required String table,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    validateTable(table);
    final db = await database;
    final now = nowIso();

    await db.transaction((txn) async {
      final existing = await txn.query(table,
          where: 'id = ?', whereArgs: [id], limit: 1);
      if (existing.isEmpty) {
        throw PoultryDbException(
            'Cannot update: record "$id" not found in "$table".');
      }

      final currentVersion =
          int.tryParse(existing.first['version']?.toString() ?? '1') ?? 1;

      final payload = Map<String, dynamic>.from(data);
      payload['updatedAt']    = now;
      payload['lastModified'] = now;
      payload['syncStatus']   = SyncStatus.pending;
      payload['version']      = currentVersion + 1;

      await txn.update(table, payload,
          where: 'id = ?', whereArgs: [id]);

      // Read the fully merged row to store in the queue payload
      final updated = await txn.query(table,
          where: 'id = ?', whereArgs: [id], limit: 1);

      await txn.insert(
        'sync_queue',
        _buildQueueEntry(
          table:     table,
          id:        id,
          operation: 'update',
          payload:   updated.first,
          now:       now,
        ),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Soft-deletes [id] in [table] and optionally cascades to child tables.
  /// Each soft-deleted row (parent and children) gets its own sync_queue
  /// tombstone so the SyncService can push all deletions to Supabase.
  Future<void> deleteSoftTransactional({
    required String table,
    required String id,
  }) async {
    validateTable(table);
    final db = await database;
    final now = nowIso();

    await db.transaction((txn) async {
      // ── 1. Soft-delete the parent row ──────────────────────────────────────
      final existing = await txn.query(table,
          where: 'id = ?', whereArgs: [id], limit: 1);
      if (existing.isEmpty) return; // Already gone — idempotent

      final currentVersion =
          int.tryParse(existing.first['version']?.toString() ?? '1') ?? 1;

      final parentPatch = {
        'deleted':      1,
        'syncStatus':   SyncStatus.pending,
        'updatedAt':    now,
        'lastModified': now,
        'version':      currentVersion + 1,
      };

      await txn.update(table, parentPatch,
          where: 'id = ? AND deleted = 0', whereArgs: [id]);

      final updatedParent = await txn.query(table,
          where: 'id = ?', whereArgs: [id], limit: 1);

      await txn.insert(
        'sync_queue',
        _buildQueueEntry(
          table:     table,
          id:        id,
          operation: 'delete',
          payload:   updatedParent.first,
          now:       now,
          // Deletes get highest priority so Supabase tombstones land first
          priority:  2,
        ),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // ── 2. Cascade soft-delete to children ────────────────────────────────
      final children = _childTables[table] ?? [];
      for (final childTable in children) {
        final fkColumn = _parentFkColumn[childTable]!;

        // Fetch all non-deleted children of this parent
        final childRows = await txn.query(
          childTable,
          where: '$fkColumn = ? AND deleted = 0',
          whereArgs: [id],
        );

        for (final child in childRows) {
          final childId = child['id'] as String;
          final childVersion =
              int.tryParse(child['version']?.toString() ?? '1') ?? 1;

          final childPatch = {
            'deleted':      1,
            'syncStatus':   SyncStatus.pending,
            'updatedAt':    now,
            'lastModified': now,
            'version':      childVersion + 1,
          };

          await txn.update(childTable, childPatch,
              where: 'id = ? AND deleted = 0', whereArgs: [childId]);

          final updatedChild = await txn.query(childTable,
              where: 'id = ?', whereArgs: [childId], limit: 1);

          await txn.insert(
            'sync_queue',
            _buildQueueEntry(
              table:     childTable,
              id:        childId,
              operation: 'delete',
              payload:   updatedChild.first,
              now:       now,
              priority:  2,
            ),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  // ─── Queue entry builder ────────────────────────────────────────────────────

  Map<String, dynamic> _buildQueueEntry({
    required String table,
    required String id,
    required String operation,
    required Map<String, dynamic> payload,
    required String now,
    int priority = 0,
  }) {
    // Flocks are priority 1 (other tables depend on them existing first)
    final effectivePriority = table == 'flocks' && operation != 'delete'
        ? 1
        : priority;

    return {
      'id':          'q_${DateTime.now().microsecondsSinceEpoch}_$id',
      'tableName':   table,
      'recordId':    id,
      'operation':   operation,
      'payload':     jsonEncode(payload),
      'status':      'pending',
      'priority':    effectivePriority,
      'attempts':    0,
      'nextRetryAt': now,
      'createdAt':   now,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TYPED READ METHODS
  // Reads do not go through the transactional wrappers — they are
  // plain queries since reads never need to be synced.
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> _queryActive(
    String table, {
    String? extraWhere,
    List<dynamic>? extraArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    final where = extraWhere != null
        ? '(deleted = 0 OR deleted IS NULL) AND ($extraWhere)'
        : '(deleted = 0 OR deleted IS NULL)';
    final args = extraArgs;
    return db.query(table,
        where: where, whereArgs: args, orderBy: orderBy, limit: limit);
  }

  // ─── Flocks ─────────────────────────────────────────────────────────────────

  Future<List<Flock>> getAllFlocks() async {
    final rows = await _queryActive('flocks', orderBy: 'name ASC');
    return rows.map(Flock.fromMap).toList();
  }

  Future<Flock?> getFlockById(String flockId) async {
    final rows = await _queryActive('flocks',
        extraWhere: 'id = ?', extraArgs: [flockId], limit: 1);
    return rows.isEmpty ? null : Flock.fromMap(rows.first);
  }

  Future<void> createFlock(Flock flock) async {
    await insertTransactional(
      table: 'flocks',
      id:    flock.id,
      data:  flock.toMap(),
    );
  }

  Future<void> updateFlock(Flock flock) async {
    await updateTransactional(
      table: 'flocks',
      id:    flock.id,
      data:  flock.toMap(),
    );
  }

  /// Soft-deletes the flock AND all its child records (expenses, sales,
  /// daily_records, stock, health_events) atomically.
  /// Each record gets its own sync_queue tombstone.
  Future<void> deleteFlock(String flockId) async {
    await deleteSoftTransactional(table: 'flocks', id: flockId);
  }

  // ─── Expenses ────────────────────────────────────────────────────────────────

  Future<List<Expense>> getExpensesByFlock(String flockId) async {
    final rows = await _queryActive('expenses',
        extraWhere: 'flockId = ?',
        extraArgs:  [flockId],
        orderBy:    'date DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getAllExpenses() async {
    final rows = await _queryActive('expenses', orderBy: 'date DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<void> createExpense(Expense expense) async {
    await insertTransactional(
      table: 'expenses',
      id:    expense.id,
      data:  expense.toMap(),
    );
  }

  Future<void> updateExpense(Expense expense) async {
    await updateTransactional(
      table: 'expenses',
      id:    expense.id,
      data:  expense.toMap(),
    );
  }

  Future<void> deleteExpense(String id) async {
    await deleteSoftTransactional(table: 'expenses', id: id);
  }

  // ─── Sales ───────────────────────────────────────────────────────────────────

  Future<List<Sale>> getSalesByFlock(String flockId) async {
    final rows = await _queryActive('sales',
        extraWhere: 'flockId = ?',
        extraArgs:  [flockId],
        orderBy:    'date DESC');
    return rows.map(Sale.fromMap).toList();
  }

  Future<List<Sale>> getAllSales() async {
    final rows = await _queryActive('sales', orderBy: 'date DESC');
    return rows.map(Sale.fromMap).toList();
  }

  Future<void> createSale(Sale sale) async {
    await insertTransactional(
      table: 'sales',
      id:    sale.id,
      data:  sale.toMap(),
    );
  }

  Future<void> updateSale(Sale sale) async {
    await updateTransactional(
      table: 'sales',
      id:    sale.id,
      data:  sale.toMap(),
    );
  }

  Future<void> deleteSale(String id) async {
    await deleteSoftTransactional(table: 'sales', id: id);
  }

  // ─── Daily Records ───────────────────────────────────────────────────────────

  Future<List<DailyRecord>> getDailyRecordsByFlock(String flockId) async {
    final rows = await _queryActive('daily_records',
        extraWhere: 'flockId = ?',
        extraArgs:  [flockId],
        orderBy:    'date DESC');
    return rows.map(DailyRecord.fromMap).toList();
  }

  Future<DailyRecord?> getLatestRecordByFlock(String flockId) async {
    final rows = await _queryActive('daily_records',
        extraWhere: 'flockId = ?',
        extraArgs:  [flockId],
        orderBy:    'date DESC',
        limit:      1);
    return rows.isEmpty ? null : DailyRecord.fromMap(rows.first);
  }

  Future<int> getTotalMortalityByFlock(String flockId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(mortalityCount), 0) AS total
      FROM daily_records
      WHERE flockId = ?
        AND (deleted = 0 OR deleted IS NULL)
    ''', [flockId]);
    return (rows.first['total'] as num).toInt();
  }

  Future<void> createDailyRecord(DailyRecord record) async {
    await insertTransactional(
      table: 'daily_records',
      id:    record.id,
      data:  record.toMap(),
    );
  }

  Future<void> updateDailyRecord(DailyRecord record) async {
    await updateTransactional(
      table: 'daily_records',
      id:    record.id,
      data:  record.toMap(),
    );
  }

  Future<void> deleteDailyRecord(String id) async {
    await deleteSoftTransactional(table: 'daily_records', id: id);
  }

  // ─── Stock ───────────────────────────────────────────────────────────────────

  Future<List<Stock>> getStockByFlock(String flockId) async {
    final rows = await _queryActive('stock',
        extraWhere: 'flockId = ?', extraArgs: [flockId]);
    return rows.map(Stock.fromMap).toList();
  }

  Future<List<Stock>> getLowStockAlerts(String flockId) async {
    final rows = await _queryActive('stock',
        extraWhere: 'flockId = ? AND quantity <= minThreshold',
        extraArgs:  [flockId]);
    return rows.map(Stock.fromMap).toList();
  }

  Future<void> createStock(Stock stock) async {
    await insertTransactional(
      table: 'stock',
      id:    stock.id,
      data:  stock.toMap(),
    );
  }

  Future<void> updateStock(Stock stock) async {
    await updateTransactional(
      table: 'stock',
      id:    stock.id,
      data:  stock.toMap(),
    );
  }

  Future<void> deleteStock(String id) async {
    await deleteSoftTransactional(table: 'stock', id: id);
  }

  // ─── Health Events ───────────────────────────────────────────────────────────

  Future<List<HealthEvent>> getHealthEventsByFlock(String flockId) async {
    final rows = await _queryActive('health_events',
        extraWhere: 'flockId = ?',
        extraArgs:  [flockId],
        orderBy:    'date DESC');
    return rows.map(HealthEvent.fromMap).toList();
  }

  Future<void> createHealthEvent(HealthEvent event) async {
    await insertTransactional(
      table: 'health_events',
      id:    event.id,
      data:  event.toMap(),
    );
  }

  Future<void> updateHealthEvent(HealthEvent event) async {
    await updateTransactional(
      table: 'health_events',
      id:    event.id,
      data:  event.toMap(),
    );
  }

  Future<void> deleteHealthEvent(String id) async {
    await deleteSoftTransactional(table: 'health_events', id: id);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SYNC QUEUE ACCESS
  // Used exclusively by SyncService — providers never call these directly.
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns pending queue entries ordered by priority DESC, then age ASC.
  Future<List<Map<String, dynamic>>> getPendingQueueEntries({
    int limit = 50,
  }) async {
    final db = await database;
    return db.query(
      'sync_queue',
      where:   'status = ?',
      whereArgs: ['pending'],
      orderBy: 'priority DESC, nextRetryAt ASC',
      limit:   limit,
    );
  }

  /// Marks a queue entry as successfully synced.
  Future<void> markQueueEntrySuccess(String queueId) async {
    final db = await database;
    final now = nowIso();
    await db.update(
      'sync_queue',
      {'status': 'synced', 'lastSyncedAt': now},
      where:     'id = ?',
      whereArgs: [queueId],
    );
  }

  /// Marks a queue entry as failed and schedules its next retry
  /// using exponential back-off: 2^attempts minutes, capped at 60 min.
  Future<void> markQueueEntryFailed(
      String queueId, String error, int attempts) async {
    final db = await database;
    final backoffMinutes = (1 << attempts).clamp(1, 60); // 1,2,4,8,…,60
    final nextRetry = DateTime.now()
        .toUtc()
        .add(Duration(minutes: backoffMinutes))
        .toIso8601String();

    await db.update(
      'sync_queue',
      {
        'status':      'failed',
        'lastError':   error,
        'attempts':    attempts + 1,
        'nextRetryAt': nextRetry,
      },
      where:     'id = ?',
      whereArgs: [queueId],
    );
  }

  /// Resets a failed entry back to pending so the SyncService retries it.
  Future<void> requeueEntry(String queueId) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'status': 'pending', 'nextRetryAt': nowIso()},
      where:     'id = ?',
      whereArgs: [queueId],
    );
  }

  /// Marks a business record as successfully synced and records the server id.
  Future<void> markRecordSynced({
    required String table,
    required String id,
    required String serverId,
  }) async {
    validateTable(table);
    final db = await database;
    final now = nowIso();
    await db.update(
      table,
      {
        'syncStatus':   SyncStatus.synced,
        'serverId':     serverId,
        'lastSyncedAt': now,
      },
      where:     'id = ?',
      whereArgs: [id],
    );
  }

  /// Cleans up successfully synced queue entries older than [olderThan].
  Future<void> pruneCompletedQueueEntries({
    Duration olderThan = const Duration(days: 7),
  }) async {
    final db = await database;
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(olderThan)
        .toIso8601String();
    await db.delete(
      'sync_queue',
      where:     'status = ? AND createdAt < ?',
      whereArgs: ['synced', cutoff],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPORT / IMPORT
  // ══════════════════════════════════════════════════════════════════════════

  /// Exports all non-deleted business data to a JSON-serialisable map.
  Future<Map<String, dynamic>> exportAllToJson() async {
    final db = await database;
    try {
      final data = <String, dynamic>{};
      for (final table in allowedTables) {
        data[table] = await db.query(
          table,
          where: 'deleted = 0 OR deleted IS NULL',
        );
      }
      return {
        'version':    '4.0',
        'timestamp':  DateTime.now().toIso8601String(),
        'appVersion': 'poultry_pro_v4',
        'data':       data,
      };
    } catch (e) {
      debugPrint('Export error: $e');
      rethrow;
    }
  }

  /// Imports data from a previously exported JSON.
  /// DESTRUCTIVE — clears all existing business data first.
  /// Always confirm with the user before calling.
  Future<void> importAllFromJson(Map<String, dynamic> jsonData) async {
    final db = await database;
    final importedData = jsonData['data'] as Map<String, dynamic>?;

    if (importedData == null) {
      throw const PoultryDbException('Invalid import data: missing "data" key.');
    }

    try {
      await db.transaction((txn) async {
        // Clear in child-first order to respect FK constraints
        for (final table in allowedTables.toList().reversed) {
          await txn.delete(table, where: '1=1');
        }

        // Re-insert table by table in parent-first order
        for (final table in allowedTables) {
          final records = importedData[table] as List<dynamic>? ?? [];
          for (final record in records) {
            final row = Map<String, dynamic>.from(record as Map);
            // Normalise sync state on import — treat as pending until synced
            row['syncStatus']   = SyncStatus.pending;
            row['lastModified'] = nowIso();
            row['updatedAt']    = nowIso();
            row.putIfAbsent('version', () => 1);
            row.remove('sync_queue_id');

            await txn.insert(table, row,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });
      debugPrint('Import successful');
    } catch (e) {
      debugPrint('Import error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY
  // ══════════════════════════════════════════════════════════════════════════

  /// Hard-wipes all business data. Does NOT touch sync infrastructure tables.
  /// Used for "Clear all data" in settings — always confirm with user first.
  Future<void> clearAllData() async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        for (final table in allowedTables.toList().reversed) {
          await txn.delete(table, where: '1=1');
        }
      });
      debugPrint('All business data cleared');
    } catch (e) {
      debugPrint('Clear error: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _database = null;
  }
}