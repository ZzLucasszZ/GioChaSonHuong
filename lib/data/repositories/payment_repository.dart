import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';
import '../database/database_helper.dart';
import '../models/order.dart';
import '../models/payment.dart';
import 'base_repository.dart';

/// Repository for payment CRUD operations
class PaymentRepository extends BaseRepository<Payment> {
  PaymentRepository(super.dbHelper);

  @override
  String get tableName => DbConstants.tablePayments;

  @override
  Map<String, dynamic> toMap(Payment entity) => entity.toMap();

  @override
  Payment fromMap(Map<String, dynamic> map) => Payment.fromMap(map);

  /// Create payment record (order's paid amount is updated separately by OrderRepository.addPayment)
  Future<Payment> createPaymentForOrder({
    required String orderId,
    required String restaurantId,
    required double amount,
    required PaymentMethod method,
    DateTime? paymentDate,
    String? notes,
  }) async {
    final db = await database;
    
    final payment = Payment.create(
      restaurantId: restaurantId,
      orderId: orderId,
      amount: amount,
      method: method,
      paymentDate: paymentDate,
      notes: notes,
    );
    
    // Only insert payment record — order's paidAmount is updated by OrderRepository.addPayment()
    await db.insert(tableName, payment.toMap());
    
    return payment;
  }

  /// Create a general payment for restaurant (not linked to specific order)
  Future<Payment> createGeneralPayment({
    required String restaurantId,
    required double amount,
    required PaymentMethod method,
    DateTime? paymentDate,
    String? notes,
  }) async {
    final payment = Payment.create(
      restaurantId: restaurantId,
      amount: amount,
      method: method,
      paymentDate: paymentDate,
      notes: notes,
    );
    
    await insert(payment);
    return payment;
  }

