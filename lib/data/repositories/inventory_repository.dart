import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';
import '../database/database_helper.dart';
import '../models/inventory_transaction.dart';
import 'base_repository.dart';

/// Repository for inventory transaction operations
class InventoryRepository extends BaseRepository<InventoryTransaction> {
  InventoryRepository(super.dbHelper);

  @override
  String get tableName => DbConstants.tableInventoryTransactions;

  @override
  Map<String, dynamic> toMap(InventoryTransaction entity) => entity.toMap();

  @override
  InventoryTransaction fromMap(Map<String, dynamic> map) => InventoryTransaction.fromMap(map);

  /// Record stock-in and update product stock
  Future<InventoryTransaction> recordStockIn({
    required String productId,
    required double quantity,
    String? notes,
  }) async {
    final db = await database;
    
    // Get current stock
    final productResult = await db.query(
      DbConstants.tableProducts,
      columns: [DbConstants.colCurrentStock],
      where: '${DbConstants.colId} = ?',
      whereArgs: [productId],
      limit: 1,
    );
    
    if (productResult.isEmpty) {
      throw Exception('Product not found');
    }
    
    final currentStock = (productResult.first[DbConstants.colCurrentStock] as num).toDouble();
    final newStock = currentStock + quantity;
    
    final transaction = InventoryTransaction.stockIn(
      productId: productId,
      quantity: quantity,
      currentStock: currentStock,
      notes: notes,
    );
    
    // Use database transaction
    await db.transaction((txn) async {
      // Insert inventory transaction
      await txn.insert(tableName, transaction.toMap());
      
      // Update product stock
      await txn.update(
        DbConstants.tableProducts,
        {
          DbConstants.colCurrentStock: newStock,
          DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [productId],
      );
    });
    
    return transaction;
  }

  /// Record stock-out (delivery) and update product stock
  Future<InventoryTransaction> recordStockOut({
    required String productId,
    required double quantity,
    String? referenceId,
    String? notes,
  }) async {
    final db = await database;
    
    // Get current stock
    final productResult = await db.query(
      DbConstants.tableProducts,
      columns: [DbConstants.colCurrentStock],
      where: '${DbConstants.colId} = ?',
      whereArgs: [productId],
      limit: 1,
    );
    
    if (productResult.isEmpty) {
      throw Exception('Product not found');
    }
    
    final currentStock = (productResult.first[DbConstants.colCurrentStock] as num).toDouble();
    
    if (currentStock < quantity) {
      throw Exception('Insufficient stock. Available: $currentStock, Requested: $quantity');
    }
    
    final newStock = currentStock - quantity;
    
    final transaction = InventoryTransaction.stockOut(
      productId: productId,
      quantity: quantity,
      currentStock: currentStock,
      referenceId: referenceId,
      notes: notes,
    );
    
    // Use database transaction
    await db.transaction((txn) async {
      // Insert inventory transaction
      await txn.insert(tableName, transaction.toMap());
      
      // Update product stock
      await txn.update(
        DbConstants.tableProducts,
        {
          DbConstants.colCurrentStock: newStock,
          DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [productId],
      );
    });
    
    return transaction;
  }

  /// Record stock-out for delivery (allows negative stock — business must proceed)
  Future<InventoryTransaction> recordDeliveryStockOut({
    required String productId,
    required double quantity,
    String? referenceId,
    String? notes,
  }) async {
    final db = await database;

    final productResult = await db.query(
      DbConstants.tableProducts,
      columns: [DbConstants.colCurrentStock],
      where: '${DbConstants.colId} = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (productResult.isEmpty) {
      throw Exception('Product not found');
    }

    final currentStock = (productResult.first[DbConstants.colCurrentStock] as num).toDouble();
    final newStock = currentStock - quantity; // may go negative

    final transaction = InventoryTransaction.stockOut(
      productId: productId,
      quantity: quantity,
      currentStock: currentStock,
      referenceId: referenceId,
      notes: notes,
    );

    await db.transaction((txn) async {
      await txn.insert(tableName, transaction.toMap());
      await txn.update(
        DbConstants.tableProducts,
        {
          DbConstants.colCurrentStock: newStock,
          DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [productId],
      );
    });

    return transaction;
  }

  /// Record stock adjustment and update product stock
  Future<InventoryTransaction> recordAdjustment({
    required String productId,
    required double newQuantity,
    String? notes,
  }) async {
    final db = await database;
    
    // Get current stock
    final productResult = await db.query(
      DbConstants.tableProducts,
      columns: [DbConstants.colCurrentStock],
      where: '${DbConstants.colId} = ?',
      whereArgs: [productId],
      limit: 1,
    );
    
    if (productResult.isEmpty) {
      throw Exception('Product not found');
    }
    
    final currentStock = (productResult.first[DbConstants.colCurrentStock] as num).toDouble();
    
    final transaction = InventoryTransaction.adjustment(
      productId: productId,
      newQuantity: newQuantity,
      currentStock: currentStock,
      notes: notes,
    );
    
    // Use database transaction
    await db.transaction((txn) async {
      // Insert inventory transaction
      await txn.insert(tableName, transaction.toMap());
      
      // Update product stock
      await txn.update(
        DbConstants.tableProducts,
        {
          DbConstants.colCurrentStock: newQuantity,
          DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [productId],
      );
    });
    
    return transaction;
  }

  /// Record stock deduction for order delivery (multiple products)
  Future<List<InventoryTransaction>> recordDelivery({
    required String orderId,
    required Map<String, double> productQuantities, // productId -> quantity
  }) async {
    final db = await database;
    final transactions = <InventoryTransaction>[];
    
    await db.transaction((txn) async {
      for (final entry in productQuantities.entries) {
        final productId = entry.key;
        final quantity = entry.value;
        
        // Get current stock
        final productResult = await txn.query(
          DbConstants.tableProducts,
          columns: [DbConstants.colCurrentStock],
          where: '${DbConstants.colId} = ?',
          whereArgs: [productId],
          limit: 1,
        );
        
        if (productResult.isEmpty) continue;
        
        final currentStock = (productResult.first[DbConstants.colCurrentStock] as num).toDouble();
        final newStock = (currentStock - quantity).clamp(0, double.infinity);
        
        final transaction = InventoryTransaction.stockOut(
          productId: productId,
          quantity: quantity,
          currentStock: currentStock,
          referenceId: orderId,
          notes: 'Xuất kho giao hàng',
        );
        
        transactions.add(transaction);
        
        // Insert inventory transaction
        await txn.insert(tableName, transaction.toMap());
        
        // Update product stock
        await txn.update(
          DbConstants.tableProducts,
          {
            DbConstants.colCurrentStock: newStock,
            DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
          },
          where: '${DbConstants.colId} = ?',
          whereArgs: [productId],
        );
      }
    });
    
    return transactions;
  }

  /// Get transactions by product
  Future<List<InventoryTransaction>> getByProduct(
    String productId, {
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colProductId} = ?',
      whereArgs: [productId],
      orderBy: '${DbConstants.colCreatedAt} DESC',
      limit: limit,
      offset: offset,
    );
    return result.map(fromMap).toList();
  }

  /// Get transactions by type
  Future<List<InventoryTransaction>> getByType(
    TransactionType type, {
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colType} = ?',
      whereArgs: [type.value],
      orderBy: '${DbConstants.colCreatedAt} DESC',
      limit: limit,
      offset: offset,
    );
    return result.map(fromMap).toList();
  }

  /// Get transactions by order
  Future<List<InventoryTransaction>> getByOrder(String orderId) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colOrderId} = ?',
      whereArgs: [orderId],
      orderBy: '${DbConstants.colCreatedAt} DESC',
    );
    return result.map(fromMap).toList();
  }

  /// Get transactions by date range with product info
  Future<List<InventoryTransaction>> getByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? productId,
    TransactionType? type,
  }) async {
    final db = await database;
    
    String where = 'it.${DbConstants.colCreatedAt} >= ? AND it.${DbConstants.colCreatedAt} < ?';
    List<Object> whereArgs = [
      AppDateUtils.toDbDateTime(startDate),
      AppDateUtils.toDbDateTime(endDate.add(const Duration(days: 1))),
    ];
    
    if (productId != null) {
      where += ' AND it.${DbConstants.colProductId} = ?';
      whereArgs.add(productId);
    }
    
    if (type != null) {
      where += ' AND it.${DbConstants.colType} = ?';
      whereArgs.add(type.value);
    }
    
    final result = await db.rawQuery('''
      SELECT 
        it.*,
        p.${DbConstants.colName} as product_name,
        p.${DbConstants.colSku} as product_sku,
        p.${DbConstants.colUnit} as product_unit
      FROM ${DbConstants.tableInventoryTransactions} it
      INNER JOIN ${DbConstants.tableProducts} p ON it.${DbConstants.colProductId} = p.${DbConstants.colId}
      WHERE $where
      ORDER BY it.${DbConstants.colCreatedAt} DESC
    ''', whereArgs);
    
    return result.map(fromMap).toList();
  }

  /// Get recent transactions with product info
  Future<List<InventoryTransaction>> getRecent({int limit = 50}) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        it.*,
        p.${DbConstants.colName} as product_name,
        p.${DbConstants.colSku} as product_sku,
        p.${DbConstants.colUnit} as product_unit
      FROM ${DbConstants.tableInventoryTransactions} it
      INNER JOIN ${DbConstants.tableProducts} p ON it.${DbConstants.colProductId} = p.${DbConstants.colId}
      ORDER BY it.${DbConstants.colCreatedAt} DESC
      LIMIT ?
    ''', [limit]);
    
    return result.map(fromMap).toList();
  }

  /// Get inventory summary for a product
  Future<Map<String, dynamic>> getProductSummary(String productId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        ${DbConstants.colType},
        SUM(${DbConstants.colQuantity}) as total_quantity,
        COUNT(*) as transaction_count
      FROM $tableName
      WHERE ${DbConstants.colProductId} = ?
      GROUP BY ${DbConstants.colType}
    ''', [productId]);
    
    final summary = <String, dynamic>{
      'total_in': 0.0,
      'total_out': 0.0,
      'total_adjustments': 0,
    };
    
    for (final row in result) {
      final type = row[DbConstants.colType] as String;
      final totalQty = (row['total_quantity'] as num?)?.toDouble() ?? 0;
      
      if (type == 'stock_in' || type == 'returned') {
        summary['total_in'] = (summary['total_in'] as double) + totalQty;
      } else if (type == 'stock_out') {
        summary['total_out'] = (summary['total_out'] as double) + totalQty;
      } else if (type == 'adjustment') {
        summary['total_adjustments'] = (row['transaction_count'] as int?) ?? 0;
      }
    }
    
    return summary;
  }

  /// Update an existing inventory transaction and adjust product stock
  Future<void> updateTransaction({
    required String transactionId,
    required double newQuantity,
    String? notes,
  }) async {
    final db = await database;
    
    // Get old transaction
    final result = await db.query(
      tableName,
      where: '${DbConstants.colId} = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    
    if (result.isEmpty) throw Exception('Transaction not found');
    
    final oldTxn = InventoryTransaction.fromMap(result.first);
    final oldQty = oldTxn.quantity;
    
    // Calculate new stockAfter and stock delta
    double newStockAfter;
    double stockDelta;
    
    if (oldTxn.type == TransactionType.adjustment) {
      newStockAfter = newQuantity;
      stockDelta = newQuantity - oldTxn.stockAfter;
    } else if (oldTxn.type.isIncrease) {
      newStockAfter = oldTxn.stockBefore + newQuantity;
      stockDelta = newQuantity - oldQty;
    } else {
      newStockAfter = oldTxn.stockBefore - newQuantity;
      stockDelta = oldQty - newQuantity;
    }
    
    await db.transaction((txn) async {
      // Update transaction record
      final updateMap = <String, dynamic>{
        DbConstants.colQuantity: newQuantity,
        DbConstants.colStockAfter: newStockAfter,
      };
      if (notes != null) {
        updateMap[DbConstants.colNotes] = notes;
      }
      
      await txn.update(
        tableName,
        updateMap,
        where: '${DbConstants.colId} = ?',
        whereArgs: [transactionId],
      );
      
      // Update product stock
      final productResult = await txn.query(
        DbConstants.tableProducts,
        columns: [DbConstants.colCurrentStock],
        where: '${DbConstants.colId} = ?',
        whereArgs: [oldTxn.productId],
        limit: 1,
      );
      
      if (productResult.isNotEmpty) {
        final currentStock = (productResult.first[DbConstants.colCurrentStock] as num).toDouble();
        await txn.update(
          DbConstants.tableProducts,
          {
            DbConstants.colCurrentStock: currentStock + stockDelta,
            DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
          },
          where: '${DbConstants.colId} = ?',
          whereArgs: [oldTxn.productId],
        );
      }
    });
  }

  /// Delete an inventory transaction and reverse its stock effect
  Future<void> deleteTransaction(String transactionId) async {
    final db = await database;
    
    // Get transaction to reverse
    final result = await db.query(
      tableName,
      where: '${DbConstants.colId} = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    
    if (result.isEmpty) throw Exception('Transaction not found');
    
    final oldTxn = InventoryTransaction.fromMap(result.first);
    final stockDelta = oldTxn.stockAfter - oldTxn.stockBefore;
    
    await db.transaction((dbTxn) async {
      // Delete transaction
      await dbTxn.delete(
        tableName,
        where: '${DbConstants.colId} = ?',
        whereArgs: [transactionId],
      );
      
      // Reverse stock change on product
      final productResult = await dbTxn.query(
        DbConstants.tableProducts,
        columns: [DbConstants.colCurrentStock],
        where: '${DbConstants.colId} = ?',
        whereArgs: [oldTxn.productId],
        limit: 1,
      );
      
      if (productResult.isNotEmpty) {
        final currentStock = (productResult.first[DbConstants.colCurrentStock] as num).toDouble();
        await dbTxn.update(
          DbConstants.tableProducts,
          {
            DbConstants.colCurrentStock: currentStock - stockDelta,
            DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
          },
          where: '${DbConstants.colId} = ?',
          whereArgs: [oldTxn.productId],
        );
      }
    });
  }
}
