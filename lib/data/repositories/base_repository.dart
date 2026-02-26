import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

/// Base repository class with common CRUD operations
abstract class BaseRepository<T> {
  final DatabaseHelper _dbHelper;
  
  BaseRepository(this._dbHelper);
  
  /// Get database instance
  Future<Database> get database => _dbHelper.database;
  
  /// Get table name - to be implemented by subclasses
  String get tableName;
  
  /// Convert entity to map - to be implemented by subclasses
  Map<String, dynamic> toMap(T entity);
  
  /// Convert map to entity - to be implemented by subclasses
  T fromMap(Map<String, dynamic> map);
  
  /// Insert an entity
  Future<int> insert(T entity) async {
    final db = await database;
    return await db.insert(
      tableName,
      toMap(entity),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Insert multiple entities in a transaction
  Future<void> insertAll(List<T> entities) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final entity in entities) {
        batch.insert(
          tableName,
          toMap(entity),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }
  
  /// Update an entity
  Future<int> update(T entity, String id) async {
    final db = await database;
    return await db.update(
      tableName,
      toMap(entity),
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// Delete an entity by ID
  Future<int> delete(String id) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// Delete multiple entities by IDs
  Future<int> deleteAll(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(', ');
    return await db.delete(
      tableName,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }
  
  /// Get entity by ID
  Future<T?> getById(String id) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return fromMap(result.first);
  }
  
  /// Get all entities
  Future<List<T>> getAll({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final result = await db.query(
      tableName,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return result.map(fromMap).toList();
  }
  
  /// Count all entities
  Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  /// Check if entity exists by ID
  Future<bool> exists(String id) async {
    final db = await database;
    final result = await db.query(
      tableName,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty;
  }
  
  /// Execute raw query
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }
  
  /// Execute raw insert/update/delete
  Future<int> rawExecute(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }
}
