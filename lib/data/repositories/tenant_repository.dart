import '../../core/constants/db_constants.dart';
import '../database/database_helper.dart';
import '../models/tenant.dart';
import 'base_repository.dart';

/// Repository for tenant CRUD operations
class TenantRepository extends BaseRepository<Tenant> {
  TenantRepository(super.dbHelper);

  @override
  String get tableName => DbConstants.tableTenants;

  @override
  Map<String, dynamic> toMap(Tenant entity) => entity.toMap();

  @override
  Tenant fromMap(Map<String, dynamic> map) => Tenant.fromMap(map);

  /// Get all active tenants
  Future<List<Tenant>> getActiveTenants() async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colIsActive} = ?',
      whereArgs: [1],
      orderBy: '${DbConstants.colRoomNumber} ASC',
    );
    return result.map(fromMap).toList();
  }

  /// Get all tenants (including inactive)
  Future<List<Tenant>> getAllTenants() async {
    final db = await database;
    final result = await db.query(
      tableName,
      orderBy: '${DbConstants.colRoomNumber} ASC',
    );
    return result.map(fromMap).toList();
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

  /// Delete tenant and all related invoices
  Future<void> deleteWithAllData(String tenantId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        DbConstants.tableRentalInvoices,
        where: '${DbConstants.colTenantId} = ?',
        whereArgs: [tenantId],
      );
      await txn.delete(
        DbConstants.tableTenants,
        where: '${DbConstants.colId} = ?',
        whereArgs: [tenantId],
      );
    });
  }
}
