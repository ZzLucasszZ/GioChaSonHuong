import 'package:uuid/uuid.dart';

import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';

/// Tenant (khách thuê nhà) model
class Tenant {
  final String id;
  final String name;
  final String? phone;
  final String roomNumber;
  final double rentAmount;
  final double electricityRate;
  final double waterRate;
  final double depositAmount;
  final bool isDepositPaid;
  final DateTime? moveInDate;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Tenant({
    required this.id,
    required this.name,
    this.phone,
    required this.roomNumber,
    required this.rentAmount,
    required this.electricityRate,
    required this.waterRate,
    this.depositAmount = 0,
    this.isDepositPaid = false,
    this.moveInDate,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Tenant.create({
    required String name,
    String? phone,
    required String roomNumber,
    required double rentAmount,
    required double electricityRate,
    required double waterRate,
    double depositAmount = 0,
    bool isDepositPaid = false,
    DateTime? moveInDate,
    String? notes,
  }) {
    final now = DateTime.now();
    return Tenant(
      id: const Uuid().v4(),
      name: name,
      phone: phone,
      roomNumber: roomNumber,
      rentAmount: rentAmount,
      electricityRate: electricityRate,
      waterRate: waterRate,
      depositAmount: depositAmount,
      isDepositPaid: isDepositPaid,
      moveInDate: moveInDate,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map[DbConstants.colId] as String,
      name: map[DbConstants.colName] as String,
      phone: map[DbConstants.colPhone] as String?,
      roomNumber: map[DbConstants.colRoomNumber] as String,
      rentAmount: (map[DbConstants.colRentAmount] as num).toDouble(),
      electricityRate: (map[DbConstants.colElectricityRate] as num).toDouble(),
      waterRate: (map[DbConstants.colWaterRate] as num).toDouble(),
      depositAmount: (map[DbConstants.colDepositAmount] as num?)?.toDouble() ?? 0,
      isDepositPaid: (map[DbConstants.colIsDepositPaid] as int? ?? 0) == 1,
      moveInDate: map[DbConstants.colMoveInDate] != null
          ? AppDateUtils.parseDbDateTime(map[DbConstants.colMoveInDate] as String)
          : null,
      notes: map[DbConstants.colNotes] as String?,
      isActive: (map[DbConstants.colIsActive] as int?) == 1,
      createdAt: AppDateUtils.parseDbDateTime(map[DbConstants.colCreatedAt] as String) ?? DateTime.now(),
      updatedAt: AppDateUtils.parseDbDateTime(map[DbConstants.colUpdatedAt] as String) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: id,
      DbConstants.colName: name,
      DbConstants.colPhone: phone,
      DbConstants.colRoomNumber: roomNumber,
      DbConstants.colRentAmount: rentAmount,
      DbConstants.colElectricityRate: electricityRate,
      DbConstants.colWaterRate: waterRate,
      DbConstants.colDepositAmount: depositAmount,
      DbConstants.colIsDepositPaid: isDepositPaid ? 1 : 0,
      DbConstants.colMoveInDate: moveInDate != null ? AppDateUtils.toDbDateTime(moveInDate!) : null,
      DbConstants.colNotes: notes,
      DbConstants.colIsActive: isActive ? 1 : 0,
      DbConstants.colCreatedAt: AppDateUtils.toDbDateTime(createdAt),
      DbConstants.colUpdatedAt: AppDateUtils.toDbDateTime(updatedAt),
    };
  }

  Tenant copyWith({
    String? id,
    String? name,
    String? phone,
    String? roomNumber,
    double? rentAmount,
    double? electricityRate,
    double? waterRate,
    double? depositAmount,
    bool? isDepositPaid,
    DateTime? moveInDate,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      roomNumber: roomNumber ?? this.roomNumber,
      rentAmount: rentAmount ?? this.rentAmount,
      electricityRate: electricityRate ?? this.electricityRate,
      waterRate: waterRate ?? this.waterRate,
      depositAmount: depositAmount ?? this.depositAmount,
      isDepositPaid: isDepositPaid ?? this.isDepositPaid,
      moveInDate: moveInDate ?? this.moveInDate,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Tenant(id: $id, name: $name, room: $roomNumber, rent: $rentAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tenant && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
