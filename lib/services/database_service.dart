import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

import '../models/flock.dart';
import '../models/expense.dart';
import '../models/sale.dart';
import '../models/daily_record.dart';
import '../models/stock.dart';
import '../models/health_event.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static const int _version = 6;
  static const String _dbName = 'poultry_pro_v3.db';

  // ─── Core ──────────────────────────────────────────────────────────────────

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return await openDatabase(
      path,
      version: _version,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future initialize() async => await database;

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  // ─── Create Tables ─────────────────────────────────────────────────────────

  Future _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE flocks (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        birdCount INTEGER NOT NULL,
        initialBirdCount INTEGER NOT NULL DEFAULT 0,
        costPerBird REAL NOT NULL,
        startDate TEXT NOT NULL,
        status TEXT NOT NULL,
        ageAtStocking INTEGER DEFAULT 0,
        breed TEXT,
        source TEXT,
        housingType TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        lastModified TEXT,
        syncStatus TEXT DEFAULT 'local',
        serverId TEXT,
        userId TEXT,
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        flockId TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        paymentMethod TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        lastModified TEXT,
        syncStatus TEXT DEFAULT 'local',
        serverId TEXT,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (flockId) REFERENCES flocks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        flockId TEXT NOT NULL,
        saleType TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        pricePerUnit REAL NOT NULL,
        totalAmount REAL NOT NULL,
        date TEXT NOT NULL,
        buyerName TEXT,
        paymentMethod TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        lastModified TEXT,
        syncStatus TEXT DEFAULT 'local',
        serverId TEXT,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (flockId) REFERENCES flocks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_records (
        id TEXT PRIMARY KEY,
        flockId TEXT NOT NULL,
        date TEXT NOT NULL,
        feedGiven REAL,
        waterGiven REAL,
        eggsCollected INTEGER,
        mortalityCount INTEGER,
        averageWeight REAL,
        healthObservations TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        lastModified TEXT,
        syncStatus TEXT DEFAULT 'local',
        serverId TEXT,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (flockId) REFERENCES flocks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE stock (
        id TEXT PRIMARY KEY,
        flockId TEXT NOT NULL,
        itemType TEXT NOT NULL,
        itemName TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        minThreshold REAL NOT NULL,
        costPerUnit REAL NOT NULL,
        supplier TEXT,
        lastRestockDate TEXT,
        expiryDate TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        lastModified TEXT,
        syncStatus TEXT DEFAULT 'local',
        serverId TEXT,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (flockId) REFERENCES flocks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE health_events (
        id TEXT PRIMARY KEY,
        flockId TEXT NOT NULL,
        date TEXT NOT NULL,
        eventType TEXT NOT NULL,
        description TEXT NOT NULL,
        severity TEXT,
        affectedBirds INTEGER,
        medicine TEXT,
        dosage TEXT,
        photoPath TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        lastModified TEXT,
        syncStatus TEXT DEFAULT 'local',
        serverId TEXT,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (flockId) REFERENCES flocks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_flocks_startDate ON flocks(startDate)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_daily_records_flock_date ON daily_records(flockId, date DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_daily_records_date ON daily_records(date)');
  }

  // ─── Migrations ────────────────────────────────────────────────────────────

  Future<void> _addColumnIfNotExists(
      Database db, String table, String column, String type) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    } on DatabaseException catch (e) {
      if (e.toString().contains('duplicate column name')) {
        // Already exists — safe to ignore
      } else {
        rethrow;
      }
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfNotExists(db, 'flocks', 'breed', 'TEXT');
      await _addColumnIfNotExists(db, 'flocks', 'source', 'TEXT');
      await _addColumnIfNotExists(db, 'flocks', 'housingType', 'TEXT');
      await _addColumnIfNotExists(db, 'daily_records', 'averageWeight', 'REAL');
      await _addColumnIfNotExists(db, 'health_events', 'photoPath', 'TEXT');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_flocks_startDate ON flocks(startDate)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_daily_records_flock_date ON daily_records(flockId, date DESC)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_daily_records_date ON daily_records(date)');
    }

    if (oldVersion < 3) {
      await _addColumnIfNotExists(
          db, 'flocks', 'ageAtStocking', 'INTEGER DEFAULT 0');
    }

    if (oldVersion < 4) {
      final tables = [
        'flocks',
        'expenses',
        'sales',
        'daily_records',
        'stock',
        'health_events',
      ];
      for (final table in tables) {
        await _addColumnIfNotExists(db, table, 'lastModified', 'TEXT');
        await _addColumnIfNotExists(
            db, table, 'syncStatus', 'TEXT DEFAULT "local"');
        await _addColumnIfNotExists(db, table, 'serverId', 'TEXT');
        await _addColumnIfNotExists(db, table, 'deleted', 'INTEGER DEFAULT 0');
      }
    }

    if (oldVersion < 5) {
      await _addColumnIfNotExists(
          db, 'flocks', 'initialBirdCount', 'INTEGER DEFAULT 0');
      await db.execute('''
        UPDATE flocks
        SET initialBirdCount = birdCount
        WHERE initialBirdCount = 0 OR initialBirdCount IS NULL
      ''');
    }

    if (oldVersion < 6) {
      await _addColumnIfNotExists(db, 'flocks', 'userId', 'TEXT');
    }
  }

  // ─── Flocks ────────────────────────────────────────────────────────────────

  Future<List<Flock>> getAllFlocks() async {
    final db = await database;
    final rows = await db.query('flocks',
        where: 'deleted = 0 OR deleted IS NULL', orderBy: 'name ASC');
    return rows.map(Flock.fromMap).toList();
  }

  Future createFlock(Flock flock) async {
    final db = await database;
    final now = _nowIso();
    final data = flock.copyWith(
      createdAt: now,
      updatedAt: now,
      lastModified: now,
      syncStatus: 'pending',
    );
    await db.insert('flocks', data.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future updateFlock(Flock flock) async {
    final db = await database;
    final now = _nowIso();
    final data = flock.copyWith(
      updatedAt: now,
      lastModified: now,
      syncStatus: 'pending',
    );
    final affected = await db
        .update('flocks', data.toMap(), where: 'id = ?', whereArgs: [flock.id]);
    if (affected == 0) throw DatabaseException('Flock ${flock.id} not found.');
  }

  Future deleteFlock(String flockId) async {
    final db = await database;
    await db.delete('flocks', where: 'id = ?', whereArgs: [flockId]);
  }

  // ─── Expenses ──────────────────────────────────────────────────────────────

  Future<List<Expense>> getExpensesByFlock(String flockId) async {
    final db = await database;
    final rows = await db.query('expenses',
        where: 'flockId = ? AND (deleted = 0 OR deleted IS NULL)',
        whereArgs: [flockId],
        orderBy: 'date DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final rows = await db.query('expenses',
        where: 'deleted = 0 OR deleted IS NULL', orderBy: 'date DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future createExpense(Expense expense) async {
    final db = await database;
    final now = _nowIso();
    final data = expense.copyWith(
      createdAt: now,
      updatedAt: now,
      lastModified: now,
      syncStatus: 'pending',
    );
    await db.insert('expenses', data.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future updateExpense(Expense expense) async {
    final db = await database;
    final now = _nowIso();
    final data = expense.copyWith(
      updatedAt: now,
      lastModified: now,
      syncStatus: 'pending',
    );
    await db.update('expenses', data.toMap(),
        where: 'id = ?', whereArgs: [expense.id]);
  }

  Future deleteExpense(String id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Sales ─────────────────────────────────────────────────────────────────

  Future<List<Sale>> getSalesByFlock(String flockId) async {
    final db = await database;
    final rows = await db.query('sales',
        where: 'flockId = ? AND (deleted = 0 OR deleted IS NULL)',
        whereArgs: [flockId],
        orderBy: 'date DESC');
    return rows.map(Sale.fromMap).toList();
  }

  Future<List<Sale>> getAllSales() async {
    final db = await database;
    final rows = await db.query('sales',
        where: 'deleted = 0 OR deleted IS NULL', orderBy: 'date DESC');
    return rows.map(Sale.fromMap).toList();
  }

  Future createSale(Sale sale) async {
    final db = await database;
    final now = _nowIso();
    final data = sale.copyWith(
      createdAt: now,
      updatedAt: now,
      lastModified: now,
      syncStatus: 'pending',
    );
    await db.insert('sales', data.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future updateSale(Sale sale) async {
    final db = await database;
    final now = _nowIso();
    final data = sale.copyWith(
      updatedAt: now,
      lastModified: now,
      syncStatus: 'pending',
    );
    await db
        .update('sales', data.toMap(), where: 'id = ?', whereArgs: [sale.id]);
  }

  Future deleteSale(String id) async {
    final db = await database;
    await db.delete('sales', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Daily Records ─────────────────────────────────────────────────────────

  Future<List<DailyRecord>> getDailyRecordsByFlock(String flockId) async {
    final db = await database;
    final rows = await db.query('daily_records',
        where: 'flockId = ? AND (deleted = 0 OR deleted IS NULL)',
        whereArgs: [flockId],
        orderBy: 'date DESC');
    return rows.map(DailyRecord.fromMap).toList();
  }

  Future<int> getTotalMortalityByFlock(String flockId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(mortalityCount), 0) as total
      FROM daily_records
      WHERE flockId = ?
      AND (deleted = 0 OR deleted IS NULL)
    ''', [flockId]);
    return (rows.first['total'] as num).toInt();
  }

  Future createDailyRecord(DailyRecord record) async {
    final db = await database;
    final now = _nowIso();
    final data = record.copyWith(
      createdAt: now,
      updatedAt: now,
      lastModified: now,
      syncStatus: 'pending',
    );
    await db.insert('daily_records', data.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future updateDailyRecord(DailyRecord record) async {
    final db = await database;
    final now = _nowIso();
    final data = record.copyWith(
      updatedAt: now,
      lastModified: now,
      syncStatus: 'pending',
    );
    await db.update('daily_records', data.toMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  Future deleteDailyRecord(String id) async {
    final db = await database;
    await db.delete('daily_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<DailyRecord?> getLatestRecordByFlock(String flockId) async {
    final db = await database;
    final rows = await db.query('daily_records',
        where: 'flockId = ? AND (deleted = 0 OR deleted IS NULL)',
        whereArgs: [flockId],
        orderBy: 'date DESC',
        limit: 1);
    if (rows.isEmpty) return null;
    return DailyRecord.fromMap(rows.first);
  }

  // ─── Stock ─────────────────────────────────────────────────────────────────

  Future<List<Stock>> getStockByFlock(String flockId) async {
    final db = await database;
    final rows = await db.query('stock',
        where: 'flockId = ? AND (deleted = 0 OR deleted IS NULL)',
        whereArgs: [flockId]);
    return rows.map(Stock.fromMap).toList();
  }

  Future<List<Stock>> getLowStockAlerts(String flockId) async {
    final db = await database;
    final rows = await db.query('stock',
        where:
            'flockId = ? AND quantity <= minThreshold AND (deleted = 0 OR deleted IS NULL)',
        whereArgs: [flockId]);
    return rows.map(Stock.fromMap).toList();
  }

  Future createStock(Stock stock) async {
    final db = await database;
    final now = _nowIso();
    final data = stock.copyWith(
      createdAt: now,
      updatedAt: now,
      lastModified: now,
      syncStatus: 'pending',
    );
    await db.insert('stock', data.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future updateStock(Stock stock) async {
    final db = await database;
    final now = _nowIso();
    final data = stock.copyWith(
      updatedAt: now,
      lastModified: now,
      syncStatus: 'pending',
    );
    await db
        .update('stock', data.toMap(), where: 'id = ?', whereArgs: [stock.id]);
  }

  Future deleteStock(String id) async {
    final db = await database;
    await db.delete('stock', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Health Events ─────────────────────────────────────────────────────────

  Future<List<HealthEvent>> getHealthEventsByFlock(String flockId) async {
    final db = await database;
    final rows = await db.query('health_events',
        where: 'flockId = ? AND (deleted = 0 OR deleted IS NULL)',
        whereArgs: [flockId],
        orderBy: 'date DESC');
    return rows.map(HealthEvent.fromMap).toList();
  }

  Future createHealthEvent(HealthEvent event) async {
    final db = await database;
    final now = _nowIso();
    final data = event.copyWith(
      createdAt: now,
      updatedAt: now,
      lastModified: now,
      syncStatus: 'pending',
    );
    await db.insert('health_events', data.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future updateHealthEvent(HealthEvent event) async {
    final db = await database;
    final now = _nowIso();
    final data = event.copyWith(
      updatedAt: now,
      lastModified: now,
      syncStatus: 'pending',
    );
    await db.update('health_events', data.toMap(),
        where: 'id = ?', whereArgs: [event.id]);
  }

  Future deleteHealthEvent(String id) async {
    final db = await database;
    await db.delete('health_events', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Export/Import ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> exportAllToJson() async {
    final db = await database;

    try {
      final flocks = await db.query('flocks');
      final records = await db.query('daily_records');
      final expenses = await db.query('expenses');
      final health = await db.query('health_events');
      final stock = await db.query('stock');
      final sales = await db.query('sales');

      return {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'data': {
          'flocks': flocks,
          'records': records,
          'expenses': expenses,
          'health': health,
          'stock': stock,
          'sales': sales,
        }
      };
    } catch (e) {
      debugPrint('Export error: $e');
      rethrow;
    }
  }

  Future<void> importAllFromJson(Map<String, dynamic> data) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        await txn.delete('health_events');
        await txn.delete('stock');
        await txn.delete('daily_records');
        await txn.delete('sales');
        await txn.delete('expenses');
        await txn.delete('flocks');

        if (data['data']['flocks'] != null) {
          for (var flock in data['data']['flocks']) {
            await txn.insert('flocks', flock);
          }
        }

        if (data['data']['records'] != null) {
          for (var record in data['data']['records']) {
            await txn.insert('daily_records', record);
          }
        }

        if (data['data']['expenses'] != null) {
          for (var expense in data['data']['expenses']) {
            await txn.insert('expenses', expense);
          }
        }

        if (data['data']['health'] != null) {
          for (var health in data['data']['health']) {
            await txn.insert('health_events', health);
          }
        }

        if (data['data']['stock'] != null) {
          for (var stock in data['data']['stock']) {
            await txn.insert('stock', stock);
          }
        }

        if (data['data']['sales'] != null) {
          for (var sale in data['data']['sales']) {
            await txn.insert('sales', sale);
          }
        }
      });

      debugPrint('Import successful');
    } catch (e) {
      debugPrint('Import error: $e');
      rethrow;
    }
  }

  // ─── Utility ───────────────────────────────────────────────────────────────

  Future clearAllData() async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        await txn.delete('health_events');
        await txn.delete('stock');
        await txn.delete('daily_records');
        await txn.delete('sales');
        await txn.delete('expenses');
        await txn.delete('flocks');
      });

      debugPrint('All data cleared');
    } catch (e) {
      debugPrint('Clear error: $e');
      rethrow;
    }
  }

  Future close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

class DatabaseException implements Exception {
  final String message;
  const DatabaseException(this.message);
  @override
  String toString() => 'DatabaseException: $message';
}
