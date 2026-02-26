import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/logger.dart';
import '../database/database_helper.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import 'base_repository.dart';

/// Repository for order CRUD operations
class OrderRepository extends BaseRepository<Order> {
  OrderRepository(super.dbHelper);

  @override
  String get tableName => DbConstants.tableOrders;

  @override
  Map<String, dynamic> toMap(Order entity) => entity.toMap();

  @override
  Order fromMap(Map<String, dynamic> map) => Order.fromMap(map);

  /// Create order with items in a transaction
  Future<String> createOrderWithItems({
    required Order order,
    required List<OrderItem> items,
  }) async {
    try {
      final db = await database;
      
      // Validate items
      if (items.isEmpty) {
        throw ArgumentError('Order must have at least one item');
      }
      
      // Calculate total amount from items
      double totalAmount = 0;
      for (final item in items) {
        if (item.quantity <= 0 || item.unitPrice < 0) {
          throw ArgumentError('Invalid item: quantity must be positive and price non-negative');
        }
        totalAmount += item.subtotal;
      }
      
      if (totalAmount <= 0) {
        throw ArgumentError('Order total must be positive');
      }
      
      final orderWithTotal = order.copyWith(totalAmount: totalAmount);
      
      await db.transaction((txn) async {
        // Insert order
        await txn.insert(tableName, orderWithTotal.toMap());
        
        // Insert order items
        for (final item in items) {
          final itemWithOrderId = item.copyWith(orderId: order.id);
          await txn.insert(DbConstants.tableOrderItems, itemWithOrderId.toMap());
        }
      });
      
      AppLogger.database('Order created', details: 'Order ${order.id} with ${items.length} items');
      return order.id;
    } catch (e, stack) {
      AppLogger.error('Failed to create order', error: e, stackTrace: stack, tag: 'OrderRepository');
      throw Exception('Failed to create order: $e');
    }
  }

  /// Get order with items
  Future<Order?> getOrderWithItems(String orderId) async {
    final db = await database;
    
    // Get order with restaurant info
    final orderResult = await db.rawQuery('''
      SELECT 
        o.*,
        r.${DbConstants.colName} as restaurant_name,
        r.${DbConstants.colPhone} as restaurant_phone,
        r.${DbConstants.colAddress} as restaurant_address
      FROM ${DbConstants.tableOrders} o
      INNER JOIN ${DbConstants.tableRestaurants} r ON o.${DbConstants.colRestaurantId} = r.${DbConstants.colId}
      WHERE o.${DbConstants.colId} = ?
    ''', [orderId]);
    
    if (orderResult.isEmpty) return null;
    
    // Get order items
    final itemsResult = await db.query(
      DbConstants.tableOrderItems,
      where: '${DbConstants.colOrderId} = ?',
      whereArgs: [orderId],
    );
    
    final items = itemsResult.map((map) => OrderItem.fromMap(map)).toList();
    final order = Order.fromMap(orderResult.first);
    
    return order.copyWith(items: items);
  }

