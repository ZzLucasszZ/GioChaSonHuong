import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/product.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/product_provider.dart';

/// Dialog to add stock to inventory
class AddStockDialog extends StatefulWidget {
  final Product? product;
  final VoidCallback? onStockAdded;

  const AddStockDialog({
    super.key,
    this.product,
    this.onStockAdded,
  });

  @override
  State<AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<AddStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  
  Product? _selectedProduct;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.product;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addStock() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng chọn sản phẩm'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final notes = _notesController.text.trim();

    final success = await context.read<InventoryProvider>().addStock(
      productId: _selectedProduct!.id,
      quantity: quantity,
      notes: notes.isNotEmpty ? notes : null,
    );

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      widget.onStockAdded?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nhập ${quantity.round()} ${_selectedProduct!.unit} ${_selectedProduct!.name}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.add_box, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nhập kho',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.product != null)
                              Text(
                                widget.product!.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Product selector (if not pre-selected)
                  if (widget.product == null)
                    Consumer<ProductProvider>(
                      builder: (context, provider, _) {
                        return DropdownButtonFormField<Product>(
                          value: _selectedProduct,
                          decoration: const InputDecoration(
                            labelText: 'Sản phẩm',
                            prefixIcon: Icon(Icons.inventory_2),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          isExpanded: true,
                          items: provider.products.map((p) {
                            return DropdownMenuItem<Product>(
                              value: p,
                              child: Text(p.name, style: const TextStyle(fontSize: 16)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedProduct = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) return 'Vui lòng chọn sản phẩm';
                            return null;
                          },
                        );
                      },
                    ),
                  
                  if (widget.product == null) const SizedBox(height: 20),

                  // Current stock info
                  if (_selectedProduct != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.1),
                            AppColors.primary.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Tồn kho hiện tại',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_selectedProduct!.currentStock.round()} ${_selectedProduct!.unit}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Quantity input
                  TextFormField(
                    controller: _quantityController,
                    autofocus: false,
                    decoration: InputDecoration(
                      labelText: 'Số lượng nhập',
                      labelStyle: const TextStyle(fontSize: 16),
                      prefixIcon: const Icon(Icons.add_circle_outline, size: 24),
                      suffixText: _selectedProduct?.unit ?? '',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    ),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng nhập số lượng';
                      final qty = int.tryParse(value);
                      if (qty == null || qty <= 0) return 'Số lượng phải lớn hơn 0';
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Notes input
                  TextFormField(
                    controller: _notesController,
                    autofocus: false,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú (tùy chọn)',
                      labelStyle: TextStyle(fontSize: 16),
                      prefixIcon: Icon(Icons.note_outlined, size: 24),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: const TextStyle(fontSize: 16),
                    maxLines: 3,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Hủy', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _addStock,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle),
                          label: Text(
                            _isLoading ? 'Đang xử lý...' : 'Nhập kho',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
