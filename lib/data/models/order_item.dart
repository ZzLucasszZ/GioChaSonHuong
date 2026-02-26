import 'package:uuid/uuid.dart';

import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';

/// Order item model - snapshot of product at order time
class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String productName; // Snapshot at order time
  final String unit; // Snapshot at order time
  final double unitPrice; // Snapshot at order time (restaurant price or base price)
  final double quantity;
  final double subtotal;
  final DateTime createdAt;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    required this.createdAt,
  });

  /// Create a new OrderItem with generated ID and timestamp
  factory OrderItem.create({
    required String orderId,
    required String productId,
    required String productName,
    required String unit,
    required double unitPrice,
    required double quantity,
  }) {
    return OrderItem(
      id: const Uuid().v4(),
      orderId: orderId,
      productId: productId,
      productName: productName,
      unit: unit,
      unitPrice: unitPrice,
      quantity: quantity,
      subtotal: unitPrice * quantity,
      createdAt: DateTime.now(),
    );
  }

  /// Create from database map
  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map[DbConstants.colId]?.toString() ?? '',
      orderId: map[DbConstants.colOrderId]?.toString() ?? '',
      productId: map[DbConstants.colProductId]?.toString() ?? '',
      productName: map[DbConstants.colProductName]?.toString() ?? '',
      unit: map[DbConstants.colUnit]?.toString() ?? '',
      unitPrice: (map[DbConstants.colUnitPrice] as num?)?.toDouble() ?? 0,
      quantity: (map[DbConstants.colQuantity] as num?)?.toDouble() ?? 0,
      subtotal: (map[DbConstants.colSubtotal] as num?)?.toDouble() ?? 0,
      createdAt: AppDateUtils.parseDbDateTime(map[DbConstants.colCreatedAt]?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: id,
      DbConstants.colOrderId: orderId,
      DbConstants.colProductId: productId,
      DbConstants.colProductName: productName,
      DbConstants.colUnit: unit,
      DbConstants.colUnitPrice: unitPrice,
      DbConstants.colQuantity: quantity,
      DbConstants.colSubtotal: subtotal,
      DbConstants.colCreatedAt: AppDateUtils.toDbDateTime(createdAt),
    };
  }

  /// Copy with modified fields
  OrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? productName,
    String? unit,
    double? unitPrice,
    double? quantity,
    double? subtotal,
    DateTime? createdAt,
  }) {
    final newQuantity = quantity ?? this.quantity;
    final newUnitPrice = unitPrice ?? this.unitPrice;
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      unitPrice: newUnitPrice,
      quantity: newQuantity,
      subtotal: subtotal ?? (newUnitPrice * newQuantity),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'OrderItem(id: $id, product: $productName, qty: $quantity, subtotal: $subtotal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