  /// Get order by ID (without items)
  Future<Order?> findById(String orderId) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${DbConstants.colId} = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    return result.isNotEmpty ? fromMap(result.first) : null;
  }

  /// Get orders by restaurant
  Future<List<Order>> getOrdersByRestaurant(
    String restaurantId, {
    OrderStatus? status,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    String where = '${DbConstants.colRestaurantId} = ?';
    List<Object> whereArgs = [restaurantId];
    
    if (status != null) {
      where += ' AND ${DbConstants.colStatus} = ?';
      whereArgs.add(status.value);
    }
    
    final result = await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy ?? '${DbConstants.colOrderDate} DESC',
      limit: limit,
      offset: offset,
    );
    return result.map(fromMap).toList();
  }

  /// Get orders by delivery date
  Future<List<Order>> getOrdersByDeliveryDate(DateTime date) async {
    final db = await database;
    final dateStr = AppDateUtils.toDbDate(date);
    
    final result = await db.rawQuery('''
      SELECT 
        o.*,
        r.${DbConstants.colName} as restaurant_name,
        r.${DbConstants.colPhone} as restaurant_phone,
        r.${DbConstants.colAddress} as restaurant_address
      FROM ${DbConstants.tableOrders} o
      INNER JOIN ${DbConstants.tableRestaurants} r ON o.${DbConstants.colRestaurantId} = r.${DbConstants.colId}
      WHERE o.${DbConstants.colDeliveryDate} = ?
        AND o.${DbConstants.colStatus} != 'cancelled'
      ORDER BY r.${DbConstants.colName} ASC
    ''', [dateStr]);
    
    return result.map(fromMap).toList();
  }

  /// Get orders by date range
  Future<List<Order>> getOrdersByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
  }) async {
    final db = await database;
    String where = '${DbConstants.colDeliveryDate} >= ? AND ${DbConstants.colDeliveryDate} <= ?';
    List<Object> whereArgs = [
      AppDateUtils.toDbDate(startDate),
      AppDateUtils.toDbDate(endDate),
    ];
    
    if (status != null) {
      where += ' AND ${DbConstants.colStatus} = ?';
      whereArgs.add(status.value);
    }
    
    if (paymentStatus != null) {
      where += ' AND ${DbConstants.colPaymentStatus} = ?';
      whereArgs.add(paymentStatus.value);
    }
    
    final result = await db.rawQuery('''
      SELECT 
        o.*,
        r.${DbConstants.colName} as restaurant_name,
        r.${DbConstants.colPhone} as restaurant_phone,
        r.${DbConstants.colAddress} as restaurant_address
      FROM ${DbConstants.tableOrders} o
      INNER JOIN ${DbConstants.tableRestaurants} r ON o.${DbConstants.colRestaurantId} = r.${DbConstants.colId}
      WHERE $where
      ORDER BY o.${DbConstants.colDeliveryDate} ASC, r.${DbConstants.colName} ASC
    ''', whereArgs);
    
    return result.map(fromMap).toList();
  }

  /// Get pending orders (not delivered or cancelled)
  Future<List<Order>> getPendingOrders() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        o.*,
        r.${DbConstants.colName} as restaurant_name,
        r.${DbConstants.colPhone} as restaurant_phone,
        r.${DbConstants.colAddress} as restaurant_address
      FROM ${DbConstants.tableOrders} o
      INNER JOIN ${DbConstants.tableRestaurants} r ON o.${DbConstants.colRestaurantId} = r.${DbConstants.colId}
      WHERE o.${DbConstants.colStatus} IN ('pending', 'confirmed', 'delivering')
      ORDER BY o.${DbConstants.colDeliveryDate} ASC, r.${DbConstants.colName} ASC
    ''');
    
    return result.map(fromMap).toList();
  }

  /// Get orders with debt (not fully paid)
  Future<List<Order>> getOrdersWithDebt() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        o.*,
        r.${DbConstants.colName} as restaurant_name,
        r.${DbConstants.colPhone} as restaurant_phone,
        r.${DbConstants.colAddress} as restaurant_address
      FROM ${DbConstants.tableOrders} o
      INNER JOIN ${DbConstants.tableRestaurants} r ON o.${DbConstants.colRestaurantId} = r.${DbConstants.colId}
      WHERE o.${DbConstants.colPaymentStatus} != 'paid'
        AND o.${DbConstants.colStatus} != 'cancelled'
      ORDER BY o.${DbConstants.colDeliveryDate} ASC, r.${DbConstants.colName} ASC
    ''');
    
    return result.map(fromMap).toList();
  }

  /// Get the latest full-settlement date for a restaurant.
  /// Returns the max(updated_at) of orders with payment_status = 'paid' for this restaurant.
  /// Returns null if no paid orders exist.
  Future<DateTime?> getLastSettlementDate(String restaurantId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT MAX(${DbConstants.colUpdatedAt}) as last_settled
      FROM ${DbConstants.tableOrders}
      WHERE ${DbConstants.colRestaurantId} = ?
        AND ${DbConstants.colPaymentStatus} = 'paid'
        AND ${DbConstants.colStatus} != 'cancelled'
    ''', [restaurantId]);
    final raw = result.first['last_settled'];
    if (raw == null) return null;
    return AppDateUtils.parseDbDateTime(raw.toString());
  }

  /// Update order status
  Future<int> updateStatus(String orderId, OrderStatus status) async {
    final db = await database;
    return await db.update(
      tableName,
      {
        DbConstants.colStatus: status.value,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [orderId],
    );
  }

  /// Update paid amount and recalculate payment status
  Future<int> updatePaidAmount(String orderId, double paidAmount) async {
    final db = await database;
    
    // Get total amount first
    final orderResult = await db.query(
      tableName,
      columns: [DbConstants.colTotalAmount],
      where: '${DbConstants.colId} = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    
    if (orderResult.isEmpty) return 0;
    
    final totalAmount = (orderResult.first[DbConstants.colTotalAmount] as num).toDouble();
    final paymentStatus = PaymentStatusExtension.calculate(totalAmount, paidAmount);
    
    return await db.update(
      tableName,
      {
        DbConstants.colPaidAmount: paidAmount,
        DbConstants.colPaymentStatus: paymentStatus.value,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [orderId],
    );
  }

  /// Add payment to order
  Future<int> addPayment(String orderId, double amount) async {
    try {
      final db = await database;
      
      // Validate amount
      if (amount <= 0) {
        throw ArgumentError('Payment amount must be positive');
      }
      
      // Get current paid amount
      final orderResult = await db.query(
        tableName,
        columns: [DbConstants.colTotalAmount, DbConstants.colPaidAmount],
        where: '${DbConstants.colId} = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      
      if (orderResult.isEmpty) {
        throw StateError('Order not found: $orderId');
      }
      
      final totalAmount = (orderResult.first[DbConstants.colTotalAmount] as num).toDouble();
      final currentPaid = (orderResult.first[DbConstants.colPaidAmount] as num).toDouble();
      final debt = totalAmount - currentPaid;
      
      // Cap payment at remaining debt to prevent overpayment
      final actualPayment = amount > debt ? debt : amount;
      final newPaidAmount = currentPaid + actualPayment;
      final paymentStatus = PaymentStatusExtension.calculate(totalAmount, newPaidAmount);
      
      if (actualPayment < amount) {
        AppLogger.warning('Payment capped: requested=${amount.toStringAsFixed(0)}, actual=${actualPayment.toStringAsFixed(0)}', tag: 'OrderRepository');
      }
    
      final result = await db.update(
        tableName,
        {
          DbConstants.colPaidAmount: newPaidAmount,
          DbConstants.colPaymentStatus: paymentStatus.value,
          DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [orderId],
      );
      
      AppLogger.payment('Payment added', amount: actualPayment);
      AppLogger.database('Payment recorded', details: 'Order $orderId: ${currentPaid.toStringAsFixed(0)} -> ${newPaidAmount.toStringAsFixed(0)} (status: ${paymentStatus.value})');
      return result;
    } catch (e, stack) {
      AppLogger.error('Failed to add payment', error: e, stackTrace: stack, tag: 'OrderRepository');
      throw Exception('Failed to add payment: $e');
    }
  }

  /// Update order items and recalculate total
  Future<void> updateOrderItems(String orderId, List<OrderItem> items) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // Delete existing items
      await txn.delete(
        DbConstants.tableOrderItems,
        where: '${DbConstants.colOrderId} = ?',
        whereArgs: [orderId],
      );
      
      // Insert new items and calculate total
      double totalAmount = 0;
      for (final item in items) {
        final itemWithOrderId = item.copyWith(orderId: orderId);
        await txn.insert(DbConstants.tableOrderItems, itemWithOrderId.toMap());
        totalAmount += item.subtotal;
      }
      
      // Update order total
      await txn.update(
        tableName,
        {
          DbConstants.colTotalAmount: totalAmount,
          DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [orderId],
      );
    });
  }

  /// Update order info and items in a single transaction
  Future<void> updateOrderWithItems({
    required String orderId,
    required DateTime deliveryDate,
    required OrderSession session,
    required List<OrderItem> items,
    String? notes,
  }) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // Update order info
      final updateData = {
        DbConstants.colDeliveryDate: AppDateUtils.toDbDate(deliveryDate),
        DbConstants.colSession: session.value,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      };
      
      // Add notes if provided
      if (notes != null) {
        updateData[DbConstants.colNotes] = notes;
      }
      
      await txn.update(
        tableName,
        updateData,
        where: '${DbConstants.colId} = ?',
        whereArgs: [orderId],
      );

      // Delete existing items
      await txn.delete(
        DbConstants.tableOrderItems,
        where: '${DbConstants.colOrderId} = ?',
        whereArgs: [orderId],
      );
      
      // Insert new items and calculate total
      double totalAmount = 0;
      for (final item in items) {
        final itemWithOrderId = item.copyWith(orderId: orderId);
        await txn.insert(DbConstants.tableOrderItems, itemWithOrderId.toMap());
        totalAmount += item.subtotal;
      }
      
      // Update order total
      await txn.update(
        tableName,
        {
          DbConstants.colTotalAmount: totalAmount,
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [orderId],
      );
    });
    
    AppLogger.database('Order updated', details: 'Order $orderId with ${items.length} items');
  }

  /// Get order items
  Future<List<OrderItem>> getOrderItems(String orderId) async {
    final db = await database;
    final result = await db.query(
      DbConstants.tableOrderItems,
      where: '${DbConstants.colOrderId} = ?',
      whereArgs: [orderId],
    );
    return result.map((map) => OrderItem.fromMap(map)).toList();
  }

  /// Count orders by status
  Future<int> countByStatus(OrderStatus status) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE ${DbConstants.colStatus} = ?',
      [status.value],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Count orders for today's delivery
  Future<int> countTodayDeliveries() async {
    final db = await database;
    final today = AppDateUtils.toDbDate(DateTime.now());
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM $tableName 
      WHERE ${DbConstants.colDeliveryDate} = ? 
        AND ${DbConstants.colStatus} NOT IN ('delivered', 'cancelled')
    ''', [today]);
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get total debt amount
  Future<double> getTotalDebt() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(${DbConstants.colTotalAmount} - ${DbConstants.colPaidAmount}), 0) as total_debt
      FROM $tableName 
      WHERE ${DbConstants.colStatus} != 'cancelled'
    ''');
    return (result.first['total_debt'] as num?)?.toDouble() ?? 0;
  }

  /// Get debt amount by restaurant
  Future<double> getDebtByRestaurant(String restaurantId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(${DbConstants.colTotalAmount} - ${DbConstants.colPaidAmount}), 0) as total_debt
      FROM $tableName 
      WHERE ${DbConstants.colRestaurantId} = ?
        AND ${DbConstants.colStatus} != 'cancelled'
    ''', [restaurantId]);
    return (result.first['total_debt'] as num?)?.toDouble() ?? 0;
  }

  /// Get total ordered quantity for each product (only pending/confirmed/delivering orders)
  Future<Map<String, double>> getTotalOrderedQuantities({DateTime? untilDate}) async {
    final db = await database;
    
    String whereClause = "o.${DbConstants.colStatus} NOT IN ('delivered', 'cancelled')";
    List<dynamic> whereArgs = [];
    
    if (untilDate != null) {
      whereClause += " AND o.${DbConstants.colDeliveryDate} <= ?";
      whereArgs.add(AppDateUtils.toDbDate(untilDate));
    }
    
    final result = await db.rawQuery('''
      SELECT 
        oi.${DbConstants.colProductId},
        SUM(oi.${DbConstants.colQuantity}) as total_quantity
      FROM ${DbConstants.tableOrderItems} oi
      INNER JOIN ${DbConstants.tableOrders} o 
        ON oi.${DbConstants.colOrderId} = o.${DbConstants.colId}
      WHERE $whereClause
      GROUP BY oi.${DbConstants.colProductId}
    ''', whereArgs);
    
    final Map<String, double> quantities = {};
    for (final row in result) {
      final productId = row[DbConstants.colProductId] as String;
      final quantity = (row['total_quantity'] as num?)?.toDouble() ?? 0;
      quantities[productId] = quantity;
    }
    return quantities;
  }

  /// Get sales summary for date range
  Future<Map<String, dynamic>> getSalesSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_orders,
        COALESCE(SUM(${DbConstants.colTotalAmount}), 0) as total_sales,
        COALESCE(SUM(${DbConstants.colPaidAmount}), 0) as total_paid,
        COALESCE(SUM(${DbConstants.colTotalAmount} - ${DbConstants.colPaidAmount}), 0) as total_debt
      FROM $tableName 
      WHERE ${DbConstants.colOrderDate} >= ? 
        AND ${DbConstants.colOrderDate} <= ?
        AND ${DbConstants.colStatus} != 'cancelled'
    ''', [AppDateUtils.toDbDate(startDate), AppDateUtils.toDbDate(endDate)]);
    
    return result.first;
  }

  /// Create a manual debt entry (order without items)
  Future<String> createManualDebt({
    required String restaurantId,
    required DateTime date,
    required double amount,
    String? notes,
  }) async {
    try {
      final db = await database;
      final order = Order.create(
        restaurantId: restaurantId,
        orderDate: date,
        deliveryDate: date,
        totalAmount: amount,
        notes: notes ?? 'Nợ cũ',
      );
      
      // Insert as delivered + unpaid
      final map = order.toMap();
      map[DbConstants.colStatus] = OrderStatus.delivered.value;
      map[DbConstants.colTotalAmount] = amount;
      map[DbConstants.colPaidAmount] = 0.0;
      map[DbConstants.colPaymentStatus] = PaymentStatus.unpaid.value;
      
      await db.insert(tableName, map);
      AppLogger.database('Manual debt created', details: 'Order ${order.id} for $amount');
      return order.id;
    } catch (e, stack) {
      AppLogger.error('Failed to create manual debt', error: e, stackTrace: stack, tag: 'OrderRepository');
      throw Exception('Failed to create manual debt: $e');
    }
  }

  /// Update a manual debt entry
  Future<void> updateManualDebt({
    required String orderId,
    required DateTime date,
    required double amount,
    String? notes,
  }) async {
    try {
      final db = await database;
      await db.update(
        tableName,
        {
          DbConstants.colOrderDate: AppDateUtils.toDbDate(date),
          DbConstants.colDeliveryDate: AppDateUtils.toDbDate(date),
          DbConstants.colTotalAmount: amount,
          DbConstants.colNotes: notes,
          DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [orderId],
      );
      AppLogger.database('Manual debt updated', details: 'Order $orderId to $amount');
    } catch (e, stack) {
      AppLogger.error('Failed to update manual debt', error: e, stackTrace: stack, tag: 'OrderRepository');
      throw Exception('Failed to update manual debt: $e');
    }
  }

  /// Get monthly revenue stats for a restaurant
  /// Returns list of maps: [{'month': '2025-01', 'total_amount': 1000000, 'order_count': 5}, ...]
  Future<List<Map<String, dynamic>>> getMonthlyRevenue(String restaurantId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        strftime('%Y-%m', ${DbConstants.colDeliveryDate}) as month,
        SUM(${DbConstants.colTotalAmount}) as total_amount,
        COUNT(*) as order_count
      FROM ${DbConstants.tableOrders}
      WHERE ${DbConstants.colRestaurantId} = ?
        AND ${DbConstants.colStatus} != 'cancelled'
      GROUP BY strftime('%Y-%m', ${DbConstants.colDeliveryDate})
      ORDER BY month DESC
    ''', [restaurantId]);
    return result;
  }

  /// Get all unpaid orders (unpaid + partial) with restaurant info
  Future<List<Order>> getUnpaidOrders() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        o.*,
        r.${DbConstants.colName} as restaurant_name,
        r.${DbConstants.colPhone} as restaurant_phone,
        r.${DbConstants.colAddress} as restaurant_address
      FROM ${DbConstants.tableOrders} o
      INNER JOIN ${DbConstants.tableRestaurants} r 
        ON o.${DbConstants.colRestaurantId} = r.${DbConstants.colId}
      WHERE o.${DbConstants.colPaymentStatus} IN ('unpaid', 'partial')
        AND o.${DbConstants.colStatus} != 'cancelled'
      ORDER BY o.${DbConstants.colDeliveryDate} ASC, r.${DbConstants.colName} ASC
    ''');
    
    // Load items for each order
    final orders = <Order>[];
    for (final orderMap in result) {
      final order = fromMap(orderMap);
      final items = await getOrderItems(order.id);
      orders.add(order.copyWith(items: items));
    }
    
    return orders;
  }
}
