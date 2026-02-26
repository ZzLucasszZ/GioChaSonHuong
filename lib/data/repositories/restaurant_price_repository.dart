import '../../core/constants/db_constants.dart';
import '../database/database_helper.dart';
import '../models/restaurant_price.dart';
import 'base_repository.dart';

/// Repository for restaurant-specific pricing operations
class RestaurantPriceRepository extends BaseRepository<RestaurantPrice> {
  RestaurantPriceRepository(super.dbHelper);

  @override
  String get tableName => DbConstants.tableRestaurantPrices;

  @override
  Map<String, dynamic> toMap(RestaurantPrice entity) => entity.toMap();

  @override
  RestaurantPrice fromMap(Map<String, dynamic> map) => RestaurantPrice.fromMap(map);

  /// Get price for a specific restaurant and product
  Future<RestaurantPrice?> getPrice(String restaurantId, String productId) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colRestaurantId} = ? AND ${DbConstants.colProductId} = ?',
      whereArgs: [restaurantId, productId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return fromMap(result.first);
  }

  /// Get all prices for a restaurant with product details
  Future<List<RestaurantPrice>> getPricesForRestaurant(String restaurantId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        rp.*,
        p.${DbConstants.colName} as product_name,
        p.${DbConstants.colUnit} as product_unit,
        p.${DbConstants.colBasePrice} as product_base_price
      FROM ${DbConstants.tableRestaurantPrices} rp
      INNER JOIN ${DbConstants.tableProducts} p ON rp.${DbConstants.colProductId} = p.${DbConstants.colId}
      WHERE rp.${DbConstants.colRestaurantId} = ?
        AND p.${DbConstants.colIsActive} = 1
      ORDER BY p.${DbConstants.colName} ASC
    ''', [restaurantId]);
    
    return result.map((map) => RestaurantPrice.fromMap(map)).toList();
  }

  /// Get all prices for a product (across restaurants)
  Future<List<Map<String, dynamic>>> getPricesForProduct(String productId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        rp.*,
        r.${DbConstants.colName} as restaurant_name
      FROM ${DbConstants.tableRestaurantPrices} rp
      INNER JOIN ${DbConstants.tableRestaurants} r ON rp.${DbConstants.colRestaurantId} = r.${DbConstants.colId}
      WHERE rp.${DbConstants.colProductId} = ?
        AND r.${DbConstants.colIsActive} = 1
      ORDER BY r.${DbConstants.colName} ASC
    ''', [productId]);
    
    return result;
  }

  /// Set price for a restaurant and product (insert or update)
  Future<int> setPrice({
    required String restaurantId,
    required String productId,
    required double price,
  }) async {
    final db = await database;
    final existing = await getPrice(restaurantId, productId);
    
    if (existing != null) {
      // Update existing price
      return await db.update(
        tableName,
        {
          DbConstants.colPrice: price,
          DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [existing.id],
      );
    } else {
      // Insert new price
      final newPrice = RestaurantPrice.create(
        restaurantId: restaurantId,
        productId: productId,
        price: price,
      );
      return await insert(newPrice);
    }
  }

  /// Delete price for a restaurant and product
  Future<int> deletePrice(String restaurantId, String productId) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: '${DbConstants.colRestaurantId} = ? AND ${DbConstants.colProductId} = ?',
      whereArgs: [restaurantId, productId],
    );
  }

  /// Delete all prices for a restaurant
  Future<int> deleteAllForRestaurant(String restaurantId) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: '${DbConstants.colRestaurantId} = ?',
      whereArgs: [restaurantId],
    );
  }

  /// Delete all prices for a product
  Future<int> deleteAllForProduct(String productId) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: '${DbConstants.colProductId} = ?',
      whereArgs: [productId],
    );
  }

  /// Bulk set prices for a restaurant
  Future<void> bulkSetPrices({
    required String restaurantId,
    required Map<String, double> productPrices, // productId -> price
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in productPrices.entries) {
        final productId = entry.key;
        final price = entry.value;
        
        // Check if exists
        final existing = await txn.query(
          tableName,
          where: '${DbConstants.colRestaurantId} = ? AND ${DbConstants.colProductId} = ?',
          whereArgs: [restaurantId, productId],
          limit: 1,
        );
        
        if (existing.isNotEmpty) {
          await txn.update(
            tableName,
            {
              DbConstants.colPrice: price,
              DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
            },
            where: '${DbConstants.colRestaurantId} = ? AND ${DbConstants.colProductId} = ?',
            whereArgs: [restaurantId, productId],
          );
        } else {
          final newPrice = RestaurantPrice.create(
            restaurantId: restaurantId,
            productId: productId,
            price: price,
          );
          await txn.insert(tableName, newPrice.toMap());
        }
      }
    });
  }

  /// Get effective price for a product and restaurant
  /// Returns restaurant-specific price if exists, otherwise base price
  Future<double> getEffectivePrice(String restaurantId, String productId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(rp.${DbConstants.colPrice}, p.${DbConstants.colBasePrice}) as effective_price
      FROM ${DbConstants.tableProducts} p
      LEFT JOIN ${DbConstants.tableRestaurantPrices} rp 
        ON p.${DbConstants.colId} = rp.${DbConstants.colProductId}
        AND rp.${DbConstants.colRestaurantId} = ?
      WHERE p.${DbConstants.colId} = ?
    ''', [restaurantId, productId]);
    
    if (result.isEmpty) return 0;
    return (result.first['effective_price'] as num?)?.toDouble() ?? 0;
  }

  /// Count custom prices for a restaurant
  Future<int> countForRestaurant(String restaurantId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE ${DbConstants.colRestaurantId} = ?',
      [restaurantId],
    );
    return (result.first['count'] as int?) ?? 0;
  }
}
