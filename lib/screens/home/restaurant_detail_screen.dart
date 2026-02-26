import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/vietnamese_utils.dart';
import '../../data/models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../shared/share_preview_dialog.dart';
import 'order_detail_screen.dart';
import 'widgets/add_order_dialog.dart';

/// Restaurant detail screen - Calendar date picker + orders by date
class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  late DateTime _selectedDate;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _dayFormat = DateFormat('EEEE', 'vi_VN');
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    
    // Load products for order creation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    await context.read<OrderProvider>().loadOrdersForDate(
      widget.restaurantId,
      _selectedDate,
    );
  }
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await context.read<OrderProvider>().setSelectedDate(
        picked,
        widget.restaurantId,
      );
    }
  }

  void _goToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadOrders();
  }

  void _goToNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    _loadOrders();
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadOrders();
  }

  Future<void> _editRestaurant() async {
    final nameController = TextEditingController(text: widget.restaurantName);
    
    try {
      final confirmed = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đổi tên khách hàng'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Tên khách hàng',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(context, newName);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      );

      if (confirmed != null && confirmed != widget.restaurantName && mounted) {
        try {
          final restaurantProvider = context.read<RestaurantProvider>();
          final restaurant = restaurantProvider.restaurants
              .firstWhere((r) => r.id == widget.restaurantId);
          
          final updatedRestaurant = restaurant.copyWith(
            name: confirmed,
            updatedAt: DateTime.now(),
          );
          
          final success = await restaurantProvider.updateRestaurant(updatedRestaurant);
          
          if (success && mounted) {
            // Refresh the screen with new name
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => RestaurantDetailScreen(
                  restaurantId: widget.restaurantId,
                  restaurantName: confirmed,
                ),
              ),
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã đổi tên khách hàng'),
                backgroundColor: AppColors.success,
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Không thể đổi tên khách hàng'),
                backgroundColor: AppColors.error,
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
    } finally {
      // Dispose controller after dialog is fully closed
      nameController.dispose();
    }
  }

  Future<void> _deleteRestaurant() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Xóa khách hàng "${widget.restaurantName}"?\n\n'
          'Tất cả đơn hàng, công nợ và lịch sử liên quan sẽ bị xóa vĩnh viễn. '
          'Hành động này không thể hoàn tác.',
          style: const TextStyle(height: 1.5),
        ),
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
        final restaurantProvider = context.read<RestaurantProvider>();
        final success = await restaurantProvider.deleteRestaurant(widget.restaurantId);
        
        if (success && mounted) {
          Navigator.pop(context, true); // Return to previous screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa khách hàng'),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể xóa khách hàng'),
              backgroundColor: AppColors.error,
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

  void _shareOrders(List<Order> orders) {
    if (orders.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('📦 ĐƠN HÀNG - ${widget.restaurantName}');
    buffer.writeln('${DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_selectedDate)}');
    buffer.writeln();

    double totalDay = 0;

    // Group by session
    final morningOrders = orders.where((o) => o.session == OrderSession.morning).toList();
    final afternoonOrders = orders.where((o) => o.session == OrderSession.afternoon).toList();
    final unassignedOrders = orders.where((o) => o.session == null).toList();

    // Morning orders
    if (morningOrders.isNotEmpty) {
      buffer.writeln('🌅 BUỔI SÁNG');
      double totalMorning = 0;
      int orderIndex = 1;
      for (final order in morningOrders) {
        if (morningOrders.length > 1) {
          buffer.writeln('Đơn $orderIndex:');
        }
        if (order.items != null && order.items!.isNotEmpty) {
          for (final item in order.items!) {
            final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1);
            buffer.writeln('• ${item.productName}: $qtyStr x ${CurrencyUtils.formatCurrency(item.unitPrice)} = ${CurrencyUtils.formatCurrency(item.subtotal)}');
          }
        }
        buffer.writeln('Tổng đơn: ${CurrencyUtils.formatCurrency(order.totalAmount)}');
        buffer.writeln();
        totalMorning += order.totalAmount;
        orderIndex++;
      }
      buffer.writeln('TỔNG SÁNG: ${CurrencyUtils.formatCurrency(totalMorning)}');
      buffer.writeln();
      totalDay += totalMorning;
    }

    // Afternoon orders
    if (afternoonOrders.isNotEmpty) {
      buffer.writeln('🌆 BUỔI CHIỀU');
      double totalAfternoon = 0;
      int orderIndex = 1;
      for (final order in afternoonOrders) {
        if (afternoonOrders.length > 1) {
          buffer.writeln('Đơn $orderIndex:');
        }
        if (order.items != null && order.items!.isNotEmpty) {
          for (final item in order.items!) {
            final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1);
            buffer.writeln('• ${item.productName}: $qtyStr x ${CurrencyUtils.formatCurrency(item.unitPrice)} = ${CurrencyUtils.formatCurrency(item.subtotal)}');
          }
        }
        buffer.writeln('Tổng đơn: ${CurrencyUtils.formatCurrency(order.totalAmount)}');
        buffer.writeln();
        totalAfternoon += order.totalAmount;
        orderIndex++;
      }
      buffer.writeln('TỔNG CHIỀU: ${CurrencyUtils.formatCurrency(totalAfternoon)}');
      buffer.writeln();
      totalDay += totalAfternoon;
    }

    // Unassigned orders
    if (unassignedOrders.isNotEmpty) {
      if (morningOrders.isNotEmpty || afternoonOrders.isNotEmpty) {
        buffer.writeln('⏰ CHƯA XÁC ĐỊNH');
      }
      double totalUnassigned = 0;
      int orderIndex = 1;
      for (final order in unassignedOrders) {
        if (unassignedOrders.length > 1) {
          buffer.writeln('Đơn $orderIndex:');
        }
        if (order.items != null && order.items!.isNotEmpty) {
          for (final item in order.items!) {
            final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1);
            buffer.writeln('• ${item.productName}: $qtyStr x ${CurrencyUtils.formatCurrency(item.unitPrice)} = ${CurrencyUtils.formatCurrency(item.subtotal)}');
          }
        }
        buffer.writeln('Tổng đơn: ${CurrencyUtils.formatCurrency(order.totalAmount)}');
        buffer.writeln();
        totalUnassigned += order.totalAmount;
        orderIndex++;
      }
      if (morningOrders.isNotEmpty || afternoonOrders.isNotEmpty) {
        buffer.writeln('TỔNG CHƯA XÁC ĐỊNH: ${CurrencyUtils.formatCurrency(totalUnassigned)}');
        buffer.writeln();
      }
      totalDay += totalUnassigned;
    }

    // Only show daily total if there are orders in multiple sessions
    final sessionCount = (morningOrders.isNotEmpty ? 1 : 0) + 
                        (afternoonOrders.isNotEmpty ? 1 : 0) + 
                        (unassignedOrders.isNotEmpty ? 1 : 0);
    
    if (sessionCount > 1) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━');
      buffer.writeln('TỔNG TIỀN CẢ NGÀY: ${CurrencyUtils.formatCurrency(totalDay)}');
    }

    SharePreviewDialog.show(context, message: buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurantName),
        actions: [
          Consumer<OrderProvider>(
            builder: (context, provider, _) {
              if (provider.orders.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Chia sẻ',
                  onPressed: () => _shareOrders(provider.orders),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Hôm nay',
            onPressed: _goToToday,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                _editRestaurant();
              } else if (value == 'delete') {
                _deleteRestaurant();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Đổi tên'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Xóa khách hàng', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Date picker header
          _buildDatePicker(),
          
          const Divider(height: 1),
          
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm đơn hàng...',
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
          
          // Orders list
          Expanded(
            child: _buildOrdersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrderDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm đơn'),
      ),
    );
  }

  Widget _buildDatePicker() {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _goToPreviousDay,
            tooltip: 'Ngày trước',
          ),
          Expanded(
            child: InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: isToday 
                      ? Theme.of(context).colorScheme.primaryContainer 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _dateFormat.format(_selectedDate),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isToday 
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                    Text(
                      isToday ? 'Hôm nay' : _getDayName(_selectedDate),
                      style: TextStyle(
                        fontSize: 13,
                        color: isToday 
                            ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _goToNextDay,
            tooltip: 'Ngày sau',
          ),
        ],
      ),
    );
  }

  String _getDayName(DateTime date) {
    try {
      return _dayFormat.format(date);
    } catch (_) {
      // Fallback if locale not available
      const days = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
      return days[date.weekday - 1];
    }
  }

  Widget _buildOrdersList() {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(provider.error!, style: TextStyle(color: Colors.red[700])),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _loadOrders,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        var orders = provider.orders;
        
        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          final normalizedQuery = normalizeForSearch(_searchQuery);
          orders = orders.where((order) {
            // Search in notes
            final notesMatch = order.notes != null && normalizeForSearch(order.notes!).contains(normalizedQuery);
            // Search in product names (if items are loaded)
            final productMatch = order.items?.any(
              (item) => normalizeForSearch(item.productName).contains(normalizedQuery)
            ) ?? false;
            return notesMatch || productMatch;
          }).toList();
        }

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _searchQuery.isNotEmpty ? Icons.search_off : Icons.receipt_long_outlined, 
                  size: 64, 
                  color: Colors.grey[400]
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty 
                      ? 'Không tìm thấy đơn hàng nào'
                      : 'Chưa có đơn hàng',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                if (_searchQuery.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ngày ${_dateFormat.format(_selectedDate)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          );
        }

        // Chia đơn hàng theo buổi
        final morningOrders = orders
            .where((o) => o.session == OrderSession.morning || o.session == null)
            .toList();
        final afternoonOrders = orders
            .where((o) => o.session == OrderSession.afternoon)
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Buổi sáng
              if (morningOrders.isNotEmpty) ...[
                _buildSessionHeader('🌅 Buổi sáng', morningOrders.length, AppColors.sessionMorning),
                ...morningOrders.map((order) => _buildOrderCard(order)),
                const SizedBox(height: 16),
              ],
              
              // Buổi chiều
              if (afternoonOrders.isNotEmpty) ...[
                _buildSessionHeader('🌆 Buổi chiều', afternoonOrders.length, AppColors.sessionAfternoon),
                ...afternoonOrders.map((order) => _buildOrderCard(order)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionHeader(String title, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count đơn',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    // Build product names string
    String productNames = '';
    if (order.items != null && order.items!.isNotEmpty) {
      productNames = order.items!.map((item) {
        final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1);
        return '${item.productName} x$qtyStr';
      }).join(', ');
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showOrderDetail(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _buildStatusChip(order.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      CurrencyUtils.formatCurrency(order.totalAmount),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              // Product names
              if (productNames.isNotEmpty) ...[  
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        productNames,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Payment info
              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    order.paymentStatus.displayName,
                    style: TextStyle(
                      color: _getPaymentStatusColor(order.paymentStatus),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (order.debtAmount > 0) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '(Còn nợ: ${CurrencyUtils.formatCurrency(order.debtAmount)})',
                        style: TextStyle(
                          color: Colors.red[600],
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  order.notes!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color bgColor;
    Color textColor;
    
    switch (status) {
      case OrderStatus.pending:
        bgColor = AppColors.statusPendingBg;
        textColor = AppColors.statusPending;
        break;
      case OrderStatus.confirmed:
        bgColor = AppColors.statusConfirmedBg;
        textColor = AppColors.statusConfirmed;
        break;
      case OrderStatus.delivering:
        bgColor = AppColors.statusDeliveringBg;
        textColor = AppColors.statusDelivering;
        break;
      case OrderStatus.delivered:
        bgColor = AppColors.statusDeliveredBg;
        textColor = AppColors.statusDelivered;
        break;
      case OrderStatus.cancelled:
        bgColor = AppColors.statusCancelledBg;
        textColor = AppColors.statusCancelled;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.unpaid:
        return AppColors.paymentUnpaid;
      case PaymentStatus.partial:
        return AppColors.paymentPartial;
      case PaymentStatus.paid:
        return AppColors.paymentPaid;
    }
  }

  void _showAddOrderDialog() async {
    final result = await showDialog<bool>(
      context: context,
      useSafeArea: false,
      builder: (context) => AddOrderDialog(
        restaurantId: widget.restaurantId,
        restaurantName: widget.restaurantName,
        selectedDate: _selectedDate,
      ),
    );

    // Reload orders if order was created successfully
    if (result == true) {
      await _loadOrders();
    }
  }

  void _showOrderDetail(Order order) {
    Navigator.push<DateTime?>(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(
          orderId: order.id,
          restaurantName: widget.restaurantName,
        ),
      ),
    ).then((newDate) {
      // If date changed, switch to that date
      if (newDate != null) {
        setState(() {
          _selectedDate = newDate;
        });
      }
      // Always reload orders
      _loadOrders();
    });
  }
}
