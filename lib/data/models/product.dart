import 'package:uuid/uuid.dart';

import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';

/// Product model
class Product {
  final String id;
  final String name;
  final String? sku;
  final String unit;
  final double basePrice;
  final double currentStock;
  final double minStockAlert;
  final String? category;
  final bool isActive;
  final int defaultQuantityPerTable; // Number of items per table by default
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.sku,
    required this.unit,
    required this.basePrice,
    required this.currentStock,
    required this.minStockAlert,
    this.category,
    this.isActive = true,
    this.defaultQuantityPerTable = 1,
    required this.createdAt,
    required this.updatedAt,
  });
  
  // Alias for basePrice for backward compatibility
  double get defaultPrice => basePrice;
  
  // Alias for minStockAlert for backward compatibility
  double get minStockLevel => minStockAlert;

  /// Check if stock is low
  bool get isLowStock => currentStock <= minStockAlert && currentStock > 0;

  /// Check if out of stock
  bool get isOutOfStock => currentStock <= 0;

  /// Get stock status
  StockStatus get stockStatus {
    if (isOutOfStock) return StockStatus.outOfStock;
    if (isLowStock) return StockStatus.low;
    return StockStatus.normal;
  }

  /// Create a new Product with generated ID and timestamps
  factory Product.create({
    required String name,
    String? sku,
    required String unit,
    required double basePrice,
    double currentStock = 0,
    double minStockAlert = 0,
    String? category,
    bool isActive = true,
  }) {
    final now = DateTime.now();
    return Product(
      id: const Uuid().v4(),
      name: name,
      sku: sku,
      unit: unit,
      basePrice: basePrice,
      currentStock: currentStock,
      minStockAlert: minStockAlert,
      category: category,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create from database map
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map[DbConstants.colId] as String,
      name: map[DbConstants.colName] as String,
      sku: map[DbConstants.colSku] as String?,
      unit: map[DbConstants.colUnit] as String,
      basePrice: (map[DbConstants.colBasePrice] as num).toDouble(),
      currentStock: (map[DbConstants.colCurrentStock] as num).toDouble(),
      minStockAlert: (map[DbConstants.colMinStockAlert] as num).toDouble(),
      category: map[DbConstants.colCategory] as String?,
      isActive: (map[DbConstants.colIsActive] as int?) == 1,
      createdAt: AppDateUtils.parseDbDateTime(map[DbConstants.colCreatedAt] as String) ?? DateTime.now(),
      updatedAt: AppDateUtils.parseDbDateTime(map[DbConstants.colUpdatedAt] as String) ?? DateTime.now(),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: id,
      DbConstants.colName: name,
      DbConstants.colSku: sku,
      DbConstants.colUnit: unit,
      DbConstants.colBasePrice: basePrice,
      DbConstants.colCurrentStock: currentStock,
      DbConstants.colMinStockAlert: minStockAlert,
      DbConstants.colCategory: category,
      DbConstants.colIsActive: isActive ? 1 : 0,
      DbConstants.colCreatedAt: AppDateUtils.toDbDateTime(createdAt),
      DbConstants.colUpdatedAt: AppDateUtils.toDbDateTime(updatedAt),
    };
  }

  /// Copy with modified fields
  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? unit,
    double? basePrice,
    double? currentStock,
    double? minStockAlert,
    String? category,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      basePrice: basePrice ?? this.basePrice,
      currentStock: currentStock ?? this.currentStock,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, sku: $sku, unit: $unit, basePrice: $basePrice, currentStock: $currentStock)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Stock status enum
enum StockStatus {
  normal,
  low,
  outOfStock,
}
