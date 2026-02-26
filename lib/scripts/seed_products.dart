import 'package:sqflite/sqflite.dart';
import '../data/database/database_helper.dart';
import '../data/models/product.dart';

/// Script to add initial products to the database
Future<void> seedProducts() async {
  final dbHelper = DatabaseHelper.instance;
  final db = await dbHelper.database;

  // List of products to add
  final products = [
    Product.create(
      name: 'Chả lá',
      sku: 'CL001',
      unit: 'Cái',
      basePrice: 3500,
      category: 'Thực phẩm chế biến',
      minStockAlert: 300,
    ),
    Product.create(
      name: 'Nem Hộp',
      sku: 'NEM001',
      unit: 'Cái',
      basePrice: 3500,
      category: 'Thực phẩm chế biến',
      minStockAlert: 100,
    ),
    Product.create(
      name: 'Bánh bao',
      sku: 'BB001',
      unit: 'Cái',
      basePrice: 3300,
      category: 'Thực phẩm chế biến',
      minStockAlert: 200,
    ),
    Product.create(
      name: 'Rế',
      sku: 'RE001',
      unit: 'Gói',
      basePrice: 52000,
      category: 'Thực phẩm',
      minStockAlert: 10,
    ),
    Product.create(
      name: 'Lụi',
      sku: 'LU001',
      unit: 'Cái',
      basePrice: 3500,
      category: 'Thực phẩm',
      minStockAlert: 200,
    ),
    Product.create(
      name: 'Bánh Xếp',
      sku: 'BX001',
      unit: 'Gói',
      basePrice: 45000,
      category: 'Thực phẩm',
      minStockAlert: 5,
    ),
    Product.create(
      name: 'Bánh Bao Không Nhân',
      sku: 'BBKN001',
      unit: 'Cái',
      basePrice: 2500,
      category: 'Thực phẩm',
      minStockAlert: 100,
    ),
    Product.create(
      name: 'Giò Lụa',
      sku: 'GL001',
      unit: 'Kg',
      basePrice: 130000,
      category: 'Thực phẩm',
    ),
    Product.create(
      name: 'Nem chua',
      sku: 'NC001',
      unit: 'Kg',
      basePrice: 150000,
      category: 'Thực phẩm',
    ),
    Product.create(
      name: 'Giò Thủ',
      sku: 'GT001',
      unit: 'Kg',
      basePrice: 140000,
      category: 'Thực phẩm',
    ),
    Product.create(
      name: 'Thịt Nguội',
      sku: 'TN001',
      unit: 'Kg',
      basePrice: 150000,
      category: 'Thực phẩm',
    ),
    Product.create(
      name: 'Giò Viên',
      sku: 'GV001',
      unit: 'Kg',
      basePrice: 150000,
      category: 'Thực phẩm',
    ),
  ];

  // Insert each product
  for (final product in products) {
    try {
      await db.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ Đã thêm: ${product.name} - ${product.basePrice}đ');
    } catch (e) {
      print('✗ Lỗi khi thêm ${product.name}: $e');
    }
  }

  print('\nHoàn thành! Đã thêm ${products.length} sản phẩm.');
}
