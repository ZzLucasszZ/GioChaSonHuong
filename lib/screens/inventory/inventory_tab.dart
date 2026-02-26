import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/vietnamese_utils.dart';
import '../../data/models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/product_provider.dart';
import 'widgets/add_stock_dialog.dart';
import 'widgets/stock_history_screen.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  bool _isLoading = false;
  String _searchQuery = '';
  DateTime? _selectedDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    await context.read<ProductProvider>().loadProducts(untilDate: _selectedDate);
    await context.read<InventoryProvider>().loadInventories();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
      helpText: 'Chọn ngày kiểm tra tồn kho',
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      await loadData();
    }
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
    });
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tồn kho'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StockHistoryScreen()),
              );
            },
            tooltip: 'Lịch sử nhập kho',
          ),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, _) {
          if (productProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = productProvider.products;
          
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có sản phẩm',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Date picker section
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Chọn ngày kiểm tra tồn kho',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectDate,
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
                                  : 'Chọn ngày',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        if (_selectedDate != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _clearDate,
                            icon: const Icon(Icons.close),
                            color: AppColors.error,
                            tooltip: 'Xóa bộ lọc ngày',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                child: Builder(
                  builder: (context) {
                    // Filter by search query
                    var filteredProducts = products;
                    if (_searchQuery.isNotEmpty) {
                      final normalizedQuery = normalizeForSearch(_searchQuery);
                      filteredProducts = products.where((p) => 
                          normalizeForSearch(p.name).contains(normalizedQuery) ||
                          normalizeForSearch(p.unit).contains(normalizedQuery)
                      ).toList();
                    }
                    
                    // Sort alphabetically
                    filteredProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                    if (filteredProducts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không tìm thấy sản phẩm nào',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        final orderedQty = productProvider.orderedQuantities[product.id] ?? 0;
                        final remaining = product.currentStock - orderedQty;
                        final isLowStock = product.minStockAlert > 0 && product.currentStock <= product.minStockLevel;
                        final isShortage = remaining < 0;

                        return _buildInventoryCard(
                          product, 
                          product.currentStock.round(), 
                          orderedQty.round(),
                          remaining.round(),
                          isLowStock,
                          isShortage,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AddStockDialog(
              onStockAdded: loadData,
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nhập kho'),
      ),
    );
  }

  Widget _buildInventoryCard(
    Product product, 
    int currentStock,
    int orderedQty,
    int remaining,
    bool isLowStock,
    bool isShortage,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AddStockDialog(
              product: product,
              onStockAdded: loadData,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isShortage
                      ? AppColors.error.withOpacity(0.1)
                      : isLowStock 
                          ? AppColors.warning.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isShortage 
                      ? Icons.error_outline
                      : isLowStock 
                          ? Icons.warning_amber 
                          : Icons.inventory_2,
                  color: isShortage 
                      ? AppColors.error
                      : isLowStock 
                          ? AppColors.warning 
                          : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(product.defaultPrice.round()),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Stock info table
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStockRow('Tồn kho:', currentStock, product.unit, AppColors.textPrimary),
                  const SizedBox(height: 2),
                  _buildStockRow('Đã đặt:', orderedQty, product.unit, AppColors.info),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isShortage 
                          ? AppColors.error.withOpacity(0.1)
                          : remaining <= product.minStockLevel
                              ? AppColors.warning.withOpacity(0.1)
                              : AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Còn lại: ',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$remaining ${product.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isShortage 
                                ? AppColors.error
                                : remaining <= product.minStockLevel
                                    ? AppColors.warning
                                    : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockRow(String label, int quantity, String unit, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$quantity $unit',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
