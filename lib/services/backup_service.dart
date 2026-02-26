import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../data/database/database_helper.dart';

/// Service for backing up and restoring app data
class BackupService {
  final DatabaseHelper _dbHelper;

  BackupService(this._dbHelper);

  /// Export all data to JSON format
  Future<Map<String, dynamic>> exportData() async {
    final db = await _dbHelper.database;

    // Export all tables
    final products = await db.query('products');
    final restaurants = await db.query('restaurants');
    final orders = await db.query('orders');
    final orderItems = await db.query('order_items');
    final inventoryTransactions = await db.query('inventory_transactions');

    return {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'data': {
        'products': products,
        'restaurants': restaurants,
        'orders': orders,
        'order_items': orderItems,
        'inventory_transactions': inventoryTransactions,
      },
    };
  }

  /// Export data and save to file
  Future<String> exportToFile() async {
    final data = await exportData();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    // Create backup file name with timestamp
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'order_inventory_backup_$timestamp.json';

    // Save to temporary directory
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonString);

    return file.path;
  }

  /// Share backup file
  Future<void> shareBackup() async {
    final filePath = await exportToFile();
    final file = File(filePath);
    
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Backup dữ liệu Order Inventory',
      text: 'File backup dữ liệu ứng dụng Order Inventory',
    );
  }

  /// Import data from JSON
  Future<void> importData(Map<String, dynamic> backupData) async {
    final db = await _dbHelper.database;

    // Validate backup format
    if (!backupData.containsKey('version') || !backupData.containsKey('data')) {
      throw Exception('Invalid backup format');
    }

    final data = backupData['data'] as Map<String, dynamic>;

    // Clear existing data (optional - can be made configurable)
    await db.transaction((txn) async {
      await txn.delete('inventory_transactions');
      await txn.delete('order_items');
      await txn.delete('orders');
      await txn.delete('restaurants');
      await txn.delete('products');

      // Import products
      if (data.containsKey('products')) {
        final products = data['products'] as List;
        for (final product in products) {
          await txn.insert('products', product as Map<String, dynamic>);
        }
      }

      // Import restaurants
      if (data.containsKey('restaurants')) {
        final restaurants = data['restaurants'] as List;
        for (final restaurant in restaurants) {
          await txn.insert('restaurants', restaurant as Map<String, dynamic>);
        }
      }

      // Import orders
      if (data.containsKey('orders')) {
        final orders = data['orders'] as List;
        for (final order in orders) {
          await txn.insert('orders', order as Map<String, dynamic>);
        }
      }

      // Import order items
      if (data.containsKey('order_items')) {
        final orderItems = data['order_items'] as List;
        for (final item in orderItems) {
          await txn.insert('order_items', item as Map<String, dynamic>);
        }
      }

      // Import inventory transactions
      if (data.containsKey('inventory_transactions')) {
        final transactions = data['inventory_transactions'] as List;
        for (final transaction in transactions) {
          await txn.insert('inventory_transactions', transaction as Map<String, dynamic>);
        }
      }
    });
  }

  /// Import from file path
  Future<void> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found');
    }

    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    await importData(data);
  }

  /// Get backup info without importing
  Future<Map<String, dynamic>> getBackupInfo(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found');
    }

    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    final backupData = data['data'] as Map<String, dynamic>;
    
    return {
      'version': data['version'],
      'exportDate': data['exportDate'],
      'productsCount': (backupData['products'] as List?)?.length ?? 0,
      'restaurantsCount': (backupData['restaurants'] as List?)?.length ?? 0,
      'ordersCount': (backupData['orders'] as List?)?.length ?? 0,
      'orderItemsCount': (backupData['order_items'] as List?)?.length ?? 0,
      'transactionsCount': (backupData['inventory_transactions'] as List?)?.length ?? 0,
    };
  }
}
