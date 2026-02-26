import 'package:uuid/uuid.dart';

import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';

/// Transaction type enum
enum TransactionType {
  stockIn, // Nhập kho
  stockOut, // Xuất kho (giao hàng)
  adjustment, // Điều chỉnh
  returned, // Trả hàng
}

/// Transaction type extension
extension TransactionTypeExtension on TransactionType {
  String get value {
    switch (this) {
      case TransactionType.stockIn:
        return 'stock_in';
      case TransactionType.stockOut:
        return 'stock_out';
      case TransactionType.adjustment:
        return 'adjustment';
      case TransactionType.returned:
        return 'returned';
    }
  }

  String get displayName {
    switch (this) {
      case TransactionType.stockIn:
        return 'Nhập kho';
      case TransactionType.stockOut:
        return 'Xuất kho';
      case TransactionType.adjustment:
        return 'Điều chỉnh';
      case TransactionType.returned:
        return 'Trả hàng';
    }
  }

  /// Returns true if this transaction type increases stock
  bool get isIncrease {
    switch (this) {
      case TransactionType.stockIn:
      case TransactionType.returned:
        return true;
      case TransactionType.stockOut:
      case TransactionType.adjustment:
        return false;
    }
  }

  static TransactionType fromString(String value) {
    switch (value) {
      case 'stock_in':
        return TransactionType.stockIn;
      case 'stock_out':
        return TransactionType.stockOut;
      case 'adjustment':
        return TransactionType.adjustment;
      case 'returned':
        return TransactionType.returned;
      default:
        return TransactionType.adjustment;
    }
  }
}

/// Inventory transaction model
class InventoryTransaction {
  final String id;
  final String productId;
  final TransactionType type;
  final double quantity;
  final double stockBefore;
  final double stockAfter;
  final String? referenceId;
  final String? notes;
  final DateTime createdAt;

  // Joined data (for display)
  final String? productName;
  final String? productSku;
  final String? productUnit;

  const InventoryTransaction({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    this.referenceId,
    this.notes,
    required this.createdAt,
    this.productName,
    this.productSku,
    this.productUnit,
  });

  /// Calculate stock change (positive for increase, negative for decrease)
  double get stockChange => stockAfter - stockBefore;

  /// Create a new InventoryTransaction with generated ID and timestamp
  factory InventoryTransaction.create({
    required String productId,
    required TransactionType type,
    required double quantity,
    required double stockBefore,
    String? referenceId,
    String? notes,
  }) {
    // Calculate stock after based on transaction type
    double stockAfter;
    if (type.isIncrease) {
      stockAfter = stockBefore + quantity;
    } else if (type == TransactionType.adjustment) {
      // For adjustment, quantity is the new absolute value
      stockAfter = quantity;
    } else {
      stockAfter = stockBefore - quantity;
    }

    return InventoryTransaction(
      id: const Uuid().v4(),
      productId: productId,
      type: type,
      quantity: quantity,
      stockBefore: stockBefore,
      stockAfter: stockAfter,
      referenceId: referenceId,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }

  /// Create a stock-in transaction
  factory InventoryTransaction.stockIn({
    required String productId,
    required double quantity,
    required double currentStock,
    String? notes,
  }) {
    return InventoryTransaction.create(
      productId: productId,
      type: TransactionType.stockIn,
      quantity: quantity,
      stockBefore: currentStock,
      notes: notes,
    );
  }

  /// Create a stock-out transaction (for delivery)
  factory InventoryTransaction.stockOut({
    required String productId,
    required double quantity,
    required double currentStock,
    String? referenceId,
    String? notes,
  }) {
    return InventoryTransaction.create(
      productId: productId,
      type: TransactionType.stockOut,
      quantity: quantity,
      stockBefore: currentStock,
      referenceId: referenceId,
      notes: notes,
    );
  }

  /// Create an adjustment transaction
  factory InventoryTransaction.adjustment({
    required String productId,
    required double newQuantity,
    required double currentStock,
    String? notes,
  }) {
    return InventoryTransaction.create(
      productId: productId,
      type: TransactionType.adjustment,
      quantity: newQuantity, // newQuantity is the absolute new value
      stockBefore: currentStock,
      notes: notes,
    );
  }

  /// Create from database map
  factory InventoryTransaction.fromMap(Map<String, dynamic> map) {
    return InventoryTransaction(
      id: map[DbConstants.colId] as String,
      productId: map[DbConstants.colProductId] as String,
      type: TransactionTypeExtension.fromString(map[DbConstants.colType] as String),
      quantity: (map[DbConstants.colQuantity] as num).toDouble(),
      stockBefore: (map[DbConstants.colStockBefore] as num).toDouble(),
      stockAfter: (map[DbConstants.colStockAfter] as num).toDouble(),
      referenceId: map[DbConstants.colReferenceId] as String?,
      notes: map[DbConstants.colNotes] as String?,
      createdAt: AppDateUtils.parseDbDateTime(map[DbConstants.colCreatedAt] as String) ?? DateTime.now(),
      // Joined fields
      productName: map['product_name'] as String?,
      productSku: map['product_sku'] as String?,
      productUnit: map['product_unit'] as String?,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: id,
      DbConstants.colProductId: productId,
      DbConstants.colType: type.value,
      DbConstants.colQuantity: quantity,
      DbConstants.colStockBefore: stockBefore,
      DbConstants.colStockAfter: stockAfter,
      DbConstants.colReferenceId: referenceId,
      DbConstants.colNotes: notes,
      DbConstants.colCreatedAt: AppDateUtils.toDbDateTime(createdAt),
    };
  }

  /// Copy with modified fields
  InventoryTransaction copyWith({
    String? id,
    String? productId,
    TransactionType? type,
    double? quantity,
    double? stockBefore,
    double? stockAfter,
    String? referenceId,
    String? notes,
    DateTime? createdAt,
    String? productName,
    String? productSku,
    String? productUnit,
  }) {
    return InventoryTransaction(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      stockBefore: stockBefore ?? this.stockBefore,
      stockAfter: stockAfter ?? this.stockAfter,
      referenceId: referenceId ?? this.referenceId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      productUnit: productUnit ?? this.productUnit,
    );
  }

  @override
  String toString() {
    return 'InventoryTransaction(id: $id, type: ${type.displayName}, qty: $quantity, before: $stockBefore, after: $stockAfter)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventoryTransaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
