import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/thousands_separator_formatter.dart';
import '../../core/utils/vietnamese_utils.dart';
import '../../data/models/models.dart';
import '../../providers/product_provider.dart';

String formatCurrency(int amount) {
  return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫';
}

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load products when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý sản phẩm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showProductDialog(),
            tooltip: 'Thêm sản phẩm',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm sản phẩm...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Products list
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                var products = provider.products;

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  final normalizedQuery = normalizeForSearch(_searchQuery);
                  products = products.where((p) =>
                      normalizeForSearch(p.name).contains(normalizedQuery) ||
                      normalizeForSearch(p.unit).contains(normalizedQuery)
                  ).toList();
                }
                
                // Sort alphabetically
                products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off : Icons.inventory_2_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Không tìm thấy sản phẩm nào'
                              : 'Chưa có sản phẩm nào',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _showProductDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm sản phẩm'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            product.name[0],
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${product.unit} • ${formatCurrency(product.basePrice.toInt())}'),
                            if (product.minStockAlert > 0)
                              Text(
                                'Cảnh báo tồn: ${product.minStockLevel.toInt()} ${product.unit}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showProductDialog(product: product);
                            } else if (value == 'delete') {
                              _deleteProduct(product);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Chỉnh sửa'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: AppColors.error, size: 20),
                                  SizedBox(width: 8),
                                  Text('Xóa', style: TextStyle(color: AppColors.error)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProductDialog({Product? product}) async {
    final nameController = TextEditingController(text: product?.name ?? '');
    final unitController = TextEditingController(text: product?.unit ?? 'Kg');
    final priceController = TextEditingController(
      text: product != null ? formatNumber(product.basePrice.toInt()) : '',
    );
    final minStockController = TextEditingController(
      text: product?.minStockLevel.toInt().toString() ?? '0',
    );
    final minAlertController = TextEditingController(
      text: product?.minStockAlert.toInt().toString() ?? '0',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product == null ? 'Thêm sản phẩm' : 'Chỉnh sửa sản phẩm'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên sản phẩm *',
                  border: OutlineInputBorder(),
                ),
                autofocus: product == null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Đơn vị *',
                  hintText: 'Ví dụ: Kg, Hộp, Thùng',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Giá cơ bản *',
                  suffixText: '₫',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minStockController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Tồn kho tối thiểu',
                  hintText: 'Để 0 nếu không cần',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minAlertController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Cảnh báo tồn kho',
                  hintText: 'Để 0 để tắt cảnh báo',
                  border: OutlineInputBorder(),
                  helperText: 'Cảnh báo khi tồn kho <= giá trị này',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final unit = unitController.text.trim();
              final price = double.tryParse(priceController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
              final minStock = double.tryParse(minStockController.text) ?? 0;
              final minAlert = double.tryParse(minAlertController.text) ?? 0;

              if (name.isEmpty || unit.isEmpty || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng điền đầy đủ thông tin bắt buộc'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              Navigator.pop(context, {
                'name': name,
                'unit': unit,
                'price': price,
                'minStock': minStock,
                'minAlert': minAlert,
              });
            },
            child: Text(product == null ? 'Thêm' : 'Lưu'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        final provider = context.read<ProductProvider>();

        if (product == null) {
          // Add new product
          await provider.addProduct(
            name: result['name'],
            unit: result['unit'],
            basePrice: result['price'],
            minStockLevel: result['minStock'],
            minStockAlert: result['minAlert'],
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã thêm sản phẩm'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          // Update existing product
          await provider.updateProductById(
            product.id,
            name: result['name'],
            unit: result['unit'],
            basePrice: result['price'],
            minStockLevel: result['minStock'],
            minStockAlert: result['minAlert'],
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã cập nhật sản phẩm'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa sản phẩm "${product.name}"?\n\n'
          'Lưu ý: Sản phẩm này sẽ vẫn xuất hiện trong các đơn hàng cũ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final provider = context.read<ProductProvider>();
        await provider.deleteProduct(product.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa sản phẩm'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
