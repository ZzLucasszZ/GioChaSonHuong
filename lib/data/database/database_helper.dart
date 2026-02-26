import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../core/constants/db_constants.dart';
import 'migrations/migration_v1.dart';

/// Database helper for SQLite operations
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbConstants.databaseName);

    return await openDatabase(
      path,
      version: DbConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Configure database (enable foreign keys)
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Create tables
    await db.execute(MigrationV1.createRestaurantsTable);
    await db.execute(MigrationV1.createProductsTable);
    await db.execute(MigrationV1.createRestaurantPricesTable);
    await db.execute(MigrationV1.createOrdersTable);
    await db.execute(MigrationV1.createOrderItemsTable);
    await db.execute(MigrationV1.createInventoryTransactionsTable);
    await db.execute(MigrationV1.createPaymentsTable);
    await db.execute(MigrationV1.createAppSettingsTable);

    // Create indexes
    for (final index in MigrationV1.createIndexes) {
      await db.execute(index);
    }

    // Insert default settings
    for (final setting in MigrationV1.defaultSettings) {
      await db.insert(DbConstants.tableAppSettings, setting);
    }
  }

  /// Upgrade database
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // V2: Create payments table (was defined in V1 migration but only runs on fresh install)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DbConstants.tablePayments} (
          ${DbConstants.colId} TEXT PRIMARY KEY,
          ${DbConstants.colRestaurantId} TEXT NOT NULL,
          ${DbConstants.colOrderId} TEXT,
          ${DbConstants.colAmount} REAL NOT NULL,
          ${DbConstants.colMethod} TEXT NOT NULL,
          ${DbConstants.colPaymentDate} TEXT NOT NULL,
          ${DbConstants.colNotes} TEXT,
          ${DbConstants.colCreatedAt} TEXT NOT NULL,
          FOREIGN KEY (${DbConstants.colRestaurantId}) REFERENCES ${DbConstants.tableRestaurants}(${DbConstants.colId}) ON DELETE CASCADE,
          FOREIGN KEY (${DbConstants.colOrderId}) REFERENCES ${DbConstants.tableOrders}(${DbConstants.colId}) ON DELETE SET NULL
        )
      ''');
      // Create indexes for payments table
      await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_restaurant ON ${DbConstants.tablePayments}(${DbConstants.colRestaurantId})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_order ON ${DbConstants.tablePayments}(${DbConstants.colOrderId})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_date ON ${DbConstants.tablePayments}(${DbConstants.colPaymentDate})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_created ON ${DbConstants.tablePayments}(${DbConstants.colCreatedAt})');
    }

    if (oldVersion < 3) {
      // V3: Fix corrupted paidAmount on orders.
      // Before V2, partial payments updated order.paidAmount but failed to save
      // payment records (payments table didn't exist). Users then used
      // "Bổ sung bản ghi" to add reconciliation records (order_id IS NULL).
      // This caused double-counting: paidAmount on orders + payment records.
      // Fix: Reset paidAmount for partial orders that have no linked payment record.
      final affected = await db.rawUpdate('''
        UPDATE ${DbConstants.tableOrders}
        SET ${DbConstants.colPaidAmount} = 0,
            ${DbConstants.colPaymentStatus} = 'unpaid',
            ${DbConstants.colUpdatedAt} = ?
        WHERE ${DbConstants.colPaidAmount} > 0
          AND ${DbConstants.colPaymentStatus} != 'paid'
          AND ${DbConstants.colId} NOT IN (
            SELECT DISTINCT ${DbConstants.colOrderId}
            FROM ${DbConstants.tablePayments}
            WHERE ${DbConstants.colOrderId} IS NOT NULL
          )
      ''', [DateTime.now().toIso8601String()]);
      if (affected > 0) {
        // ignore: avoid_print
        print('V3 migration: Reset paidAmount on $affected orders with no linked payment records');
      }
    }

    if (oldVersion < 4) {
      await _migrateV4MarkDeliveredAndDeductStock(db);
    }
  }

  /// V4: Retroactively mark fully-paid orders as delivered and deduct stock.
  /// Before V4, payment did not auto-deliver or deduct inventory.
  Future<void> _migrateV4MarkDeliveredAndDeductStock(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Find all fully-paid orders that are NOT yet delivered or cancelled
    final paidOrders = await db.rawQuery('''
      SELECT ${DbConstants.colId}
      FROM ${DbConstants.tableOrders}
      WHERE ${DbConstants.colPaymentStatus} = 'paid'
        AND ${DbConstants.colStatus} NOT IN ('delivered', 'cancelled')
    ''');

    if (paidOrders.isEmpty) return;

    // ignore: avoid_print
    print('V4 migration: Found \${paidOrders.length} paid but undelivered orders');

    for (final row in paidOrders) {
      final orderId = row[DbConstants.colId] as String;

      // 2. Mark order as delivered
      await db.rawUpdate('''
        UPDATE ${DbConstants.tableOrders}
        SET ${DbConstants.colStatus} = 'delivered',
            ${DbConstants.colUpdatedAt} = ?
        WHERE ${DbConstants.colId} = ?
      ''', [now, orderId]);

      // 3. Deduct stock for each order item
      final items = await db.rawQuery('''
        SELECT ${DbConstants.colProductId}, ${DbConstants.colQuantity}, ${DbConstants.colProductName}
        FROM ${DbConstants.tableOrderItems}
        WHERE ${DbConstants.colOrderId} = ?
      ''', [orderId]);

      for (final item in items) {
        final productId = item[DbConstants.colProductId] as String;
        final qty = (item[DbConstants.colQuantity] as num).toDouble();
        final productName = item[DbConstants.colProductName] as String? ?? productId;

        // Get current stock
        final stockResult = await db.rawQuery('''
          SELECT ${DbConstants.colCurrentStock}
          FROM ${DbConstants.tableProducts}
          WHERE ${DbConstants.colId} = ?
        ''', [productId]);

        if (stockResult.isEmpty) continue; // product deleted — skip

        final stockBefore = (stockResult.first[DbConstants.colCurrentStock] as num).toDouble();
        final stockAfter = stockBefore - qty; // may go negative

        // Insert inventory transaction record
        final txnId = '${orderId.substring(0, 8)}-v4-\${productId.substring(0, 8)}';
        await db.rawInsert('''
          INSERT OR IGNORE INTO ${DbConstants.tableInventoryTransactions}
            (${DbConstants.colId}, ${DbConstants.colProductId}, ${DbConstants.colType},
             ${DbConstants.colQuantity}, ${DbConstants.colStockBefore}, ${DbConstants.colStockAfter},
             ${DbConstants.colReferenceType}, ${DbConstants.colReferenceId},
             ${DbConstants.colNotes}, ${DbConstants.colCreatedAt})
          VALUES (?, ?, 'stock_out', ?, ?, ?, 'order', ?, ?, ?)
        ''', [
          txnId, productId, qty, stockBefore, stockAfter,
          orderId, 'V4 migration: trừ kho cho đơn đã thanh toán - $productName', now,
        ]);

        // Update product stock
        await db.rawUpdate('''
          UPDATE ${DbConstants.tableProducts}
          SET ${DbConstants.colCurrentStock} = ?,
              ${DbConstants.colUpdatedAt} = ?
          WHERE ${DbConstants.colId} = ?
        ''', [stockAfter, now, productId]);
      }
    }

    // ignore: avoid_print
    print('V4 migration: Marked \${paidOrders.length} orders as delivered & deducted stock');
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Delete database (for testing/reset)
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbConstants.databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  // ==================== Generic CRUD Operations ====================

  /// Insert a record
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update a record
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(
      table,
      data,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Delete a record
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Query records
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Execute raw query
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  /// Execute raw SQL
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    await db.execute(sql, arguments);
  }

  /// Run in transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  /// Get single record by id
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final results = await query(
      table,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get all records from table
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    String? orderBy,
    int? limit,
  }) async {
    return await query(
      table,
      orderBy: orderBy,
      limit: limit,
    );
  }

  /// Count records in table
  Future<int> count(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $table ${where != null ? 'WHERE $where' : ''}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Check if record exists
  Future<bool> exists(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final count = await this.count(table, where: where, whereArgs: whereArgs);
    return count > 0;
  }
}
