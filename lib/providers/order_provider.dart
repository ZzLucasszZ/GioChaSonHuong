import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/utils/error_dialog.dart';
import '../core/utils/logger.dart';
import '../data/database/database_helper.dart';
import '../data/models/order.dart';
import '../data/models/order_item.dart';
import '../data/models/payment.dart';
import '../data/repositories/inventory_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/repositories/payment_repository.dart';

/// Provider for order state management
class OrderProvider extends ChangeNotifier {
  final OrderRepository _repository;
  final PaymentRepository _paymentRepository;
  final InventoryRepository _inventoryRepository;

  List<Order> _orders = [];
  Order? _currentOrder;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _error;

  OrderProvider(DatabaseHelper dbHelper)
      : _repository = OrderRepository(dbHelper),
        _paymentRepository = PaymentRepository(dbHelper),
        _inventoryRepository = InventoryRepository(dbHelper);

  // Getters
  List<Order> get orders => _orders;
  Order? get currentOrder => _currentOrder;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  String? get error => _error;
  OrderRepository get repository => _repository;

  /// Set selected date and reload orders
  Future<void> setSelectedDate(DateTime date, String restaurantId) async {
    _selectedDate = date;
    notifyListeners();
    await loadOrdersForDate(restaurantId, date);
  }

  /// Load orders for a specific restaurant and date
  Future<void> loadOrdersForDate(String restaurantId, DateTime date) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('Loading orders for restaurant $restaurantId on ${date.toString().substring(0, 10)}', tag: 'OrderProvider');
      final ordersWithoutItems = await _repository.getOrdersByDateRange(
        startDate: date,
        endDate: date,
      );
      // Filter by restaurant
      final filteredOrders = ordersWithoutItems.where((o) => o.restaurantId == restaurantId).toList();
      
      // Load items for each order
      _orders = [];
      for (final order in filteredOrders) {
        final items = await _repository.getOrderItems(order.id);
        _orders.add(order.copyWith(items: items));
      }
      
