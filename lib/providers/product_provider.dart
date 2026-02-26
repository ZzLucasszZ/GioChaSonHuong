import 'package:flutter/foundation.dart';

import '../core/utils/logger.dart';
import '../data/database/database_helper.dart';
import '../data/models/product.dart';
import '../data/repositories/order_repository.dart';
import '../data/repositories/product_repository.dart';
import '../services/google_drive_backup_service.dart';

/// Provider for product state management
class ProductProvider extends ChangeNotifier {
  final ProductRepository _repository;
  final OrderRepository _orderRepository;
  final GoogleDriveBackupService _gDriveBackup = GoogleDriveBackupService();

  List<Product> _products = [];
  List<Product> _lowStockProducts = [];
  Map<String, double> _orderedQuantities = {};
  bool _isLoading = false;
  String? _error;

  ProductProvider(DatabaseHelper dbHelper)
      : _repository = ProductRepository(dbHelper),
        _orderRepository = OrderRepository(dbHelper);

  void _triggerAutoBackup() {
    _gDriveBackup.autoBackup().catchError((e) {
      AppLogger.warning('Auto-backup skipped: $e', tag: 'AutoBackup');
    });
  }

  // Getters
  List<Product> get products => _products;
  List<Product> get lowStockProducts => _lowStockProducts;
  Map<String, double> get orderedQuantities => _orderedQuantities;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all active products
  Future<void> loadProducts({String? category, DateTime? untilDate}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _repository.getActiveProducts(category: category);
      // Load ordered quantities
      _orderedQuantities = await _orderRepository.getTotalOrderedQuantities(untilDate: untilDate);
      _error = null;
    } catch (e) {
      _error = 'Không thể tải danh sách sản phẩm: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load low stock products
  Future<void> loadLowStockProducts() async {
    try {
      _lowStockProducts = await _repository.getLowStockProducts();
      // Also reload ordered quantities when checking low stock
      _orderedQuantities = await _orderRepository.getTotalOrderedQuantities();
      notifyListeners();
    } catch (e) {
      _error = 'Không thể tải sản phẩm sắp hết: $e';
      notifyListeners();
    }
  }

  /// Create a new product
  Future<Product?> createProduct({
    required String name,
    required String unit,
    required double basePrice,
    String? sku,
    String? category,
    double currentStock = 0,
    double minStockAlert = 10,
  }) async {
    try {
      final product = Product.create(
        name: name,
        unit: unit,
        basePrice: basePrice,
        sku: sku,
        category: category,
        currentStock: currentStock,
        minStockAlert: minStockAlert,
      );

      await _repository.insert(product);
      _products.insert(0, product);
      notifyListeners();
      _triggerAutoBackup();

      return product;
    } catch (e) {
      _error = 'Không thể tạo sản phẩm: $e';
      notifyListeners();
      return null;
    }
  }

  /// Update product
  Future<bool> updateProduct(Product product) async {
    try {
      await _repository.update(product, product.id);

      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }

      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể cập nhật sản phẩm: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete product
  Future<bool> deleteProduct(String id) async {
    try {
      await _repository.delete(id);
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể xóa sản phẩm: $e';
      notifyListeners();
      return false;
    }
  }

  /// Add product (convenience method)
  Future<Product?> addProduct({
    required String name,
    required String unit,
    required double basePrice,
    double minStockLevel = 0,
    double minStockAlert = 0,
  }) async {
    return await createProduct(
      name: name,
      unit: unit,
      basePrice: basePrice,
      currentStock: 0,
      minStockAlert: minStockAlert,
    );
  }

  /// Update product by ID (convenience method)
  Future<bool> updateProductById(
    String id, {
    required String name,
    required String unit,
    required double basePrice,
    required double minStockLevel,
    required double minStockAlert,
  }) async {
    final existingProduct = _products.firstWhere((p) => p.id == id);
    final updatedProduct = existingProduct.copyWith(
      name: name,
      unit: unit,
      basePrice: basePrice,
      minStockAlert: minStockAlert,
    );
    return await updateProduct(updatedProduct);
  }

  /// Update stock
  Future<bool> updateStock(String productId, double newStock) async {
    try {
      await _repository.updateStock(productId, newStock);

      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        _products[index] = _products[index].copyWith(currentStock: newStock);
        notifyListeners();
      }

      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể cập nhật tồn kho: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get product by ID
  Product? getById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Search products
  Future<List<Product>> search(String query) async {
    try {
      return await _repository.search(query);
    } catch (e) {
      _error = 'Không thể tìm kiếm: $e';
      notifyListeners();
      return [];
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
