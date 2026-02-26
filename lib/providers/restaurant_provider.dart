import 'package:flutter/foundation.dart';

import '../core/utils/logger.dart';
import '../data/database/database_helper.dart';
import '../data/models/restaurant.dart';
import '../data/repositories/restaurant_repository.dart';
import '../services/google_drive_backup_service.dart';

/// Provider for restaurant state management
class RestaurantProvider extends ChangeNotifier {
  final RestaurantRepository _repository;
  final GoogleDriveBackupService _gDriveBackup = GoogleDriveBackupService();
  
  List<Restaurant> _restaurants = [];
  bool _isLoading = false;
  String? _error;

  RestaurantProvider(DatabaseHelper dbHelper)
      : _repository = RestaurantRepository(dbHelper);

  void _triggerAutoBackup() {
    _gDriveBackup.autoBackup().catchError((e) {
      AppLogger.warning('Auto-backup skipped: $e', tag: 'AutoBackup');
    });
  }

  // Getters
  List<Restaurant> get restaurants => _restaurants;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all restaurants
  Future<void> loadRestaurants() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _restaurants = await _repository.getActiveRestaurants();
      _error = null;
    } catch (e) {
      _error = 'Không thể tải danh sách nhà hàng: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new restaurant
  Future<Restaurant?> createRestaurant({
    required String name,
    String? phone,
    String? address,
  }) async {
    if (name.trim().isEmpty) {
      _error = 'Vui lòng nhập tên nhà hàng';
      notifyListeners();
      return null;
    }

    // Check for duplicate name (case-insensitive)
    final trimmedName = name.trim();
    final normalizedNewName = trimmedName.toLowerCase();
    final isDuplicate = _restaurants.any((r) => 
      r.name.toLowerCase() == normalizedNewName
    );

    if (isDuplicate) {
      _error = 'Tên nhà hàng "$trimmedName" đã tồn tại';
      notifyListeners();
      return null;
    }

    try {
      final restaurant = Restaurant.create(
        name: trimmedName,
        phone: phone ?? '',
        address: address ?? '',
      );
      await _repository.insert(restaurant);
      
      // Add to list immediately
      _restaurants.insert(0, restaurant);
      _error = null;
      notifyListeners();
      _triggerAutoBackup();
      
      return restaurant;
    } catch (e) {
      _error = 'Không thể tạo nhà hàng: $e';
      notifyListeners();
      return null;
    }
  }

  /// Update restaurant
  Future<bool> updateRestaurant(Restaurant restaurant) async {
    try {
      await _repository.update(restaurant, restaurant.id);
      
      // Update in list
      final index = _restaurants.indexWhere((r) => r.id == restaurant.id);
      if (index != -1) {
        _restaurants[index] = restaurant;
        notifyListeners();
      }
      
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể cập nhật nhà hàng: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete restaurant
  Future<bool> deleteRestaurant(String id) async {
    try {
      await _repository.delete(id);
      _restaurants.removeWhere((r) => r.id == id);
      notifyListeners();
      _triggerAutoBackup();
      return true;
    } catch (e) {
      _error = 'Không thể xóa nhà hàng: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get restaurant by ID
  Restaurant? getById(String id) {
    try {
      return _restaurants.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
