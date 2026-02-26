import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/thousands_separator_formatter.dart';
import '../../../data/models/order.dart';
import '../../../data/models/order_item.dart';
import '../../../data/models/product.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/product_provider.dart';

/// Dialog to create a new order with flexible item management
class CreateOrderDialog extends StatefulWidget {
  final String restaurantId;
  final DateTime selectedDate;
  final VoidCallback? onOrderCreated;

  const CreateOrderDialog({
    super.key,
    required this.restaurantId,
    required this.selectedDate,
    this.onOrderCreated,
  });

  @override
  State<CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<CreateOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tableCountController = TextEditingController(text: '1');
  OrderSession _selectedSession = OrderSession.morning;
  
  // List of order items with editable quantity and price
  final List<_EditableItem> _items = [];
  
  // Products list for dropdown
  List<Product> _allProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final productProvider = context.read<ProductProvider>();
    await productProvider.loadProducts();
    
    setState(() {
      _allProducts = productProvider.products;
      _isLoading = false;
      
      // Initialize with default items based on 1 table
      _initializeDefaultItems();
    });
  }

  /// Check if a product unit should be excluded from auto table-count multiplication.
  /// Units like "kg", "hộp", etc. are purchased per fixed quantity.
  bool _isTableExcludedUnit(String unit) {
    final lower = unit.toLowerCase().trim();
    const excludedUnits = ['kg', 'hộp', 'chai', 'lon', 'thùng', 'bịch', 'túi', 'can', 'lít', 'bao'];
    return excludedUnits.contains(lower);
  }

  /// Check if unit is "Gói" — uses ceil(tableCount / 2) rounding.
  bool _isGoiUnit(String unit) {
    return unit.toLowerCase().trim() == 'gói';
  }

  void _initializeDefaultItems() {
    final tableCount = int.tryParse(_tableCountController.text) ?? 1;
    _items.clear();
    
    for (final product in _allProducts) {
      final defaultQty = product.defaultQuantityPerTable;
      if (defaultQty > 0) {
        int quantity;
        if (_isGoiUnit(product.unit)) {
          // Gói: quy tròn lên — 1→1, 2→1, 3→2, 4→2, 5→3
          quantity = (tableCount / 2).ceil();
        } else if (_isTableExcludedUnit(product.unit)) {
          quantity = defaultQty;
        } else {
          quantity = defaultQty * tableCount;
        }
        _items.add(_EditableItem(
          product: product,
          quantity: quantity,
          unitPrice: product.defaultPrice,
        ));
      }
    }
    setState(() {});
  }

  void _updateQuantitiesFromTableCount() {
    final tableCount = int.tryParse(_tableCountController.text) ?? 1;
    
    for (final item in _items) {
      if (_isGoiUnit(item.product.unit)) {
        // Gói: quy tròn lên — ceil(tableCount / 2)
        item.quantity = (tableCount / 2).ceil();
      } else if (_isTableExcludedUnit(item.product.unit)) {
        continue;
      } else {
        item.quantity = item.product.defaultQuantityPerTable * tableCount;
      }
    }
    setState(() {});
  }

  void _addProduct(Product product) {
    // Close keyboard
    FocusScope.of(context).unfocus();
    
    // Check if product already exists
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);
    if (existingIndex != -1) {
      // Increase quantity
      setState(() {
        _items[existingIndex].quantity++;
      });
    } else {
      // Add new item
      setState(() {
        _items.add(_EditableItem(
          product: product,
          quantity: 1,
          unitPrice: product.defaultPrice,
        ));
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  double get _totalAmount {
    return _items.fold(0, (sum, item) => sum + item.subtotal);
  }

  Future<void> _createOrder() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng thêm ít nhất 1 sản phẩm'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Filter out items with quantity = 0
    final validItems = _items.where((item) => item.quantity > 0).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng có ít nhất 1 sản phẩm với số lượng > 0'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final orderItems = validItems.map((item) {
      return OrderItem.create(
        orderId: '', // Will be set by provider
        productId: item.product.id,
        productName: item.product.name,
        quantity: item.quantity.toDouble(),
        unit: item.product.unit,
        unitPrice: item.unitPrice,
      );
    }).toList();

    final orderProvider = context.read<OrderProvider>();
    final order = await orderProvider.createOrder(
      context,
      restaurantId: widget.restaurantId,
      orderDate: DateTime.now(),
      deliveryDate: widget.selectedDate,
      items: orderItems,
      notes: '${_tableCountController.text} bàn',
      session: _selectedSession,
    );

    if (order != null && mounted) {
      widget.onOrderCreated?.call();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo đơn hàng thành công'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tableCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Container(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_shopping_cart, color: Colors.white),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Tạo đơn hàng',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Session selector
                            const Text(
                              'Buổi giao hàng',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSessionButton(
                                    '🌅 Sáng',
                                    OrderSession.morning,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSessionButton(
                                    '🌆 Chiều',
                                    OrderSession.afternoon,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Table count (as default value reference)
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _tableCountController,
                                    autofocus: false,
                                    decoration: const InputDecoration(
                                      labelText: 'Số bàn',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      helperText: 'Dùng để tính số lượng mặc định',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: () {
                                    FocusScope.of(context).unfocus();
                                    _updateQuantitiesFromTableCount();
                                  },
                                  child: const Text('Áp dụng'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Items header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Sản phẩm',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${_items.length} mặt hàng',
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Items list
                            ..._items.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              return _buildItemRow(item, index);
                            }),

                            // Add product dropdown
                            const SizedBox(height: 12),
                            _buildAddProductDropdown(),

                            const SizedBox(height: 20),

                            // Total
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Tổng cộng:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    formatCurrency(_totalAmount.round()),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Hủy'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: _createOrder,
                              child: const Text('Tạo đơn hàng'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSessionButton(String label, OrderSession session) {
    final isSelected = _selectedSession == session;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedSession = session;
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primary.withOpacity(0.1) : null,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildItemRow(_EditableItem item, int index) {
    return Card(
      key: ValueKey('${item.product.id}_${item.quantity}_${item.unitPrice}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: () => _removeItem(index),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Quantity controls
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: item.quantity > 0
                            ? () {
                                setState(() {
                                  item.quantity--;
                                });
                              }
                            : null,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(
                        width: 50,
                        child: TextFormField(
                          initialValue: item.quantity.toString(),
                          autofocus: false,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              item.quantity = int.tryParse(value) ?? 0;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () {
                          setState(() {
                            item.quantity++;
                          });
                        },
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(item.product.unit, style: const TextStyle(color: AppColors.textSecondary)),
                const Spacer(),
                // Price field
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    initialValue: formatNumber(item.unitPrice.round()),
                    autofocus: false,
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                    decoration: const InputDecoration(
                      suffixText: '₫',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        item.unitPrice = double.tryParse(value.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Subtotal
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Thành tiền: ${formatCurrency(item.subtotal.round())}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddProductDropdown() {
    // Products not yet in the list
    final availableProducts = _allProducts.where((p) {
      return !_items.any((item) => item.product.id == p.id);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          const Icon(Icons.add_circle_outline, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: availableProducts.isEmpty
                ? const Text(
                    'Đã thêm tất cả sản phẩm',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                : DropdownButton<Product>(
                    isExpanded: true,
                    hint: const Text('Thêm sản phẩm...'),
                    underline: const SizedBox(),
                    items: availableProducts.map((product) {
                      return DropdownMenuItem<Product>(
                        value: product,
                        child: Text(product.name),
                      );
                    }).toList(),
                    onChanged: (product) {
                      if (product != null) {
                        _addProduct(product);
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Editable order item with quantity and price
class _EditableItem {
  final Product product;
  int quantity;
  double unitPrice;

  _EditableItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;
}
