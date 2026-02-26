import '../../core/constants/db_constants.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import 'base_repository.dart';

/// Repository for product CRUD operations
class ProductRepository extends BaseRepository<Product> {
  ProductRepository(super.dbHelper);

  @override
  String get tableName => DbConstants.tableProducts;

  @override
  Map<String, dynamic> toMap(Product entity) => entity.toMap();

  @override
  Product fromMap(Map<String, dynamic> map) => Product.fromMap(map);

  /// Get all active products
  Future<List<Product>> getActiveProducts({
    String? category,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    String where = '${DbConstants.colIsActive} = ?';
    List<Object> whereArgs = [1];

    if (category != null && category.isNotEmpty) {
      where += ' AND ${DbConstants.colCategory} = ?';
      whereArgs.add(category);
    }

    final result = await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy ?? '${DbConstants.colName} ASC',
      limit: limit,
      offset: offset,
    );
    return result.map(fromMap).toList();
  }

  /// Search products by name or SKU
  Future<List<Product>> search(String query, {bool activeOnly = true}) async {
    final db = await database;
    String where = '(${DbConstants.colName} LIKE ? OR ${DbConstants.colSku} LIKE ?)';
    List<Object> whereArgs = ['%$query%', '%$query%'];

    if (activeOnly) {
      where += ' AND ${DbConstants.colIsActive} = ?';
      whereArgs.add(1);
    }

    final result = await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: '${DbConstants.colName} ASC',
    );
    return result.map(fromMap).toList();
  }

  /// Get product by SKU
  Future<Product?> getBySku(String sku) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colSku} = ?',
      whereArgs: [sku],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return fromMap(result.first);
  }

  /// Get products by category
  Future<List<Product>> getByCategory(String category, {bool activeOnly = true}) async {
    final db = await database;
    String where = '${DbConstants.colCategory} = ?';
    List<Object> whereArgs = [category];

    if (activeOnly) {
      where += ' AND ${DbConstants.colIsActive} = ?';
      whereArgs.add(1);
    }

    final result = await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: '${DbConstants.colName} ASC',
    );
    return result.map(fromMap).toList();
  }

  /// Get products with low stock
  Future<List<Product>> getLowStockProducts() async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colCurrentStock} <= ${DbConstants.colMinStockAlert} '
          'AND ${DbConstants.colIsActive} = ?',
      whereArgs: [1],
      orderBy: '${DbConstants.colCurrentStock} ASC',
    );
    return result.map(fromMap).toList();
  }

  /// Get products out of stock
  Future<List<Product>> getOutOfStockProducts() async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colCurrentStock} <= 0 AND ${DbConstants.colIsActive} = ?',
      whereArgs: [1],
      orderBy: '${DbConstants.colName} ASC',
    );
    return result.map(fromMap).toList();
  }

  /// Update product stock
  Future<int> updateStock(String id, double newStock) async {
    final db = await database;
    return await db.update(
      tableName,
      {
        DbConstants.colCurrentStock: newStock,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Adjust stock by amount (positive to add, negative to subtract)
  Future<int> adjustStock(String id, double amount) async {
    final db = await database;
    return await db.rawUpdate('''
      UPDATE $tableName 
      SET ${DbConstants.colCurrentStock} = ${DbConstants.colCurrentStock} + ?,
          ${DbConstants.colUpdatedAt} = ?
      WHERE ${DbConstants.colId} = ?
    ''', [amount, DateTime.now().toIso8601String(), id]);
  }

  /// Toggle active status
  Future<int> toggleActive(String id, bool isActive) async {
    final db = await database;
    return await db.update(
      tableName,
      {
        DbConstants.colIsActive: isActive ? 1 : 0,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Get all categories (distinct)
  Future<List<String>> getAllCategories() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT ${DbConstants.colCategory} 
      FROM $tableName 
      WHERE ${DbConstants.colCategory} IS NOT NULL AND ${DbConstants.colCategory} != ''
      ORDER BY ${DbConstants.colCategory} ASC
    ''');
    return result.map((e) => e[DbConstants.colCategory] as String).toList();
  }

  /// Count active products
  Future<int> countActive() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE ${DbConstants.colIsActive} = 1',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Count low stock products
  Future<int> countLowStock() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM $tableName 
      WHERE ${DbConstants.colCurrentStock} <= ${DbConstants.colMinStockAlert} 
        AND ${DbConstants.colCurrentStock} > 0
        AND ${DbConstants.colIsActive} = 1
    ''');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Count out of stock products
  Future<int> countOutOfStock() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM $tableName 
      WHERE ${DbConstants.colCurrentStock} <= 0 
        AND ${DbConstants.colIsActive} = 1
    ''');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get product with price for specific restaurant
  Future<Map<String, dynamic>?> getWithRestaurantPrice(String productId, String restaurantId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        p.*,
        rp.${DbConstants.colPrice} as restaurant_price
      FROM ${DbConstants.tableProducts} p
      LEFT JOIN ${DbConstants.tableRestaurantPrices} rp 
        ON p.${DbConstants.colId} = rp.${DbConstants.colProductId}
        AND rp.${DbConstants.colRestaurantId} = ?
      WHERE p.${DbConstants.colId} = ?
    ''', [restaurantId, productId]);
    
    if (result.isEmpty) return null;
    return result.first;
  }

  /// Get all products with prices for specific restaurant
  Future<List<Map<String, dynamic>>> getAllWithRestaurantPrices(String restaurantId, {bool activeOnly = true}) async {
    final db = await database;
    final whereClause = activeOnly ? 'WHERE p.${DbConstants.colIsActive} = 1' : '';
    
    final result = await db.rawQuery('''
      SELECT 
        p.*,
        rp.${DbConstants.colPrice} as restaurant_price,
        COALESCE(rp.${DbConstants.colPrice}, p.${DbConstants.colBasePrice}) as effective_price
      FROM ${DbConstants.tableProducts} p
      LEFT JOIN ${DbConstants.tableRestaurantPrices} rp 
        ON p.${DbConstants.colId} = rp.${DbConstants.colProductId}
        AND rp.${DbConstants.colRestaurantId} = ?
      $whereClause
      ORDER BY p.${DbConstants.colName} ASC
    ''', [restaurantId]);
    
    return result;
  }
}
