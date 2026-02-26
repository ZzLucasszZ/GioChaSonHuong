import 'package:uuid/uuid.dart';

import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';

/// Restaurant-specific product price model
class RestaurantPrice {
  final String id;
  final String restaurantId;
  final String productId;
  final double price;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data (for display)
  final String? productName;
  final String? productUnit;
  final double? productBasePrice;

  const RestaurantPrice({
    required this.id,
    required this.restaurantId,
    required this.productId,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
    this.productName,
    this.productUnit,
    this.productBasePrice,
  });

  /// Create a new RestaurantPrice with generated ID and timestamps
  factory RestaurantPrice.create({
    required String restaurantId,
    required String productId,
    required double price,
  }) {
    final now = DateTime.now();
    return RestaurantPrice(
      id: const Uuid().v4(),
      restaurantId: restaurantId,
      productId: productId,
      price: price,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create from database map
  factory RestaurantPrice.fromMap(Map<String, dynamic> map) {
    return RestaurantPrice(
      id: map[DbConstants.colId] as String,
      restaurantId: map[DbConstants.colRestaurantId] as String,
      productId: map[DbConstants.colProductId] as String,
      price: (map[DbConstants.colPrice] as num).toDouble(),
      createdAt: AppDateUtils.parseDbDateTime(map[DbConstants.colCreatedAt] as String) ?? DateTime.now(),
      updatedAt: AppDateUtils.parseDbDateTime(map[DbConstants.colUpdatedAt] as String) ?? DateTime.now(),
      // Joined fields
      productName: map['product_name'] as String?,
      productUnit: map['product_unit'] as String?,
      productBasePrice: (map['product_base_price'] as num?)?.toDouble(),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: id,
      DbConstants.colRestaurantId: restaurantId,
      DbConstants.colProductId: productId,
      DbConstants.colPrice: price,
      DbConstants.colCreatedAt: AppDateUtils.toDbDateTime(createdAt),
      DbConstants.colUpdatedAt: AppDateUtils.toDbDateTime(updatedAt),
    };
  }

  /// Copy with modified fields
  RestaurantPrice copyWith({
    String? id,
    String? restaurantId,
    String? productId,
    double? price,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? productName,
    String? productUnit,
    double? productBasePrice,
  }) {
    return RestaurantPrice(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      productId: productId ?? this.productId,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      productName: productName ?? this.productName,
      productUnit: productUnit ?? this.productUnit,
      productBasePrice: productBasePrice ?? this.productBasePrice,
    );
  }

  @override
  String toString() {
    return 'RestaurantPrice(id: $id, restaurantId: $restaurantId, productId: $productId, price: $price)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RestaurantPrice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
