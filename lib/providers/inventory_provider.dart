import 'package:flutter/foundation.dart';

import '../core/utils/logger.dart';
import '../data/database/database_helper.dart';
import '../data/models/inventory_transaction.dart';
import '../data/models/product.dart';
import '../data/repositories/inventory_repository.dart';
import '../services/google_drive_backup_service.dart';

class InventoryProvider with ChangeNotifier {
  final InventoryRepository _inventoryRepository = InventoryRepository(DatabaseHelper.instance);
  final GoogleDriveBackupService _gDriveBackup = GoogleDriveBackupService();

  List<Product> _products = [];
  List<InventoryTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  void _triggerAutoBackup() {
    _gDriveBackup.autoBackup().catchError((e) {
      AppLogger.warning('Auto-backup skipped: $e', tag: 'AutoBackup');
    });
  }

  List<Product> get products => _products;
  List<InventoryTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all products with stock info (uses ProductProvider)
  Future<void> loadInventories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Products are loaded via ProductProvider
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Không thể tải tồn kho: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get product stock by product ID
  Product? getProductById(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Add stock to inventory
  Future<bool> addStock({
    required String productId,
    required double quantity,
    String? notes,
  }) async {
    try {
      await _inventoryRepository.recordStockIn(
        productId: productId,
        quantity: quantity,
        notes: notes,
      );
      await loadInventories();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể nhập kho: $e';
      notifyListeners();
      return false;
    }
  }

  /// Remove stock from inventory
  Future<bool> removeStock({
    required String productId,
    required double quantity,
    String? notes,
  }) async {
    try {
      await _inventoryRepository.recordStockOut(
        productId: productId,
        quantity: quantity,
        notes: notes,
      );
      await loadInventories();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể xuất kho: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get stock transactions for a product
  Future<List<InventoryTransaction>> getTransactions({String? productId, int limit = 50}) async {
    try {
      if (productId != null) {
        _transactions = await _inventoryRepository.getByProduct(productId);
      } else {
        _transactions = await _inventoryRepository.getRecent(limit: limit);
      }
      notifyListeners();
      return _transactions;
    } catch (e) {
      _error = 'Không thể tải lịch sử: $e';
      notifyListeners();
      return [];
    }
  }

  /// Load recent transactions
  Future<void> loadRecentTransactions({int limit = 50}) async {
    try {
      _transactions = await _inventoryRepository.getRecent(limit: limit);
      notifyListeners();
    } catch (e) {
      _error = 'Không thể tải lịch sử: $e';
      notifyListeners();
    }
  }

  /// Load transactions by date
  Future<void> loadTransactionsByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      _transactions = await _inventoryRepository.getByDateRange(
        startDate: startOfDay,
        endDate: startOfDay,
      );
      notifyListeners();
    } catch (e) {
      _error = 'Không thể tải lịch sử: $e';
      notifyListeners();
    }
  }

  /// Update an existing transaction
  Future<bool> updateTransaction({
    required String transactionId,
    required double newQuantity,
    String? notes,
  }) async {
    try {
      await _inventoryRepository.updateTransaction(
        transactionId: transactionId,
        newQuantity: newQuantity,
        notes: notes,
      );
      notifyListeners();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể cập nhật: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete an existing transaction
  Future<bool> deleteTransaction(String transactionId) async {
    try {
      await _inventoryRepository.deleteTransaction(transactionId);
      notifyListeners();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể xóa: $e';
      notifyListeners();
      return false;
    }
  }
}
