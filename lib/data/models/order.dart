import 'package:uuid/uuid.dart';

import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';
import 'order_item.dart';

/// Order status enum
enum OrderStatus {
  pending,
  confirmed,
  delivering,
  delivered,
  cancelled,
}

/// Payment status enum
enum PaymentStatus {
  unpaid,
  partial,
  paid,
}

/// Session enum (Morning/Afternoon)
enum OrderSession {
  morning,
  afternoon,
}

/// Order status extension
extension OrderStatusExtension on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.delivering:
        return 'delivering';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Chờ xử lý';
      case OrderStatus.confirmed:
        return 'Đã xác nhận';
      case OrderStatus.delivering:
        return 'Đang giao';
      case OrderStatus.delivered:
        return 'Đã giao';
      case OrderStatus.cancelled:
        return 'Đã hủy';
    }
  }

  static OrderStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'delivering':
        return OrderStatus.delivering;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}

/// Payment status extension
extension PaymentStatusExtension on PaymentStatus {
  String get value {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'unpaid';
      case PaymentStatus.partial:
        return 'partial';
      case PaymentStatus.paid:
        return 'paid';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'Chưa thanh toán';
      case PaymentStatus.partial:
        return 'Thanh toán một phần';
      case PaymentStatus.paid:
        return 'Đã thanh toán';
    }
  }

  static PaymentStatus fromString(String value) {
    switch (value) {
      case 'unpaid':
        return PaymentStatus.unpaid;
      case 'partial':
        return PaymentStatus.partial;
      case 'paid':
        return PaymentStatus.paid;
      default:
        return PaymentStatus.unpaid;
    }
  }

  /// Calculate payment status from total and paid amounts
  /// Uses tolerance of 0.01 to handle floating point precision
  static PaymentStatus calculate(double totalAmount, double paidAmount) {
    const tolerance = 0.01;
    
    if (paidAmount < tolerance) {
      return PaymentStatus.unpaid;
    } else if (paidAmount >= totalAmount - tolerance) {
      return PaymentStatus.paid;
    } else {
      return PaymentStatus.partial;
    }
  }
}

/// Session extension
extension OrderSessionExtension on OrderSession {
  String get value {
    switch (this) {
      case OrderSession.morning:
        return 'morning';
      case OrderSession.afternoon:
        return 'afternoon';
    }
  }

  String get displayName {
    switch (this) {
      case OrderSession.morning:
        return 'Sáng';
      case OrderSession.afternoon:
        return 'Chiều';
    }
  }

  static OrderSession fromString(String value) {
    switch (value) {
      case 'morning':
        return OrderSession.morning;
      case 'afternoon':
        return OrderSession.afternoon;
      default:
        return OrderSession.morning;
    }
  }
}

/// Order model
class Order {
  final String id;
  final String restaurantId;
  final DateTime orderDate;
  final DateTime deliveryDate;
  final OrderSession? session;
  final OrderStatus status;
  final double totalAmount;
  final double paidAmount;
  final PaymentStatus paymentStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data (for display)
  final String? restaurantName;
  final String? restaurantPhone;
  final String? restaurantAddress;
  final List<OrderItem>? items;

  const Order({
    required this.id,
    required this.restaurantId,
    required this.orderDate,
    required this.deliveryDate,
    this.session,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    required this.paymentStatus,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.restaurantName,
    this.restaurantPhone,
    this.restaurantAddress,
    this.items,
  });

  /// Calculate debt amount (never negative)
  double get debtAmount {
    final debt = totalAmount - paidAmount;
    return debt > 0 ? debt : 0;
  }

  /// Check if order can be edited
  bool get canEdit => status == OrderStatus.pending || status == OrderStatus.confirmed;

  /// Check if order can be deleted
  bool get canDelete => status == OrderStatus.pending || status == OrderStatus.confirmed;

  /// Check if order can be marked as delivered
  bool get canMarkDelivered =>
      status == OrderStatus.pending ||
      status == OrderStatus.confirmed ||
      status == OrderStatus.delivering;