  /// Get payments by restaurant
  Future<List<Payment>> getByRestaurant(
    String restaurantId, {
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        p.*,
        r.${DbConstants.colName} as restaurant_name
      FROM ${DbConstants.tablePayments} p
      INNER JOIN ${DbConstants.tableRestaurants} r ON p.${DbConstants.colRestaurantId} = r.${DbConstants.colId}
      WHERE p.${DbConstants.colRestaurantId} = ?
      ORDER BY p.${DbConstants.colPaymentDate} DESC
      ${limit != null ? 'LIMIT $limit' : ''}
      ${offset != null ? 'OFFSET $offset' : ''}
    ''', [restaurantId]);
    
    return result.map(fromMap).toList();
  }

  /// Get payments by order
  Future<List<Payment>> getByOrder(String orderId) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colOrderId} = ?',
      whereArgs: [orderId],
      orderBy: '${DbConstants.colPaymentDate} DESC',
    );
    return result.map(fromMap).toList();
  }

  /// Get payments by date range
  Future<List<Payment>> getByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? restaurantId,
    PaymentMethod? method,
  }) async {
    final db = await database;
    
    String where = 'p.${DbConstants.colPaymentDate} >= ? AND p.${DbConstants.colPaymentDate} <= ?';
    List<Object> whereArgs = [
      AppDateUtils.toDbDate(startDate),
      AppDateUtils.toDbDate(endDate),
    ];
    
    if (restaurantId != null) {
      where += ' AND p.${DbConstants.colRestaurantId} = ?';
      whereArgs.add(restaurantId);
    }
    
    if (method != null) {
      where += ' AND p.${DbConstants.colMethod} = ?';
      whereArgs.add(method.value);
    }
    
    final result = await db.rawQuery('''
      SELECT 
        p.*,
        r.${DbConstants.colName} as restaurant_name
      FROM ${DbConstants.tablePayments} p
      INNER JOIN ${DbConstants.tableRestaurants} r ON p.${DbConstants.colRestaurantId} = r.${DbConstants.colId}
      WHERE $where
      ORDER BY p.${DbConstants.colPaymentDate} DESC
    ''', whereArgs);
    
    return result.map(fromMap).toList();
  }

  /// Get total payments by restaurant
  Future<double> getTotalByRestaurant(String restaurantId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(${DbConstants.colAmount}), 0) as total
      FROM $tableName
      WHERE ${DbConstants.colRestaurantId} = ?
    ''', [restaurantId]);
    
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// Get general/reconciliation payment totals grouped by restaurant
  /// Only counts payments where order_id IS NULL (not reflected in order.paidAmount)
  Future<Map<String, double>> getGeneralPaidByRestaurant() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT ${DbConstants.colRestaurantId}, COALESCE(SUM(${DbConstants.colAmount}), 0) as total
      FROM $tableName
      WHERE ${DbConstants.colOrderId} IS NULL
      GROUP BY ${DbConstants.colRestaurantId}
    ''');
    
    final map = <String, double>{};
    for (final row in result) {
      final restaurantId = row[DbConstants.colRestaurantId] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      if (total > 0) map[restaurantId] = total;
    }
    return map;
  }

  /// Get total payments for date range
  Future<double> getTotalByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(${DbConstants.colAmount}), 0) as total
      FROM $tableName
      WHERE ${DbConstants.colPaymentDate} >= ? AND ${DbConstants.colPaymentDate} <= ?
    ''', [AppDateUtils.toDbDate(startDate), AppDateUtils.toDbDate(endDate)]);
    
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// Get payment summary by method for date range
  Future<Map<PaymentMethod, double>> getSummaryByMethod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        ${DbConstants.colMethod},
        COALESCE(SUM(${DbConstants.colAmount}), 0) as total
      FROM $tableName
      WHERE ${DbConstants.colPaymentDate} >= ? AND ${DbConstants.colPaymentDate} <= ?
      GROUP BY ${DbConstants.colMethod}
    ''', [AppDateUtils.toDbDate(startDate), AppDateUtils.toDbDate(endDate)]);
    
    final summary = <PaymentMethod, double>{};
    for (final row in result) {
      final method = PaymentMethodExtension.fromString(row[DbConstants.colMethod] as String);
      summary[method] = (row['total'] as num?)?.toDouble() ?? 0;
    }
    
    return summary;
  }

  /// Update a payment record (amount, date, notes) and adjust order if linked
  Future<Payment?> updatePaymentRecord(
    String paymentId, {
    double? newAmount,
    DateTime? newPaymentDate,
    String? newNotes,
  }) async {
    final db = await database;

    // Get existing payment
    final paymentResult = await db.query(
      tableName,
      where: '${DbConstants.colId} = ?',
      whereArgs: [paymentId],
      limit: 1,
    );
    if (paymentResult.isEmpty) return null;

    final oldPayment = fromMap(paymentResult.first);
    final amountChanged = newAmount != null && newAmount != oldPayment.amount;

    await db.transaction((txn) async {
      // If linked to an order and amount changed, adjust order's paidAmount
      if (amountChanged && oldPayment.orderId != null) {
        final orderResult = await txn.query(
          DbConstants.tableOrders,
          columns: [DbConstants.colTotalAmount, DbConstants.colPaidAmount],
          where: '${DbConstants.colId} = ?',
          whereArgs: [oldPayment.orderId],
          limit: 1,
        );
        if (orderResult.isNotEmpty) {
          final totalAmount = (orderResult.first[DbConstants.colTotalAmount] as num).toDouble();
          final currentPaid = (orderResult.first[DbConstants.colPaidAmount] as num).toDouble();
          final adjustedPaid = (currentPaid - oldPayment.amount + newAmount!).clamp(0.0, totalAmount);
          final paymentStatus = PaymentStatusExtension.calculate(totalAmount, adjustedPaid);

          await txn.update(
            DbConstants.tableOrders,
            {
              DbConstants.colPaidAmount: adjustedPaid,
              DbConstants.colPaymentStatus: paymentStatus.value,
              DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
            },
            where: '${DbConstants.colId} = ?',
            whereArgs: [oldPayment.orderId],
          );
        }
      }

      // Update payment record
      final updates = <String, dynamic>{};
      if (newAmount != null) updates[DbConstants.colAmount] = newAmount;
      if (newPaymentDate != null) updates[DbConstants.colPaymentDate] = AppDateUtils.toDbDate(newPaymentDate);
      if (newNotes != null) updates[DbConstants.colNotes] = newNotes;

      if (updates.isNotEmpty) {
        await txn.update(
          tableName,
          updates,
          where: '${DbConstants.colId} = ?',
          whereArgs: [paymentId],
        );
      }
    });

    // Return updated payment
    final updatedResult = await db.query(
      tableName,
      where: '${DbConstants.colId} = ?',
      whereArgs: [paymentId],
      limit: 1,
    );
    return updatedResult.isNotEmpty ? fromMap(updatedResult.first) : null;
  }

  /// Delete payment and update order's paid amount
  Future<int> deletePaymentForOrder(String paymentId) async {
    final db = await database;
    
    // Get payment details first
    final paymentResult = await db.query(
      tableName,
      where: '${DbConstants.colId} = ?',
      whereArgs: [paymentId],
      limit: 1,
    );
    
    if (paymentResult.isEmpty) return 0;
    
    final payment = fromMap(paymentResult.first);
    
    int result = 0;
    await db.transaction((txn) async {
      // Delete payment
      result = await txn.delete(
        tableName,
        where: '${DbConstants.colId} = ?',
        whereArgs: [paymentId],
      );
      
      // Update order's paid amount if linked to an order
      if (payment.orderId != null) {
        final orderResult = await txn.query(
          DbConstants.tableOrders,
          columns: [DbConstants.colTotalAmount, DbConstants.colPaidAmount],
          where: '${DbConstants.colId} = ?',
          whereArgs: [payment.orderId],
          limit: 1,
        );
        
        if (orderResult.isNotEmpty) {
          final totalAmount = (orderResult.first[DbConstants.colTotalAmount] as num).toDouble();
          final currentPaid = (orderResult.first[DbConstants.colPaidAmount] as num).toDouble();
          final newPaidAmount = (currentPaid - payment.amount).clamp(0.0, double.infinity);
          final paymentStatus = PaymentStatusExtension.calculate(totalAmount, newPaidAmount);
          
          await txn.update(
            DbConstants.tableOrders,
            {
              DbConstants.colPaidAmount: newPaidAmount,
              DbConstants.colPaymentStatus: paymentStatus.value,
              DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
            },
            where: '${DbConstants.colId} = ?',
            whereArgs: [payment.orderId],
          );
        }
      }
    });
    
    return result;
  }

  /// Get recent payments with restaurant info
  Future<List<Payment>> getRecent({int limit = 50}) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        p.*,
        r.${DbConstants.colName} as restaurant_name
      FROM ${DbConstants.tablePayments} p
      INNER JOIN ${DbConstants.tableRestaurants} r ON p.${DbConstants.colRestaurantId} = r.${DbConstants.colId}
      ORDER BY p.${DbConstants.colCreatedAt} DESC
      LIMIT ?
    ''', [limit]);
    
    return result.map(fromMap).toList();
  }
}
