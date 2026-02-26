import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/thousands_separator_formatter.dart';
import '../../core/utils/vietnamese_utils.dart';
import '../../data/models/models.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../shared/share_preview_dialog.dart';

String formatCurrency(int amount) {
  return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫';
}

String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatPrice(int price) {
  if (price == 0) return '0';
  return price.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );
}

String getStatusText(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return 'Chờ xử lý';
    case OrderStatus.confirmed:
      return 'Đã xác nhận';
    case OrderStatus.delivering:
      return 'Đang giao';
    case OrderStatus.delivered:
      return 'Đã giao';
    case OrderStatus.cancelled:
      return 'Đã hủy';
  }
}

Color getStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return Colors.orange;
    case OrderStatus.confirmed:
      return Colors.blue;
    case OrderStatus.delivering:
      return Colors.purple;
    case OrderStatus.delivered:
      return Colors.green;
    case OrderStatus.cancelled:
      return Colors.red;
  }
}

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final String restaurantName;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.restaurantName,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  List<OrderItem> _orderItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  bool _canEdit() {
    if (_order == null) return false;
    return _order!.status != OrderStatus.cancelled;
  }

  Future<void> _loadOrderDetails() async {
    setState(() => _isLoading = true);
    
    try {
      final orderProvider = context.read<OrderProvider>();
      
      // Load order
      final order = await orderProvider.getOrderById(widget.orderId);
      
      // Load order items
      final items = await orderProvider.getOrderItems(widget.orderId);
      
      setState(() {
        _order = order;
        _orderItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải đơn hàng: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  int _calculateTotal() {
    return _orderItems.fold<int>(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice).round(),
    );
  }

  Future<void> _shareOrderDetails() async {
    if (_order == null) return;

    final buffer = StringBuffer();
    
    buffer.writeln('📦 ĐƠN HÀNG - ${widget.restaurantName}');
    buffer.writeln('${DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_order!.deliveryDate)}');
    buffer.writeln();
    
    // Add session header emoji
    if (_order!.session == OrderSession.morning) {
      buffer.writeln('🌅 BUỔI SÁNG');
    } else if (_order!.session == OrderSession.afternoon) {
      buffer.writeln('🌆 BUỔI CHIỀU');
    }
    
    // Products - one line per product
    for (final item in _orderItems) {
      final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1);
      buffer.writeln('• ${item.productName}: $qtyStr x ${CurrencyUtils.formatCurrency(item.unitPrice)} = ${CurrencyUtils.formatCurrency(item.subtotal)}');
    }
    
    buffer.writeln('Tổng đơn: ${CurrencyUtils.formatCurrency(_order!.totalAmount)}');
    
    await SharePreviewDialog.show(
      context,
      message: buffer.toString(),
      subject: 'Đơn hàng ${widget.restaurantName} - ${formatDate(_order!.deliveryDate)}',
    );
  }

  Future<void> _showPaymentDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thanh toán'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tổng tiền: ${formatCurrency(_order!.totalAmount.round())}'),
            Text('Đã thanh toán: ${formatCurrency(_order!.paidAmount.round())}'),
            Text(
              'Còn nợ: ${formatCurrency(_order!.debtAmount.round())}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'partial'),
            child: const Text('Thanh toán một phần'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'full'),
            child: const Text('Thanh toán đủ'),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'full') {
      await _processPayment(_order!.debtAmount);
    } else if (choice == 'partial') {
      await _showPartialPaymentDialog();
    }
  }

  Future<void> _showPartialPaymentDialog() async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập số tiền thanh toán'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          decoration: InputDecoration(
            labelText: 'Số tiền',
            suffixText: '₫',
            hintText: formatCurrency(_order!.debtAmount.round()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(RegExp(r'[^\d]'), ''));
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (amount != null && mounted) {
      await _processPayment(amount);
    }
  }

  Future<void> _processPayment(double amount) async {
    try {
      final orderProvider = context.read<OrderProvider>();
      final success = await orderProvider.updatePayment(context, widget.orderId, amount);
      
      if (success) {
        await _loadOrderDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã cập nhật thanh toán: ${formatCurrency(amount.round())}'),
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

  Future<void> _markAsDelivered() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Đánh dấu đơn hàng này đã giao?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final orderProvider = context.read<OrderProvider>();
        await orderProvider.updateOrderStatus(
          widget.orderId,
          OrderStatus.delivered,
        );
        await _loadOrderDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã cập nhật trạng thái đơn hàng'),
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

  Future<void> _editOrderItem(OrderItem item) async {
    final quantityController = TextEditingController(text: item.quantity.toInt().toString());
    final priceController = TextEditingController(text: _formatPrice(item.unitPrice.toInt()));

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chỉnh sửa ${item.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              autofocus: false,
              decoration: const InputDecoration(
                labelText: 'Số lượng',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              autofocus: false,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Đơn giá',
                suffixText: '₫',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(quantityController.text);
              final price = double.tryParse(priceController.text.replaceAll(RegExp(r'[^\d]'), ''));
              if (qty != null && price != null && qty > 0 && price > 0) {
                Navigator.pop(context, {'quantity': qty, 'price': price});
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        // Update item in list
        final updatedItems = _orderItems.map((i) {
          if (i.id == item.id) {
            return i.copyWith(
              quantity: result['quantity']!,
              unitPrice: result['price']!,
            );
          }
          return i;
        }).toList();

        // Update in database
        final orderProvider = context.read<OrderProvider>();
        await orderProvider.updateOrderItems(widget.orderId, updatedItems);
        
        await _loadOrderDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã cập nhật sản phẩm'),
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

  Future<void> _deleteOrderItem(OrderItem item) async {
    if (_orderItems.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa sản phẩm cuối cùng. Hãy xóa đơn hàng thay vì.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa ${item.productName} khỏi đơn hàng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final updatedItems = _orderItems.where((i) => i.id != item.id).toList();
        final orderProvider = context.read<OrderProvider>();
        await orderProvider.updateOrderItems(widget.orderId, updatedItems);
        
        await _loadOrderDetails();
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

  Future<void> _showFullEditDialog() async {
    if (_order == null) return;

    final newDate = await Navigator.of(context).push<DateTime?>(
      MaterialPageRoute(
        builder: (context) => _OrderEditScreen(
          order: _order!,
          orderItems: _orderItems,
          onSaved: () {
            _loadOrderDetails();
          },
        ),
      ),
    );
    
    // If date changed, pop this detail screen and pass new date back
    if (newDate != null && mounted) {
      Navigator.pop(context, newDate);
    }
  }

  Future<void> _deleteOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Xóa toàn bộ đơn hàng này? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final orderProvider = context.read<OrderProvider>();
        await orderProvider.deleteOrder(widget.orderId, _order!.restaurantId);
        
        if (mounted) {
          Navigator.pop(context); // Return to previous screen (no value — caller expects DateTime?)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa đơn hàng'),
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

  Widget _buildBottomButtons() {
    final showPaymentButton = _order!.paymentStatus != PaymentStatus.paid;
    final showDeliveryButton = _order!.status != OrderStatus.cancelled;
    
    if (!showPaymentButton && !showDeliveryButton) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Payment button
            if (showPaymentButton)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showPaymentDialog,
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(
                    _order!.paidAmount > 0 ? 'Thanh toán thêm' : 'Thanh toán',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            
            if (showPaymentButton && showDeliveryButton)
              const SizedBox(width: 12),
            
            // Delivery button
            if (showDeliveryButton)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _markAsDelivered,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Đã giao hàng'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.success,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurantName),
        actions: [
          if (_order != null) ...[
            if (_canEdit())
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Chỉnh sửa',
                onPressed: _showFullEditDialog,
              ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Chia sẻ',
              onPressed: _shareOrderDetails,
            ),
            if (_canEdit())
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteOrder();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                        SizedBox(width: 8),
                        Text('Xóa đơn hàng', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
      bottomNavigationBar: _order == null ? null : _buildBottomButtons(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('Không tìm thấy đơn hàng'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order header
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Thông tin đơn hàng',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(_order!.status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: getStatusColor(_order!.status),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      getStatusText(_order!.status),
                                      style: TextStyle(
                                        color: getStatusColor(_order!.status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow('Ngày đặt:', formatDate(_order!.orderDate)),
                              const SizedBox(height: 8),
                              _buildInfoRow('Ngày giao:', formatDate(_order!.deliveryDate)),
                              if (_order!.notes != null && _order!.notes!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildInfoRow('Ghi chú:', _order!.notes!),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Order items
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Chi tiết sản phẩm',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Order items list as cards
                              ..._orderItems.map((item) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Product name and actions
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.productName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (_canEdit()) ...[
                                          InkWell(
                                            onTap: () => _editOrderItem(item),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              child: const Icon(
                                                Icons.edit_outlined,
                                                size: 20,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () => _deleteOrderItem(item),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              child: const Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    
                                    // Details row
                                    Row(
                                      children: [
                                        // Quantity
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Số lượng',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.quantity % 1 == 0 ? '${item.quantity.toInt()}' : item.quantity.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Unit price
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Đơn giá',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  formatCurrency(item.unitPrice.round()),
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Total
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Thành tiền',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                  formatCurrency((item.quantity * item.unitPrice).round()),
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )),
                              
                              const Divider(height: 24),
                              
                              // Total
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Tổng cộng:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      formatCurrency(_calculateTotal()),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// Full Order Edit Screen
class _OrderEditScreen extends StatefulWidget {
  final Order order;
  final List<OrderItem> orderItems;
  final VoidCallback onSaved;

  const _OrderEditScreen({
    required this.order,
    required this.orderItems,
    required this.onSaved,
  });

  @override
  State<_OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends State<_OrderEditScreen> {
  late DateTime _deliveryDate;
  late OrderSession _session;
  late TextEditingController _tableCountController;
  late List<OrderItem> _items;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _deliveryDate = widget.order.deliveryDate;
    _session = widget.order.session ?? OrderSession.morning;
    
    // Parse table count from notes (format: "5 bàn")
    String tableCountText = '';
    if (widget.order.notes != null && widget.order.notes!.contains('bàn')) {
      final match = RegExp(r'(\d+)\s*bàn').firstMatch(widget.order.notes!);
      if (match != null) {
        tableCountText = match.group(1) ?? '';
      }
    }
    _tableCountController = TextEditingController(text: tableCountText);
    _items = List.from(widget.orderItems);
  }

  @override
  void dispose() {
    _tableCountController.dispose();
    super.dispose();
  }

  int _calculateTotal() {
    return _items.fold<int>(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice).round(),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      final orderProvider = context.read<OrderProvider>();
      
      // Check if delivery date changed
      final dateChanged = _deliveryDate.year != widget.order.deliveryDate.year ||
                          _deliveryDate.month != widget.order.deliveryDate.month ||
                          _deliveryDate.day != widget.order.deliveryDate.day;
      
      // Prepare notes from table count
      final notes = _tableCountController.text.isNotEmpty
          ? '${_tableCountController.text} bàn'
          : null;
      
      // Use OrderProvider method to ensure proper state management
      await orderProvider.updateOrderWithItems(
        orderId: widget.order.id,
        deliveryDate: _deliveryDate,
        session: _session,
        items: _items,
        notes: notes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dateChanged 
                ? 'Đã cập nhật đơn hàng (ngày giao đã thay đổi sang ${formatDate(_deliveryDate)})' 
                : 'Đã cập nhật đơn hàng'
            ),
            backgroundColor: AppColors.success,
            duration: dateChanged ? const Duration(seconds: 4) : const Duration(seconds: 2),
          ),
        );
        
        // Call the saved callback
        widget.onSaved();
        
        // Pop edit screen and return new date if changed
        Navigator.pop(context, dateChanged ? _deliveryDate : null);
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _deliveryDate = picked);
    }
  }

  void _applyTableCount() {
    // Close keyboard
    FocusScope.of(context).unfocus();
    
    final tableCount = int.tryParse(_tableCountController.text);
    if (tableCount == null || tableCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số bàn hợp lệ'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final productProvider = context.read<ProductProvider>();
    final products = productProvider.products;

    // Find default products
    final chaLa = products.cast<Product?>().firstWhere((p) => p?.name == 'Chả lá', orElse: () => null);
    final nemHop = products.cast<Product?>().firstWhere((p) => p?.name == 'Nem Hộp', orElse: () => null);

    setState(() {
      _items.clear();

      // Add default products with calculated quantities
      if (chaLa != null) {
        _items.add(OrderItem.create(
          orderId: widget.order.id,
          productId: chaLa.id,
          productName: chaLa.name,
          quantity: (tableCount * 10).toDouble(),
          unit: chaLa.unit,
          unitPrice: chaLa.basePrice,
        ));
      }

      if (nemHop != null) {
        _items.add(OrderItem.create(
          orderId: widget.order.id,
          productId: nemHop.id,
          productName: nemHop.name,
          quantity: (tableCount * 10).toDouble(),
          unit: nemHop.unit,
          unitPrice: nemHop.basePrice,
        ));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã tự động tính cho $tableCount bàn'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _addProduct() async {
    final productProvider = context.read<ProductProvider>();
    final products = productProvider.products;
    
    final availableProducts = products.where((p) {
      return !_items.any((item) => item.productId == p.id);
    }).toList();

    if (availableProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm hết sản phẩm')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProductSearchBottomSheet(
        availableProducts: availableProducts,
      ),
    );

    if (selected != null) {
      // Calculate default quantity based on table count
      final tableCount = int.tryParse(_tableCountController.text) ?? 1;
      final defaultQty = _calculateDefaultQuantity(selected, tableCount);
      
      setState(() {
        _items.add(OrderItem.create(
          orderId: widget.order.id,
          productId: selected.id,
          productName: selected.name,
          quantity: defaultQty,
          unit: selected.unit,
          unitPrice: selected.basePrice,
        ));
      });
      
      // Ensure no auto-focus after adding product
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).unfocus();
        }
      });
    }
  }

  // Calculate default quantity based on product name and table count
  double _calculateDefaultQuantity(Product product, int tableCount) {
    // Skip auto-calculate for kg products - let user input manually
    if (product.unit.toLowerCase() == 'kg') {
      return 1.0;
    }
    
    // Quy tắc đặc biệt cho từng món
    switch (product.name) {
      case 'Chả lá':
      case 'Nem':
      case 'Bánh bao':
        return (tableCount * 10).toDouble();
      case 'Rế':
        return ((tableCount / 2).ceil()).toDouble();
      default:
        // Mặc định: 10 cái/bàn cho tất cả sản phẩm khác
        return (tableCount * 10).toDouble();
    }
  }

  Future<void> _editItem(int index) async {
    final item = _items[index];
    final qtyController = TextEditingController(text: item.quantity.toInt().toString());
    final priceController = TextEditingController(text: _formatPrice(item.unitPrice.toInt()));

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chỉnh sửa ${item.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              autofocus: false,
              decoration: InputDecoration(
                labelText: 'Số lượng (${item.unit})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              autofocus: false,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Đơn giá',
                suffixText: '₫',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text) ?? item.quantity;
              final price = double.tryParse(priceController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? item.unitPrice;
              Navigator.pop(context, {'quantity': qty, 'price': price});
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _items[index] = _items[index].copyWith(
          quantity: result['quantity'],
          unitPrice: result['price'],
          subtotal: result['quantity']! * result['price']!,
        );
      });
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa đơn hàng'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton.tonal(
                onPressed: _items.isEmpty ? null : _saveChanges,
                child: const Text('Lưu'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Order Info Section - Compact
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Date and Session in one row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey[700]),
                              const SizedBox(width: 6),
                              Text(
                                formatDate(_deliveryDate),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey[700]),
                          const SizedBox(width: 6),
                          Text(
                            _session == OrderSession.morning ? 'Sáng' : 'Chiều',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: _session == OrderSession.afternoon,
                              onChanged: (value) {
                                setState(() {
                                  _session = value ? OrderSession.afternoon : OrderSession.morning;
                                });
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Table count field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tableCountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Số bàn',
                          hintText: 'Nhập số bàn',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _applyTableCount,
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Tự động', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Products Section - Compact
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sản phẩm',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                FilledButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Thêm', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
          ),

          // Products List
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có sản phẩm nào\nNhấn "Thêm" để thêm sản phẩm',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final total = (item.quantity * item.unitPrice).round();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          title: Text(
                            item.productName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1)} ${item.unit} × ${formatCurrency(item.unitPrice.round())}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    formatCurrency(total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _editItem(index),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  color: AppColors.error,
                                  onPressed: () => _removeItem(index),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Total Section - Compact
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              border: const Border(
                top: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng cộng:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    formatCurrency(_calculateTotal()),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Product Search Bottom Sheet Widget
class _ProductSearchBottomSheet extends StatefulWidget {
  final List<Product> availableProducts;

  const _ProductSearchBottomSheet({
    required this.availableProducts,
  });

  @override
  State<_ProductSearchBottomSheet> createState() => _ProductSearchBottomSheetState();
}

class _ProductSearchBottomSheetState extends State<_ProductSearchBottomSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return widget.availableProducts;
    }
    
    final normalizedQuery = normalizeForSearch(_searchQuery);
    return widget.availableProducts.where((product) {
      final normalizedName = normalizeForSearch(product.name);
      return normalizedName.contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header with search
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    autofocus: false,
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            // Products list
            Expanded(
              child: _filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không tìm thấy sản phẩm',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return ListTile(
                          title: Text(product.name),
                          subtitle: Text(formatCurrency(product.basePrice.toInt())),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => Navigator.pop(context, product),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