  /// Check if order can be cancelled
  bool get canCancel => status == OrderStatus.pending || status == OrderStatus.confirmed;

  /// Create a new Order with generated ID and timestamps
  factory Order.create({
    required String restaurantId,
    required DateTime orderDate,
    required DateTime deliveryDate,
    double totalAmount = 0,
    String? notes,
    OrderSession? session,
  }) {
    final now = DateTime.now();
    return Order(
      id: const Uuid().v4(),
      restaurantId: restaurantId,
      orderDate: orderDate,
      deliveryDate: deliveryDate,
      session: session,
      status: OrderStatus.pending,
      totalAmount: totalAmount,
      paidAmount: 0,
      paymentStatus: PaymentStatus.unpaid,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create from database map
  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map[DbConstants.colId]?.toString() ?? '',
      restaurantId: map[DbConstants.colRestaurantId]?.toString() ?? '',
      orderDate: AppDateUtils.parseDbDate(map[DbConstants.colOrderDate]?.toString() ?? '') ?? DateTime.now(),
      deliveryDate: AppDateUtils.parseDbDate(map[DbConstants.colDeliveryDate]?.toString() ?? '') ?? DateTime.now(),
      session: map[DbConstants.colSession] != null
          ? OrderSessionExtension.fromString(map[DbConstants.colSession].toString())
          : null,
      status: OrderStatusExtension.fromString(map[DbConstants.colStatus]?.toString() ?? 'pending'),
      totalAmount: (map[DbConstants.colTotalAmount] as num?)?.toDouble() ?? 0,
      paidAmount: (map[DbConstants.colPaidAmount] as num?)?.toDouble() ?? 0,
      paymentStatus: PaymentStatusExtension.fromString(map[DbConstants.colPaymentStatus]?.toString() ?? 'unpaid'),
      notes: map[DbConstants.colNotes]?.toString(),
      createdAt: AppDateUtils.parseDbDateTime(map[DbConstants.colCreatedAt]?.toString() ?? '') ?? DateTime.now(),
      updatedAt: AppDateUtils.parseDbDateTime(map[DbConstants.colUpdatedAt]?.toString() ?? '') ?? DateTime.now(),
      // Joined fields
      restaurantName: map['restaurant_name']?.toString(),
      restaurantPhone: map['restaurant_phone']?.toString(),
      restaurantAddress: map['restaurant_address']?.toString(),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: id,
      DbConstants.colRestaurantId: restaurantId,
      DbConstants.colOrderDate: AppDateUtils.toDbDate(orderDate),
      DbConstants.colDeliveryDate: AppDateUtils.toDbDate(deliveryDate),
      DbConstants.colSession: session?.value ?? OrderSession.morning.value,
      DbConstants.colStatus: status.value,
      DbConstants.colTotalAmount: totalAmount,
      DbConstants.colPaidAmount: paidAmount,
      DbConstants.colPaymentStatus: paymentStatus.value,
      DbConstants.colNotes: notes,
      DbConstants.colCreatedAt: AppDateUtils.toDbDateTime(createdAt),
      DbConstants.colUpdatedAt: AppDateUtils.toDbDateTime(updatedAt),
    };
  }

  /// Copy with modified fields
  Order copyWith({
    String? id,
    String? restaurantId,
    DateTime? orderDate,
    DateTime? deliveryDate,
    OrderSession? session,
    OrderStatus? status,
    double? totalAmount,
    double? paidAmount,
    PaymentStatus? paymentStatus,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? restaurantName,
    String? restaurantPhone,
    String? restaurantAddress,
    List<OrderItem>? items,
  }) {
    return Order(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      orderDate: orderDate ?? this.orderDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      session: session ?? this.session,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantPhone: restaurantPhone ?? this.restaurantPhone,
      restaurantAddress: restaurantAddress ?? this.restaurantAddress,
      items: items ?? this.items,
    );
  }

  @override
  String toString() {
    return 'Order(id: $id, restaurantId: $restaurantId, status: ${status.displayName}, total: $totalAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Order && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
