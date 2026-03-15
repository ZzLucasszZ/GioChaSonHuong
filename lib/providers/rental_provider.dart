import 'package:flutter/foundation.dart';

import '../core/utils/logger.dart';
import '../data/database/database_helper.dart';
import '../data/models/tenant.dart';
import '../data/models/rental_invoice.dart';
import '../data/repositories/tenant_repository.dart';
import '../data/repositories/rental_invoice_repository.dart';
import '../services/google_drive_backup_service.dart';

/// Provider for rental management state
class RentalProvider extends ChangeNotifier {
  final TenantRepository _tenantRepo;
  final RentalInvoiceRepository _invoiceRepo;
  final GoogleDriveBackupService _gDriveBackup = GoogleDriveBackupService();

  List<Tenant> _tenants = [];
  List<RentalInvoice> _invoices = [];
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _isLoading = false;
  String? _error;

  RentalProvider(DatabaseHelper dbHelper)
      : _tenantRepo = TenantRepository(dbHelper),
        _invoiceRepo = RentalInvoiceRepository(dbHelper);

  void _triggerAutoBackup() {
    _gDriveBackup.autoBackup().catchError((e) {
      AppLogger.warning('Auto-backup skipped: $e', tag: 'AutoBackup');
    });
  }

  // Getters
  List<Tenant> get tenants => _tenants;
  List<RentalInvoice> get invoices => _invoices;
  int get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load active tenants
  Future<void> loadTenants() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tenants = await _tenantRepo.getActiveTenants();
      _error = null;
    } catch (e) {
      _error = 'Không thể tải danh sách khách thuê: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load invoices for selected month/year
  Future<void> loadInvoices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _invoices = await _invoiceRepo.getByMonth(_selectedMonth, _selectedYear);
      _error = null;
    } catch (e) {
      _error = 'Không thể tải hóa đơn: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load invoices for a specific tenant
  Future<List<RentalInvoice>> loadInvoicesForTenant(String tenantId) async {
    try {
      return await _invoiceRepo.getByTenant(tenantId);
    } catch (e) {
      _error = 'Không thể tải hóa đơn: $e';
      notifyListeners();
      return [];
    }
  }

  /// Set selected month/year and reload
  Future<void> setMonth(int month, int year) async {
    _selectedMonth = month;
    _selectedYear = year;
    await loadInvoices();
  }

  // ─── Tenant CRUD ───

  Future<Tenant?> createTenant({
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
  }) async {
    try {
      final tenant = Tenant.create(
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
      );
      await _tenantRepo.insert(tenant);
      _tenants.add(tenant);
      _tenants.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
      notifyListeners();
      _triggerAutoBackup();
      return tenant;
    } catch (e) {
      _error = 'Không thể tạo khách thuê: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateTenant(Tenant tenant) async {
    try {
      await _tenantRepo.update(tenant, tenant.id);
      final index = _tenants.indexWhere((t) => t.id == tenant.id);
      if (index != -1) {
        _tenants[index] = tenant;
      }
      notifyListeners();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể cập nhật khách thuê: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTenant(String id) async {
    try {
      await _tenantRepo.deleteWithAllData(id);
      _tenants.removeWhere((t) => t.id == id);
      _invoices.removeWhere((i) => i.tenantId == id);
      notifyListeners();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể xóa khách thuê: $e';
      notifyListeners();
      return false;
    }
  }

  // ─── Invoice CRUD ───

  Future<RentalInvoice?> createInvoice({
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
    bool isPendingMeter = false,
  }) async {
    try {
      // Check for duplicate
      final exists = await _invoiceRepo.existsForMonth(tenantId, month, year);
      if (exists) {
        _error = 'Hóa đơn tháng ${month.toString().padLeft(2, '0')}/$year đã tồn tại cho khách này';
        notifyListeners();
        return null;
      }

      final invoice = RentalInvoice.create(
        tenantId: tenantId,
        month: month,
        year: year,
        rentAmount: rentAmount,
        electricityOld: electricityOld,
        electricityNew: electricityNew,
        electricityRate: electricityRate,
        waterOld: waterOld,
        waterNew: waterNew,
        waterRate: waterRate,
        otherFees: otherFees,
        otherFeesNote: otherFeesNote,
        notes: notes,
        isPendingMeter: isPendingMeter,
      );

      await _invoiceRepo.insert(invoice);
      // Reload to get joined data
      await loadInvoices();
      _triggerAutoBackup();
      return invoice;
    } catch (e) {
      _error = 'Không thể tạo hóa đơn: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateInvoice(RentalInvoice invoice) async {
    try {
      await _invoiceRepo.update(invoice, invoice.id);

      // Cascade: cập nhật electricity_old/water_old của các tháng pending phía sau.
      // Nếu hóa đơn này đã chốt số: dùng electricityNew làm giá trị lan truyền.
      // Nếu vấn pending: dùng electricityOld (số thực cuối cùng biết được).
      final elecPropagated = invoice.hasPendingMeterReading
          ? invoice.electricityOld
          : invoice.electricityNew;
      final waterPropagated = invoice.hasPendingMeterReading
          ? invoice.waterOld
          : invoice.waterNew;
      await _invoiceRepo.cascadeMeterOld(
        invoice.tenantId,
        invoice.month,
        invoice.year,
        elecPropagated,
        waterPropagated,
      );

      await loadInvoices();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể cập nhật hóa đơn: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteInvoice(String id) async {
    try {
      await _invoiceRepo.delete(id);
      _invoices.removeWhere((i) => i.id == id);
      notifyListeners();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể xóa hóa đơn: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleInvoicePaid(String id, bool isPaid, {DateTime? paidAt}) async {
    try {
      await _invoiceRepo.togglePaid(id, isPaid, paidAt: paidAt);
      final index = _invoices.indexWhere((i) => i.id == id);
      if (index != -1) {
        _invoices[index] = _invoices[index].copyWith(
          isPaid: isPaid,
          paidAt: isPaid ? (paidAt ?? DateTime.now()) : null,
          clearPaidAt: !isPaid,
        );
      }
      notifyListeners();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể cập nhật trạng thái: $e';
      notifyListeners();
      return false;
    }
  }

  /// Record that the rent portion was collected in advance.
  Future<bool> markRentPaid(String id, {required DateTime paidAt}) async {
    try {
      await _invoiceRepo.markRentPaid(id, paidAt);
      final index = _invoices.indexWhere((i) => i.id == id);
      if (index != -1) {
        _invoices[index] = _invoices[index].copyWith(rentPaidAt: paidAt);
      }
      notifyListeners();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể cập nhật: $e';
      notifyListeners();
      return false;
    }
  }

  /// Undo rent collection (clears rent_paid_at).
  Future<bool> clearRentPaid(String id) async {
    try {
      await _invoiceRepo.clearRentPaid(id);
      final index = _invoices.indexWhere((i) => i.id == id);
      if (index != -1) {
        _invoices[index] = _invoices[index].copyWith(clearRentPaidAt: true);
      }
      notifyListeners();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể hoàn tác: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get latest invoice for a tenant (for pre-filling readings)
  Future<RentalInvoice?> getLatestInvoice(String tenantId) async {
    return await _invoiceRepo.getLatestForTenant(tenantId);
  }

  /// Get the invoice for a specific month/year (used when editing pending invoices
  /// to chain the old reading from the previous month's new reading).
  Future<RentalInvoice?> getInvoiceForMonth(
      String tenantId, int month, int year) async {
    return await _invoiceRepo.getForTenantAndMonth(tenantId, month, year);
  }

  /// Get tenant by id from cached list
  Tenant? getTenantById(String id) {
    try {
      return _tenants.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Insert a fully-built list of invoices (one per month, each with real readings).
  /// Skips months that already have an invoice; returns count actually inserted.
  Future<int> createInvoiceBatch(List<RentalInvoice> invoices) async {
    try {
      final inserted = await _invoiceRepo.insertBatch(invoices);
      if (inserted.isNotEmpty) {
        await loadInvoices();
        _triggerAutoBackup();
      }
      return inserted.length;
    } catch (e) {
      _error = 'Không thể tạo hóa đơn: $e';
      notifyListeners();
      return 0;
    }
  }

  /// Create multiple invoices for consecutive months (rent-only, no readings).
  /// Kept for voice command / other callers that don't have meter readings.
  Future<int> createMultiMonthInvoices({
    required String tenantId,
    required int startMonth,
    required int startYear,
    required int monthsCount,
    required double rentAmount,
    double otherFees = 0,
    String? otherFeesNote,
    String? notes,
  }) async {
    try {
      final invoices = <RentalInvoice>[];
      int m = startMonth;
      int y = startYear;

      for (int i = 0; i < monthsCount; i++) {
        invoices.add(RentalInvoice.create(
          tenantId: tenantId,
          month: m,
          year: y,
          rentAmount: rentAmount,
          electricityOld: 0,
          electricityNew: 0,
          electricityRate: 0,
          waterOld: 0,
          waterNew: 0,
          waterRate: 0,
          otherFees: i == 0 ? otherFees : 0,
          otherFeesNote: i == 0 ? otherFeesNote : null,
          notes: notes,
        ));

        m++;
        if (m > 12) {
          m = 1;
          y++;
        }
      }

      final inserted = await _invoiceRepo.insertBatch(invoices);
      if (inserted.isNotEmpty) {
        await loadInvoices();
        _triggerAutoBackup();
      }
      return inserted.length;
    } catch (e) {
      _error = 'Không thể tạo hóa đơn nhiều tháng: $e';
      notifyListeners();
      return 0;
    }
  }
}
