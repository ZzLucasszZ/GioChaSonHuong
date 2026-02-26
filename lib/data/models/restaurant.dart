import 'package:uuid/uuid.dart';

import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';

/// Restaurant model
class Restaurant {
  final String id;
  final String name;
  final String? contactPerson;
  final String phone;
  final String address;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Restaurant({
    required this.id,
    required this.name,
    this.contactPerson,
    required this.phone,
    required this.address,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new Restaurant with generated ID and timestamps
  factory Restaurant.create({
    required String name,
    String? contactPerson,
    String phone = '',
    String address = '',
    String? notes,
    bool isActive = true,
  }) {
    final now = DateTime.now();
    return Restaurant(
      id: const Uuid().v4(),
      name: name,
      contactPerson: contactPerson,
      phone: phone,
      address: address,
      notes: notes,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create from database map
  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map[DbConstants.colId] as String,
      name: map[DbConstants.colName] as String,
      contactPerson: map[DbConstants.colContactPerson] as String?,
      phone: (map[DbConstants.colPhone] as String?) ?? '',
      address: (map[DbConstants.colAddress] as String?) ?? '',
      notes: map[DbConstants.colNotes] as String?,
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
      DbConstants.colContactPerson: contactPerson,
      DbConstants.colPhone: phone,
      DbConstants.colAddress: address,
      DbConstants.colNotes: notes,
      DbConstants.colIsActive: isActive ? 1 : 0,
      DbConstants.colCreatedAt: AppDateUtils.toDbDateTime(createdAt),
      DbConstants.colUpdatedAt: AppDateUtils.toDbDateTime(updatedAt),
    };
  }

  /// Copy with modified fields
  Restaurant copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? address,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Restaurant(id: $id, name: $name, phone: $phone, address: $address, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Restaurant && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