      AppLogger.info('Loaded ${_orders.length} orders', tag: 'OrderProvider');
      _error = null;
    } catch (e) {
      _error = 'Không thể tải đơn hàng: $e';
      AppLogger.error('Failed to load orders', error: e, tag: 'OrderProvider');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load orders by restaurant
  Future<void> loadOrdersByRestaurant(String restaurantId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _orders = await _repository.getOrdersByRestaurant(restaurantId);
      _error = null;
    } catch (e) {
      _error = 'Không thể tải đơn hàng: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create order with items
  Future<Order?> createOrder(
    BuildContext context, {
    required String restaurantId,
    required DateTime orderDate,
    required DateTime deliveryDate,
    required List<OrderItem> items,
    String? notes,
    OrderSession? session,
  }) async {
    try {
      AppLogger.repository('Creating order', details: '${items.length} items');
      
      final order = Order.create(
        restaurantId: restaurantId,
        orderDate: orderDate,
        deliveryDate: deliveryDate,
        notes: notes,
        session: session,
      );

      await _repository.createOrderWithItems(order: order, items: items);
      AppLogger.success('Order created successfully', tag: 'OrderProvider');

      // Update selected date to delivery date and reload orders
      _selectedDate = deliveryDate;
      await loadOrdersForDate(restaurantId, deliveryDate);

      return order;
    } catch (e, stack) {
      AppLogger.error('Failed to create order', error: e, stackTrace: stack, tag: 'OrderProvider');
      _error = 'Không thể tạo đơn hàng: ${e.toString().replaceAll('Exception: ', '')}';
      notifyListeners();
      
      // Show error dialog to user
      if (context.mounted) {
        await ErrorDialog.show(
          context,
          title: 'Lỗi tạo đơn hàng',
          message: _error!,
          error: e,
          stackTrace: stack,
        );
      }
      return null;
    }
  }

  /// Get order with items
  Future<Order?> getOrderWithItems(String orderId) async {
    try {
      _currentOrder = await _repository.getOrderWithItems(orderId);
      notifyListeners();
      return _currentOrder;
    } catch (e) {
      _error = 'Không thể tải chi tiết đơn hàng: $e';
      notifyListeners();
      return null;
    }
  }

  /// Get order by ID (without items)
  Future<Order?> getOrderById(String orderId) async {
    try {
      return await _repository.findById(orderId);
    } catch (e) {
      _error = 'Không thể tải đơn hàng: $e';
      notifyListeners();
      return null;
    }
  }

  /// Get order items
  Future<List<OrderItem>> getOrderItems(String orderId) async {
    try {
      return await _repository.getOrderItems(orderId);
    } catch (e) {
      _error = 'Không thể tải chi tiết sản phẩm: $e';
      notifyListeners();
      return [];
    }
  }

  /// Update order status
  /// When marking as delivered, automatically deduct stock for order items
  /// (skipped if order is already delivered to avoid double deduction).
  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      // Check current status to guard against double stock deduction
      final currentOrder = await _repository.findById(orderId);
      final alreadyDelivered = currentOrder?.status == OrderStatus.delivered;

      await _repository.updateStatus(orderId, status);

      // Deduct stock when newly marked as delivered
      if (status == OrderStatus.delivered && !alreadyDelivered) {
        await _deductStockForOrder(orderId);
      }

      // Update in list
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(status: status);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Không thể cập nhật trạng thái: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update payment amount (updates order's paidAmount only, no payment record).
  /// When the order becomes fully paid, it is automatically marked as delivered
  /// and inventory is deducted (unless already delivered).
  Future<bool> updatePayment(BuildContext context, String orderId, double amount, {DateTime? paymentDate, String? notes}) async {
    try {
      AppLogger.payment('Processing payment', amount: amount);

      // Snapshot current status before payment
      final orderBefore = await _repository.findById(orderId);
      final wasDelivered = orderBefore?.status == OrderStatus.delivered;

      await _repository.addPayment(orderId, amount);

      AppLogger.success('Payment processed successfully', tag: 'OrderProvider');

      // Reload order to check new payment status
      final updatedOrder = await _repository.findById(orderId);

      if (updatedOrder != null) {
        // Auto-mark as delivered + deduct stock when fully paid
        if (updatedOrder.paymentStatus == PaymentStatus.paid && !wasDelivered) {
          await _repository.updateStatus(orderId, OrderStatus.delivered);
          await _deductStockForOrder(orderId);
          AppLogger.info('Order auto-delivered & stock deducted on full payment', tag: 'OrderProvider');
        }

        // Re-fetch to get final state (with delivered status)
        final finalOrder = await _repository.findById(orderId);
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index != -1 && finalOrder != null) {
          _orders[index] = finalOrder;
          notifyListeners();
        }
      }

      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to process payment', error: e, stackTrace: stack, tag: 'OrderProvider');
      _error = 'Không thể cập nhật thanh toán: ${e.toString().replaceAll('Exception: ', '')}';
      notifyListeners();
      
      // Show error dialog to user
      if (context.mounted) {
        await ErrorDialog.show(
          context,
          title: 'Lỗi thanh toán',
          message: _error!,
          error: e,
          stackTrace: stack,
        );
      }
      return false;
    }
  }

  /// Get payment history for a restaurant
  Future<List<Payment>> getPaymentsByRestaurant(String restaurantId) async {
    return await _paymentRepository.getByRestaurant(restaurantId);
  }

  /// Get general/reconciliation payment totals grouped by restaurant ID
  Future<Map<String, double>> getGeneralPaidByRestaurant() async {
    return await _paymentRepository.getGeneralPaidByRestaurant();
  }

  /// Edit an existing payment record (amount, date, notes)
  Future<bool> editPaymentRecord(
    String paymentId, {
    double? newAmount,
    DateTime? newPaymentDate,
    String? newNotes,
  }) async {
    try {
      final result = await _paymentRepository.updatePaymentRecord(
        paymentId,
        newAmount: newAmount,
        newPaymentDate: newPaymentDate,
        newNotes: newNotes,
      );
      if (result != null) {
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Failed to edit payment', error: e, tag: 'OrderProvider');
      return false;
    }
  }

  /// Delete a payment record and reverse order paidAmount if linked
  Future<bool> deletePaymentRecord(String paymentId) async {
    try {
      final result = await _paymentRepository.deletePaymentForOrder(paymentId);
      if (result > 0) {
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Failed to delete payment', error: e, tag: 'OrderProvider');
      return false;
    }
  }

  /// Insert a payment record WITHOUT updating order paidAmount
  /// Used for reconciling missing payment records
  Future<bool> insertPaymentRecordOnly({
    required String restaurantId,
    required double amount,
    required DateTime paymentDate,
    String? notes,
  }) async {
    try {
      await _paymentRepository.createGeneralPayment(
        restaurantId: restaurantId,
        amount: amount,
        method: PaymentMethod.cash,
        paymentDate: paymentDate,
        notes: notes ?? 'Bản ghi bổ sung',
      );
      AppLogger.success('Payment record inserted (reconciliation)', tag: 'OrderProvider');
      return true;
    } catch (e) {
      AppLogger.error('Failed to insert payment record', error: e, tag: 'OrderProvider');
      return false;
    }
  }

  /// Get monthly revenue stats for a restaurant
  Future<List<Map<String, dynamic>>> getMonthlyRevenue(String restaurantId) async {
    return await _repository.getMonthlyRevenue(restaurantId);
  }

  /// Get the latest full-settlement date for a restaurant
  Future<DateTime?> getLastSettlementDate(String restaurantId) async {
    return await _repository.getLastSettlementDate(restaurantId);
  }

  /// Load all unpaid orders (unpaid + partial)
  Future<List<Order>> loadUnpaidOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final orders = await _repository.getUnpaidOrders();
      _isLoading = false;
      notifyListeners();
      return orders;
    } catch (e) {
      _error = 'Không thể tải công nợ: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Update order items
  Future<void> updateOrderItems(String orderId, List<OrderItem> items) async {
    try {
      await _repository.updateOrderItems(orderId, items);
      
      // Update in local list
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(items: items);
      }
      
      // Update current order if it matches
      if (_currentOrder?.id == orderId) {
        _currentOrder = _currentOrder!.copyWith(items: items);
      }
      
      notifyListeners();
    } catch (e) {
      _error = 'Không thể cập nhật sản phẩm: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Update order with items (for edit order)
  Future<void> updateOrderWithItems({
    required String orderId,
    required DateTime deliveryDate,
    required OrderSession session,
    required List<OrderItem> items,
    String? notes,
  }) async {
    try {
      await _repository.updateOrderWithItems(
        orderId: orderId,
        deliveryDate: deliveryDate,
        session: session,
        items: items,
        notes: notes,
      );
      
      // Clear cache to force reload
      _orders.clear();
      _currentOrder = null;
      
      notifyListeners();
      AppLogger.success('Order updated successfully', tag: 'OrderProvider');
    } catch (e, stack) {
      AppLogger.error('Failed to update order', error: e, stackTrace: stack, tag: 'OrderProvider');
      _error = 'Không thể cập nhật đơn hàng: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Create a manual debt entry (for orders before using the app)
  Future<bool> createManualDebt({
    required String restaurantId,
    required DateTime date,
    required double amount,
    String? notes,
  }) async {
    try {
      await _repository.createManualDebt(
        restaurantId: restaurantId,
        date: date,
        amount: amount,
        notes: notes,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Không thể thêm nợ: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update a manual debt entry
  Future<bool> updateManualDebt({
    required String orderId,
    required DateTime date,
    required double amount,
    String? notes,
  }) async {
    try {
      await _repository.updateManualDebt(
        orderId: orderId,
        date: date,
        amount: amount,
        notes: notes,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Không thể cập nhật nợ: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete a manual debt / order
  Future<bool> deleteManualDebt(String orderId) async {
    try {
      await _repository.delete(orderId);
      _orders.removeWhere((o) => o.id == orderId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Không thể xóa nợ: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete order
  Future<bool> deleteOrder(String orderId, String restaurantId) async {
    try {
      await _repository.delete(orderId);
      _orders.removeWhere((o) => o.id == orderId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Không thể xóa đơn hàng: $e';
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear current order
  void clearCurrentOrder() {
    _currentOrder = null;
    notifyListeners();
  }

  // ─── Internal helpers ───────────────────────────────────────────────

  /// Deduct inventory stock for every item in the given order.
  /// Uses delivery-safe stock-out (allows negative stock).
  /// Silently skips items whose product no longer exists.
  Future<void> _deductStockForOrder(String orderId) async {
    try {
      final items = await _repository.getOrderItems(orderId);
      for (final item in items) {
        try {
          await _inventoryRepository.recordDeliveryStockOut(
            productId: item.productId,
            quantity: item.quantity,
            referenceId: orderId,
            notes: 'Tự động trừ kho khi giao/thanh toán đơn $orderId',
          );
          AppLogger.database(
            'Stock deducted',
            details: '${item.productName}: -${item.quantity}',
          );
        } catch (e) {
          // Product may have been deleted — log and continue
          AppLogger.warning(
            'Could not deduct stock for ${item.productName}: $e',
            tag: 'OrderProvider',
          );
        }
      }
    } catch (e) {
      AppLogger.error('Failed to deduct stock for order $orderId', error: e, tag: 'OrderProvider');
    }
  }
}
