import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/thousands_separator_formatter.dart';
import '../../../core/utils/vietnamese_utils.dart';
import '../../../data/models/models.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/product_provider.dart';

String formatCurrency(int amount) {
  return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫';
}

// Helper class for editable order items
class _EditableOrderItem {
  final Product product;
  double quantity;
  double unitPrice;
  final TextEditingController quantityController;
  final TextEditingController priceController;

  _EditableOrderItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  })  : quantityController = TextEditingController(
          text: product.unit.toLowerCase() == 'kg' 
              ? quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 3).replaceAll(RegExp(r'\.?0+$'), '')
              : quantity.toInt().toString()
        ),
        priceController = TextEditingController(text: _formatPrice(unitPrice.toInt()));

  void dispose() {
    quantityController.dispose();
    priceController.dispose();
  }

  double get total => quantity * unitPrice;

  static String _formatPrice(int price) {
    if (price == 0) return '0';
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

class AddOrderDialog extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final DateTime selectedDate;

  const AddOrderDialog({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.selectedDate,
  });

  @override
  State<AddOrderDialog> createState() => _AddOrderDialogState();
}

class _AddOrderDialogState extends State<AddOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tableCountController = TextEditingController();
  bool _isLoading = false;
  List<_EditableOrderItem> _orderItems = [];
  int _totalAmount = 0;
  OrderSession _selectedSession = OrderSession.morning;
  int _lastAppliedTableCount = 0; // Track the last applied table count for ratio recalculation

  String _productSearchQuery = '';
  final TextEditingController _productSearchController = TextEditingController();

  @override
  void dispose() {
    _tableCountController.dispose();
    _productSearchController.dispose();
    for (final item in _orderItems) {
      item.dispose();
    }
    super.dispose();
  }

  /// Check if a product unit should be excluded from auto table-count multiplication.
  /// Units like "kg", "hộp", "chai", "lon", "thùng", "bịch", "túi" are
  /// purchased per fixed quantity regardless of table count.
  bool _isTableExcludedUnit(String unit) {
    final lower = unit.toLowerCase().trim();
    const excludedUnits = ['kg', 'hộp', 'chai', 'lon', 'thùng', 'bịch', 'túi', 'can', 'lít', 'bao'];
    return excludedUnits.contains(lower);
  }

  void _applyTableCount(int tableCount, List<Product> products) {
    if (_orderItems.isEmpty) {
      // No existing items → add default items (Chả lá, Nem Hộp)
      final chaLa = products.cast<Product?>().firstWhere((p) => p?.name == 'Chả lá', orElse: () => null);
      final nemHop = products.cast<Product?>().firstWhere((p) => p?.name == 'Nem Hộp', orElse: () => null);

      if (chaLa != null) {
        _orderItems.add(_EditableOrderItem(
          product: chaLa,
          quantity: _calculateDefaultQuantity(chaLa, tableCount),
          unitPrice: chaLa.basePrice,
        ));
      }

      if (nemHop != null) {
        _orderItems.add(_EditableOrderItem(
          product: nemHop,
          quantity: _calculateDefaultQuantity(nemHop, tableCount),
          unitPrice: nemHop.basePrice,
        ));
      }
    } else {
      // Items already exist → recalculate quantities based on table count change
      final oldTableCount = _lastAppliedTableCount > 0 ? _lastAppliedTableCount : 1;
      
      for (final item in _orderItems) {
        // Gói: always use ceil(tableCount / 2) formula
        if (item.product.unit.toLowerCase().trim() == 'gói') {
          final newQty = (tableCount / 2).ceil().toDouble();
          item.quantity = newQty;
          item.quantityController.text = newQty.toInt().toString();
          continue;
        }

        // Skip items with excluded units (kg, hộp, etc.)
        if (_isTableExcludedUnit(item.product.unit)) continue;
        
        // Parse current quantity from controller (user may have edited it)
        final currentQty = double.tryParse(item.quantityController.text) ?? item.quantity;
        
        // Calculate ratio and apply new table count
        final perTable = currentQty / oldTableCount;
        final newQty = (perTable * tableCount).roundToDouble();
        
        item.quantity = newQty;
        if (item.product.unit.toLowerCase() == 'kg') {
          item.quantityController.text = newQty.toStringAsFixed(
              newQty.truncateToDouble() == newQty ? 0 : 3)
            .replaceAll(RegExp(r'\.?0+$'), '');
        } else {
          item.quantityController.text = newQty.toInt().toString();
        }
      }
    }

    _lastAppliedTableCount = tableCount;

    setState(() {
      _updateTotal();
    });
  }

  void _updateTotal() {
    int total = 0;
    for (final item in _orderItems) {
      final qty = double.tryParse(item.quantityController.text) ?? 0;
      final price = double.tryParse(item.priceController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      item.quantity = qty;
      item.unitPrice = price;
      total += (qty * price).round();
    }
    setState(() {
      _totalAmount = total;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _orderItems[index].dispose();
      _orderItems.removeAt(index);
      _updateTotal();
    });
  }

  void _addProduct(Product product) {
    // Close keyboard
    FocusScope.of(context).unfocus();
    
    // Check if product already exists
    final existingIndex = _orderItems.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      // Increase quantity by default amount
      final tableCount = int.tryParse(_tableCountController.text) ?? 1;
      final item = _orderItems[existingIndex];
      final defaultQty = _calculateDefaultQuantity(product, tableCount);
      item.quantity += defaultQty;
      item.quantityController.text = item.quantity.toInt().toString();
      _updateTotal();
      return;
    }

    // Add new product with default quantity based on table count
    final tableCount = int.tryParse(_tableCountController.text) ?? 1;
    final defaultQty = _calculateDefaultQuantity(product, tableCount);
    
    setState(() {
      _orderItems.add(_EditableOrderItem(
        product: product,
        quantity: defaultQty,
        unitPrice: product.basePrice,
      ));
      _updateTotal();
    });
    
    // Ensure no auto-focus after adding product
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  // Calculate default quantity based on product name and table count
  double _calculateDefaultQuantity(Product product, int tableCount) {
    // Gói: quy tròn lên — 1→1, 2→1, 3→2, 4→2, 5→3
    if (product.unit.toLowerCase().trim() == 'gói') {
      return (tableCount / 2).ceil().toDouble();
    }

    // Skip auto-calculate for units that don't scale with table count
    if (_isTableExcludedUnit(product.unit)) {
      return 1.0;
    }
    
    // Quy tắc đặc biệt cho từng món
    switch (product.name) {
      case 'Chả lá':
      case 'Nem':
      case 'Bánh bao':
        return (tableCount * 10).toDouble();
      default:
        // Mặc định: 10 cái/bàn cho tất cả sản phẩm khác
        return (tableCount * 10).toDouble();
    }
  }

  void _showAddProductBottomSheet(List<Product> availableProducts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Chọn sản phẩm',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _productSearchController,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: 'Tìm sản phẩm...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _productSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _productSearchController.clear();
                                  _productSearchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _productSearchQuery = value;
                      });
                    },
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // Filter by search query
                      var filteredProducts = availableProducts;
                      if (_productSearchQuery.isNotEmpty) {
                        final normalizedQuery = normalizeForSearch(_productSearchQuery);
                        filteredProducts = availableProducts.where((p) => 
                            normalizeForSearch(p.name).contains(normalizedQuery)
                        ).toList();
                      }
                      // Sort alphabetically
                      filteredProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                      if (filteredProducts.isEmpty) {
                        return Center(
                          child: Text(
                            _productSearchQuery.isNotEmpty 
                                ? 'Không tìm thấy sản phẩm nào'
                                : 'Đã thêm hết sản phẩm',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.builder(
                          controller: scrollController,
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return ListTile(
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
                              title: Text(product.name),
                              subtitle: Text(formatCurrency(product.basePrice.toInt())),
                              trailing: const Icon(Icons.add_circle_outline),
                              onTap: () {
                                _addProduct(product);
                                _productSearchController.clear();
                                setState(() {
                                  _productSearchQuery = '';
                                });
                                FocusScope.of(context).unfocus();
                                Navigator.pop(context);
                              },
                            );
                          },
                        );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitOrder() async {
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng thêm ít nhất một sản phẩm'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate quantities
    for (final item in _orderItems) {
      if (item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Số lượng ${item.product.name} phải lớn hơn 0'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final orderProvider = context.read<OrderProvider>();

      // Convert editable items to OrderItem
      final orderItems = _orderItems.map((item) {
        return OrderItem.create(
          orderId: '', // Will be set by createOrder
          productId: item.product.id,
          productName: item.product.name,
          quantity: item.quantity,
          unit: item.product.unit,
          unitPrice: item.unitPrice,
        );
      }).toList();

      // Tạo đơn hàng
      final tableText = _tableCountController.text.isNotEmpty
          ? '${_tableCountController.text} bàn'
          : '';
      
      final order = await orderProvider.createOrder(
        context,
        restaurantId: widget.restaurantId,
        orderDate: DateTime.now(),
        deliveryDate: widget.selectedDate,
        items: orderItems,
        notes: tableText,
        session: _selectedSession,
      );

      if (order != null && mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tạo đơn hàng thành công'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tạo đơn: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.products;

    // Get products that haven't been added yet
    final availableProducts = products.where((p) {
      final alreadyAdded = _orderItems.any((item) => item.product.id == p.id);
      if (alreadyAdded) return false;
      
      // Apply search filter
      if (_productSearchQuery.isNotEmpty) {
        final normalizedQuery = normalizeForSearch(_productSearchQuery);
        return normalizeForSearch(p.name).contains(normalizedQuery);
      }
      return true;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Thêm đơn hàng mới'),
          actions: [
            FilledButton.icon(
              onPressed: _isLoading || _orderItems.isEmpty ? null : _submitOrder,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text('Tạo đơn'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              // Session selector and table count - scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Restaurant and Date Info Card
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.restaurant, size: 20, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.restaurantName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Ngày giao: ${DateFormat('dd/MM/yyyy').format(widget.selectedDate)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Header section
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Session selector
                            const Text(
                              'Buổi giao hàng:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSessionButton(
                                    OrderSession.morning,
                                    '🌅 Sáng',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSessionButton(
                                    OrderSession.afternoon,
                                    '🌆 Chiều',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Table count - auto-adjusts all items
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _tableCountController,
                                    autofocus: false,
                                    decoration: InputDecoration(
                                      labelText: 'Số bàn',
                                      hintText: 'Nhập số bàn',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      suffixText: _lastAppliedTableCount > 0
                                          ? '$_lastAppliedTableCount'
                                          : null,
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Decrement button
                                IconButton.filled(
                                  onPressed: () {
                                    final current = int.tryParse(_tableCountController.text) ?? 0;
                                    if (current > 1 && products.isNotEmpty) {
                                      final newCount = current - 1;
                                      _tableCountController.text = newCount.toString();
                                      _applyTableCount(newCount, products);
                                      FocusScope.of(context).unfocus();
                                    }
                                  },
                                  icon: const Icon(Icons.remove, size: 20),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.error.withOpacity(0.1),
                                    foregroundColor: AppColors.error,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Increment button
                                IconButton.filled(
                                  onPressed: () {
                                    final current = int.tryParse(_tableCountController.text) ?? 0;
                                    if (products.isNotEmpty) {
                                      final newCount = current + 1;
                                      _tableCountController.text = newCount.toString();
                                      _applyTableCount(newCount, products);
                                      FocusScope.of(context).unfocus();
                                    }
                                  },
                                  icon: const Icon(Icons.add, size: 20),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    foregroundColor: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                FilledButton.tonal(
                                  onPressed: () {
                                    final count = int.tryParse(_tableCountController.text);
                                    if (count != null && count > 0 && products.isNotEmpty) {
                                      _applyTableCount(count, products);
                                      FocusScope.of(context).unfocus();
                                    }
                                  },
                                  child: const Text('Áp dụng'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Order items list
                      if (_orderItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có sản phẩm nào',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nhập số bàn hoặc thêm sản phẩm bên dưới',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _orderItems.length,
                          itemBuilder: (context, index) {
                            return _buildOrderItemCard(_orderItems[index], index);
                          },
                        ),

                      // Add product button
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddProductBottomSheet(availableProducts),
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm sản phẩm'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom total section
              if (_orderItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_orderItems.length} sản phẩm',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            const Text(
                              'Tổng cộng:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          formatCurrency(_totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionButton(OrderSession session, String label) {
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
          color: isSelected ? AppColors.primary : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildOrderItemCard(_EditableOrderItem item, int index) {
    final isExcluded = _isTableExcludedUnit(item.product.unit);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name and delete button
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (isExcluded) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Cố định',
                            style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => _removeItem(index),
                  tooltip: 'Xóa sản phẩm',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quantity and price inputs
            Row(
              children: [
                // Quantity
                Expanded(
                  child: TextFormField(
                    controller: item.quantityController,
                    autofocus: false,
                    decoration: InputDecoration(
                      labelText: 'Số lượng',
                      suffixText: item.product.unit,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      // Allow decimals for Kg products, integers only for others
                      if (item.product.unit.toLowerCase() == 'kg')
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))
                      else
                        FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => _updateTotal(),
                  ),
                ),
                const SizedBox(width: 12),

                // Price
                Expanded(
                  child: TextFormField(
                    controller: item.priceController,
                    autofocus: false,
                    decoration: const InputDecoration(
                      labelText: 'Đơn giá',
                      suffixText: '₫',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                    onChanged: (_) => _updateTotal(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Subtotal
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Thành tiền: ${formatCurrency(item.total.round())}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
