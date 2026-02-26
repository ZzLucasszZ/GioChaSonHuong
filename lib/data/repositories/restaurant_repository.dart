import '../../core/constants/db_constants.dart';
import '../database/database_helper.dart';
import '../models/restaurant.dart';
import 'base_repository.dart';

/// Repository for restaurant CRUD operations
class RestaurantRepository extends BaseRepository<Restaurant> {
  RestaurantRepository(super.dbHelper);

  @override
  String get tableName => DbConstants.tableRestaurants;

  @override
  Map<String, dynamic> toMap(Restaurant entity) => entity.toMap();

  @override
  Restaurant fromMap(Map<String, dynamic> map) => Restaurant.fromMap(map);

  /// Get all active restaurants
  Future<List<Restaurant>> getActiveRestaurants({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colIsActive} = ?',
      whereArgs: [1],
      orderBy: orderBy ?? '${DbConstants.colName} ASC',
      limit: limit,
      offset: offset,
    );
    return result.map(fromMap).toList();
  }

  /// Search restaurants by name
  Future<List<Restaurant>> searchByName(String query, {bool activeOnly = true}) async {
    final db = await database;
    String? where;
    List<Object>? whereArgs;

    if (activeOnly) {
      where = '${DbConstants.colName} LIKE ? AND ${DbConstants.colIsActive} = ?';
      whereArgs = ['%$query%', 1];
    } else {
      where = '${DbConstants.colName} LIKE ?';
      whereArgs = ['%$query%'];
    }

    final result = await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: '${DbConstants.colName} ASC',
    );
    return result.map(fromMap).toList();
  }

  /// Get restaurant by phone
  Future<Restaurant?> getByPhone(String phone) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colPhone} = ?',
      whereArgs: [phone],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return fromMap(result.first);
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

  /// Get restaurant with total debt info
  Future<Map<String, dynamic>?> getWithDebtInfo(String id) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        r.*,
        COALESCE(SUM(o.${DbConstants.colTotalAmount} - o.${DbConstants.colPaidAmount}), 0) as total_debt,
        COUNT(o.${DbConstants.colId}) as total_orders
      FROM ${DbConstants.tableRestaurants} r
      LEFT JOIN ${DbConstants.tableOrders} o ON r.${DbConstants.colId} = o.${DbConstants.colRestaurantId}
        AND o.${DbConstants.colStatus} != 'cancelled'
      WHERE r.${DbConstants.colId} = ?
      GROUP BY r.${DbConstants.colId}
    ''', [id]);
    
    if (result.isEmpty) return null;
    return result.first;
  }

  /// Get all restaurants with debt summary
  Future<List<Map<String, dynamic>>> getAllWithDebtSummary({bool activeOnly = true}) async {
    final db = await database;
    final whereClause = activeOnly ? 'WHERE r.${DbConstants.colIsActive} = 1' : '';
    
    final result = await db.rawQuery('''
      SELECT 
        r.*,
        COALESCE(SUM(CASE WHEN o.${DbConstants.colStatus} != 'cancelled' 
          THEN o.${DbConstants.colTotalAmount} - o.${DbConstants.colPaidAmount} 
          ELSE 0 END), 0) as total_debt,
        COUNT(CASE WHEN o.${DbConstants.colStatus} != 'cancelled' THEN o.${DbConstants.colId} END) as total_orders
      FROM ${DbConstants.tableRestaurants} r
      LEFT JOIN ${DbConstants.tableOrders} o ON r.${DbConstants.colId} = o.${DbConstants.colRestaurantId}
      $whereClause
      GROUP BY r.${DbConstants.colId}
      ORDER BY r.${DbConstants.colName} ASC
    ''');
    
    return result;
  }

  /// Count active restaurants
  Future<int> countActive() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE ${DbConstants.colIsActive} = 1',
    );
    return (result.first['count'] as int?) ?? 0;
  }
}
