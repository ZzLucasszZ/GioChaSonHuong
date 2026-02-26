import 'package:uuid/uuid.dart';

import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';

/// Payment method enum
enum PaymentMethod {
  cash, // Tiền mặt
  bankTransfer, // Chuyển khoản
  other, // Khác
}

/// Payment method extension
extension PaymentMethodExtension on PaymentMethod {
  String get value {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
      case PaymentMethod.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tiền mặt';
      case PaymentMethod.bankTransfer:
        return 'Chuyển khoản';
      case PaymentMethod.other:
        return 'Khác';
    }
  }

  static PaymentMethod fromString(String value) {
    switch (value) {
      case 'cash':
        return PaymentMethod.cash;
      case 'bank_transfer':
        return PaymentMethod.bankTransfer;
      case 'other':
        return PaymentMethod.other;
      default:
        return PaymentMethod.cash;
    }
  }
}

/// Payment model
class Payment {
  final String id;
  final String restaurantId;
  final String? orderId;
  final double amount;
  final PaymentMethod method;
  final DateTime paymentDate;
  final String? notes;
  final DateTime createdAt;

  // Joined data (for display)
  final String? restaurantName;
  final String? orderInfo;

  const Payment({
    required this.id,
    required this.restaurantId,
    this.orderId,
    required this.amount,
    required this.method,
    required this.paymentDate,
    this.notes,
    required this.createdAt,
    this.restaurantName,
    this.orderInfo,
  });

  /// Create a new Payment with generated ID and timestamp
  factory Payment.create({
    required String restaurantId,
    String? orderId,
    required double amount,
    required PaymentMethod method,
    DateTime? paymentDate,
    String? notes,
  }) {
    final now = DateTime.now();
    return Payment(
      id: const Uuid().v4(),
      restaurantId: restaurantId,
      orderId: orderId,
      amount: amount,
      method: method,
      paymentDate: paymentDate ?? now,
      notes: notes,
      createdAt: now,
    );
  }

  /// Create from database map
  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map[DbConstants.colId]?.toString() ?? '',
      restaurantId: map[DbConstants.colRestaurantId]?.toString() ?? '',
      orderId: map[DbConstants.colOrderId]?.toString(),
      amount: (map[DbConstants.colAmount] as num?)?.toDouble() ?? 0,
      method: PaymentMethodExtension.fromString(map[DbConstants.colMethod]?.toString() ?? 'cash'),
      paymentDate: AppDateUtils.parseDbDate(map[DbConstants.colPaymentDate]?.toString() ?? '') ?? DateTime.now(),
      notes: map[DbConstants.colNotes]?.toString(),
      createdAt: AppDateUtils.parseDbDateTime(map[DbConstants.colCreatedAt]?.toString() ?? '') ?? DateTime.now(),
      // Joined fields
      restaurantName: map['restaurant_name']?.toString(),
      orderInfo: map['order_info']?.toString(),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: id,
      DbConstants.colRestaurantId: restaurantId,
      DbConstants.colOrderId: orderId,
      DbConstants.colAmount: amount,
      DbConstants.colMethod: method.value,
      DbConstants.colPaymentDate: AppDateUtils.toDbDate(paymentDate),
      DbConstants.colNotes: notes,
      DbConstants.colCreatedAt: AppDateUtils.toDbDateTime(createdAt),
    };
  }

  /// Copy with modified fields
  Payment copyWith({
    String? id,
    String? restaurantId,
    String? orderId,
    double? amount,
    PaymentMethod? method,
    DateTime? paymentDate,
    String? notes,
    DateTime? createdAt,
    String? restaurantName,
    String? orderInfo,
  }) {
    return Payment(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      restaurantName: restaurantName ?? this.restaurantName,
      orderInfo: orderInfo ?? this.orderInfo,
    );
  }

  @override
  String toString() {
    return 'Payment(id: $id, restaurant: $restaurantId, amount: $amount, method: ${method.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Payment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
