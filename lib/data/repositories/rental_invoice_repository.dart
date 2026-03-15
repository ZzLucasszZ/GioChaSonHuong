import '../../core/constants/db_constants.dart';
import '../database/database_helper.dart';
import '../models/rental_invoice.dart';
import 'base_repository.dart';

/// Repository for rental invoice CRUD operations
class RentalInvoiceRepository extends BaseRepository<RentalInvoice> {
  RentalInvoiceRepository(super.dbHelper);

  @override
  String get tableName => DbConstants.tableRentalInvoices;

  @override
  Map<String, dynamic> toMap(RentalInvoice entity) => entity.toMap();

  @override
  RentalInvoice fromMap(Map<String, dynamic> map) => RentalInvoice.fromMap(map);

  /// Get invoices for a specific tenant
  Future<List<RentalInvoice>> getByTenant(String tenantId) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colTenantId} = ?',
      whereArgs: [tenantId],
      orderBy: '${DbConstants.colYear} ASC, ${DbConstants.colMonth} ASC',
    );
    return result.map(fromMap).toList();
  }

  /// Get invoices for a specific month/year (all tenants, with tenant info)
  Future<List<RentalInvoice>> getByMonth(int month, int year) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT i.*, 
             t.${DbConstants.colName} as tenant_name,
             t.${DbConstants.colRoomNumber} as tenant_room
      FROM ${DbConstants.tableRentalInvoices} i
      INNER JOIN ${DbConstants.tableTenants} t ON i.${DbConstants.colTenantId} = t.${DbConstants.colId}
      WHERE i.${DbConstants.colMonth} = ? AND i.${DbConstants.colYear} = ?
      ORDER BY t.${DbConstants.colRoomNumber} ASC
    ''', [month, year]);
    return result.map(fromMap).toList();
  }

  /// Get invoice for a specific tenant in a given month/year (for chaining meter readings)
  Future<RentalInvoice?> getForTenantAndMonth(
      String tenantId, int month, int year) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where:
          '${DbConstants.colTenantId} = ? AND ${DbConstants.colMonth} = ? AND ${DbConstants.colYear} = ?',
      whereArgs: [tenantId, month, year],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return fromMap(result.first);
  }

  /// Get the latest invoice for a tenant (to pre-fill electricity/water old readings)
  Future<RentalInvoice?> getLatestForTenant(String tenantId) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colTenantId} = ?',
      whereArgs: [tenantId],
      orderBy: '${DbConstants.colYear} DESC, ${DbConstants.colMonth} DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return fromMap(result.first);
  }

  /// Check if invoice exists for tenant in a given month/year
  Future<bool> existsForMonth(String tenantId, int month, int year) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colTenantId} = ? AND ${DbConstants.colMonth} = ? AND ${DbConstants.colYear} = ?',
      whereArgs: [tenantId, month, year],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Toggle paid status
  Future<int> togglePaid(String id, bool isPaid, {DateTime? paidAt}) async {
    final db = await database;
    return await db.update(
      tableName,
      {
        DbConstants.colIsPaid: isPaid ? 1 : 0,
        // Store paidAt when marking paid; clear it when reverting to unpaid
        DbConstants.colPaidAt: isPaid ? (paidAt ?? DateTime.now()).toIso8601String() : null,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Record the date rent was collected in advance (before meter readings are available).
  Future<int> markRentPaid(String id, DateTime paidAt) async {
    final db = await database;
    return await db.update(
      tableName,
      {
        DbConstants.colRentPaidAt: paidAt.toIso8601String(),
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Clear the rent_paid_at date (undo rent collection).
  Future<int> clearRentPaid(String id) async {
    final db = await database;
    return await db.update(
      tableName,
      {
        DbConstants.colRentPaidAt: null,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Get unpaid invoices count
  Future<int> countUnpaid() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE ${DbConstants.colIsPaid} = 0',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get total unpaid amount
  Future<double> totalUnpaidAmount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(${DbConstants.colTotalAmount}), 0) as total FROM $tableName WHERE ${DbConstants.colIsPaid} = 0',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// Sau khi cập nhật số điện nước của tháng M, tự động cập nhật [electricity_old]/[water_old]
  /// của các tháng pending phía sau (M+1, M+2...) theo chuỗi dây chuyền.
  ///
  /// [afterMonth]/[afterYear]: tháng vừa được cập nhật (lấy các tháng > tháng này)
  /// [elecVal]/[waterVal]: giá trị hiệu quả của tháng M (electricityNew nếu đã chốt, electricityOld nếu chưa)
  ///
  /// Dừng chuỗi khi gặp hóa đơn không phải pending (đã có số chính thức).
  Future<void> cascadeMeterOld(
    String tenantId,
    int afterMonth,
    int afterYear,
    double elecVal,
    double waterVal,
  ) async {
    // Lấy tất cả hóa đơn sau tháng/năm chỉ định, sắp xếp ASC
    final all = await getByTenant(tenantId);
    final subsequent = all.where((inv) {
      if (inv.year != afterYear) return inv.year > afterYear;
      return inv.month > afterMonth;
    }).toList();

    if (subsequent.isEmpty) return;

    final db = await database;
    final now = DateTime.now().toIso8601String();
    double propagatedElec = elecVal;
    double propagatedWater = waterVal;

    await db.transaction((txn) async {
      for (final inv in subsequent) {
        if (!inv.hasPendingMeterReading) break; // gặp tháng đã chốt → dừng

        await txn.update(
          tableName,
          {
            DbConstants.colElectricityOld: propagatedElec,
            DbConstants.colWaterOld: propagatedWater,
            DbConstants.colUpdatedAt: now,
          },
          where: '${DbConstants.colId} = ?',
          whereArgs: [inv.id],
        );

        // Giá trị truyền tiếp vấn đề là propagatedElec (tháng pending không có số mới thực)
      }
    });
  }

  /// Insert multiple invoices in a single transaction
  /// Returns list of invoices that were actually inserted (skips existing month/year)
  Future<List<RentalInvoice>> insertBatch(List<RentalInvoice> invoices) async {
    final db = await database;
    final inserted = <RentalInvoice>[];

    await db.transaction((txn) async {
      for (final invoice in invoices) {
        // Check for duplicate
        final existing = await txn.query(
          tableName,
          where: '${DbConstants.colTenantId} = ? AND ${DbConstants.colMonth} = ? AND ${DbConstants.colYear} = ?',
          whereArgs: [invoice.tenantId, invoice.month, invoice.year],
          limit: 1,
        );
        if (existing.isNotEmpty) continue; // skip month already invoiced

        await txn.insert(tableName, toMap(invoice));
        inserted.add(invoice);
      }
    });

    return inserted;
  }
}
