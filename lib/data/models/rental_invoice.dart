import 'package:uuid/uuid.dart';

import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';

/// Rental invoice (hóa đơn cho thuê) model
class RentalInvoice {
  final String id;
  final String tenantId;
  final int month;
  final int year;
  final double rentAmount;
  final double electricityOld;
  final double electricityNew;
  final double electricityRate;
  final double electricityAmount;
  final double waterOld;
  final double waterNew;
  final double waterRate;
  final double waterAmount;
  final double otherFees;
  final String? otherFeesNote;
  final double totalAmount;
  final bool isPaid;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined field (not in DB)
  final String? tenantName;
  final String? tenantRoom;

  const RentalInvoice({
    required this.id,
    required this.tenantId,
    required this.month,
    required this.year,
    required this.rentAmount,
    required this.electricityOld,
    required this.electricityNew,
    required this.electricityRate,
    required this.electricityAmount,
    required this.waterOld,
    required this.waterNew,
    required this.waterRate,
    required this.waterAmount,
    this.otherFees = 0,
    this.otherFeesNote,
    required this.totalAmount,
    this.isPaid = false,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.tenantName,
    this.tenantRoom,
  });

  /// Electricity usage
  double get electricityUsage => electricityNew - electricityOld;

  /// Water usage
  double get waterUsage => waterNew - waterOld;

  /// Period display string (e.g., "Tháng 01/2026")
  String get periodDisplay => 'Tháng ${month.toString().padLeft(2, '0')}/$year';

  factory RentalInvoice.create({
    required String tenantId,
    required int month,
    required int year,
    required double rentAmount,
    required double electricityOld,
    required double electricityNew,
    required double electricityRate,
    required double waterOld,
    required double waterNew,
    required double waterRate,
    double otherFees = 0,
    String? otherFeesNote,
    String? notes,
  }) {
    final now = DateTime.now();
    final electricityAmount = (electricityNew - electricityOld) * electricityRate;
    final waterAmount = (waterNew - waterOld) * waterRate;
    final totalAmount = rentAmount + electricityAmount + waterAmount + otherFees;

    return RentalInvoice(
      id: const Uuid().v4(),
      tenantId: tenantId,
      month: month,
      year: year,
      rentAmount: rentAmount,
      electricityOld: electricityOld,
      electricityNew: electricityNew,
      electricityRate: electricityRate,
      electricityAmount: electricityAmount,
      waterOld: waterOld,
      waterNew: waterNew,
      waterRate: waterRate,
      waterAmount: waterAmount,
      otherFees: otherFees,
      otherFeesNote: otherFeesNote,
      totalAmount: totalAmount,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory RentalInvoice.fromMap(Map<String, dynamic> map) {
    return RentalInvoice(
      id: map[DbConstants.colId] as String,
      tenantId: map[DbConstants.colTenantId] as String,
      month: map[DbConstants.colMonth] as int,
      year: map[DbConstants.colYear] as int,
      rentAmount: (map[DbConstants.colRentAmount] as num).toDouble(),
      electricityOld: (map[DbConstants.colElectricityOld] as num).toDouble(),
      electricityNew: (map[DbConstants.colElectricityNew] as num).toDouble(),
      electricityRate: (map[DbConstants.colElectricityRate] as num).toDouble(),
      electricityAmount: (map[DbConstants.colElectricityAmount] as num).toDouble(),
      waterOld: (map[DbConstants.colWaterOld] as num).toDouble(),
      waterNew: (map[DbConstants.colWaterNew] as num).toDouble(),
      waterRate: (map[DbConstants.colWaterRate] as num).toDouble(),
      waterAmount: (map[DbConstants.colWaterAmount] as num).toDouble(),
      otherFees: (map[DbConstants.colOtherFees] as num?)?.toDouble() ?? 0,
      otherFeesNote: map[DbConstants.colOtherFeesNote] as String?,
      totalAmount: (map[DbConstants.colTotalAmount] as num).toDouble(),
      isPaid: (map[DbConstants.colIsPaid] as int?) == 1,
      notes: map[DbConstants.colNotes] as String?,
      createdAt: AppDateUtils.parseDbDateTime(map[DbConstants.colCreatedAt] as String) ?? DateTime.now(),
      updatedAt: AppDateUtils.parseDbDateTime(map[DbConstants.colUpdatedAt] as String) ?? DateTime.now(),
      tenantName: map['tenant_name'] as String?,
      tenantRoom: map['tenant_room'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: id,
      DbConstants.colTenantId: tenantId,
      DbConstants.colMonth: month,
      DbConstants.colYear: year,
      DbConstants.colRentAmount: rentAmount,
      DbConstants.colElectricityOld: electricityOld,
      DbConstants.colElectricityNew: electricityNew,
      DbConstants.colElectricityRate: electricityRate,
      DbConstants.colElectricityAmount: electricityAmount,
      DbConstants.colWaterOld: waterOld,
      DbConstants.colWaterNew: waterNew,
      DbConstants.colWaterRate: waterRate,
      DbConstants.colWaterAmount: waterAmount,
      DbConstants.colOtherFees: otherFees,
      DbConstants.colOtherFeesNote: otherFeesNote,
      DbConstants.colTotalAmount: totalAmount,
      DbConstants.colIsPaid: isPaid ? 1 : 0,
      DbConstants.colNotes: notes,
      DbConstants.colCreatedAt: AppDateUtils.toDbDateTime(createdAt),
      DbConstants.colUpdatedAt: AppDateUtils.toDbDateTime(updatedAt),
    };
  }

  RentalInvoice copyWith({
    String? id,
    String? tenantId,
    int? month,
    int? year,
    double? rentAmount,
    double? electricityOld,
    double? electricityNew,
    double? electricityRate,
    double? electricityAmount,
    double? waterOld,
    double? waterNew,
    double? waterRate,
    double? waterAmount,
    double? otherFees,
    String? otherFeesNote,
    double? totalAmount,
    bool? isPaid,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? tenantName,
    String? tenantRoom,
  }) {
    return RentalInvoice(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      month: month ?? this.month,
      year: year ?? this.year,
      rentAmount: rentAmount ?? this.rentAmount,
      electricityOld: electricityOld ?? this.electricityOld,
      electricityNew: electricityNew ?? this.electricityNew,
      electricityRate: electricityRate ?? this.electricityRate,
      electricityAmount: electricityAmount ?? this.electricityAmount,
      waterOld: waterOld ?? this.waterOld,
      waterNew: waterNew ?? this.waterNew,
      waterRate: waterRate ?? this.waterRate,
      waterAmount: waterAmount ?? this.waterAmount,
      otherFees: otherFees ?? this.otherFees,
      otherFeesNote: otherFeesNote ?? this.otherFeesNote,
      totalAmount: totalAmount ?? this.totalAmount,
      isPaid: isPaid ?? this.isPaid,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      tenantName: tenantName ?? this.tenantName,
      tenantRoom: tenantRoom ?? this.tenantRoom,
    );
  }

  @override
  String toString() {
    return 'RentalInvoice(id: $id, tenant: $tenantId, $month/$year, total: $totalAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RentalInvoice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
