import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart' as currency;
import '../../data/models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../home/order_detail_screen.dart';
import '../shared/share_preview_dialog.dart';

class DeliveryTab extends StatefulWidget {
  const DeliveryTab({super.key});

  @override
  State<DeliveryTab> createState() => _DeliveryTabState();
}

class _DeliveryTabState extends State<DeliveryTab> {
  DateTime _selectedDate = DateTime.now();
  List<Order> _allOrders = [];
  bool _isLoading = false;
  OrderSession? _sessionFilter; // null = show all, or specific session

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadOrders();
    });
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
      loadOrders();
    }
  }

  void _goToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    loadOrders();
  }

  void _goToNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    loadOrders();
  }

  Future<void> loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orderProvider = context.read<OrderProvider>();
      final restaurantProvider = context.read<RestaurantProvider>();
      
      // Ensure restaurants are loaded
      if (restaurantProvider.restaurants.isEmpty) {
        await restaurantProvider.loadRestaurants();
      }

      // Load orders for all restaurants for selected date
      final allOrders = <Order>[];
      for (final restaurant in restaurantProvider.restaurants) {
        await orderProvider.loadOrdersForDate(restaurant.id, _selectedDate);
        // Copy orders with restaurant info
        for (final order in orderProvider.orders) {
          allOrders.add(order.copyWith(restaurantName: restaurant.name));
        }
      }

      setState(() {
        _allOrders = allOrders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate orders by session
    final morningOrders = _allOrders.where((o) => o.session == OrderSession.morning).toList();
    final afternoonOrders = _allOrders.where((o) => o.session == OrderSession.afternoon).toList();
    final unassignedOrders = _allOrders.where((o) => o.session == null).toList();

    // Apply session filter
    List<Order> filteredOrders;
    if (_sessionFilter == null) {
      filteredOrders = _allOrders;
    } else if (_sessionFilter == OrderSession.morning) {
      filteredOrders = morningOrders;
    } else if (_sessionFilter == OrderSession.afternoon) {
      filteredOrders = afternoonOrders;
    } else {
      filteredOrders = unassignedOrders;
    }

    final filteredMorning = _sessionFilter == null || _sessionFilter == OrderSession.morning ? morningOrders : <Order>[];
    final filteredAfternoon = _sessionFilter == null || _sessionFilter == OrderSession.afternoon ? afternoonOrders : <Order>[];
    final filteredUnassigned = _sessionFilter == null || _sessionFilter == null ? unassignedOrders : <Order>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao hàng'),
        actions: [
          if (_allOrders.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareAll(),
              tooltip: 'Chia sẻ tất cả',
            ),
          if (filteredOrders.any((o) => o.status != OrderStatus.delivered))
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: () => _markAllDelivered(filteredOrders),
              tooltip: 'Giao tất cả',
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: Row(
              children: [
                // Previous day button
                IconButton(
                  onPressed: _goToPreviousDay,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Ngày trước',
                ),
                
                // Date display
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_selectedDate),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Next day button
                IconButton(
                  onPressed: _goToNextDay,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Ngày sau',
                ),
              ],
            ),
          ),

          // Summary cards (tappable to filter)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    '🌅 Sáng',
                    morningOrders.length,
                    morningOrders.where((o) => o.status != OrderStatus.delivered).length,
                    Colors.orange,
                    OrderSession.morning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    '🌆 Chiều',
                    afternoonOrders.length,
                    afternoonOrders.where((o) => o.status != OrderStatus.delivered).length,
                    Colors.indigo,
                    OrderSession.afternoon,
                  ),
                ),
              ],
            ),
          ),

          // Orders list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              'Không có đơn hàng cần giao',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Morning section
                          if (filteredMorning.isNotEmpty) ...[
                            _buildSectionHeader('🌅 Sáng', filteredMorning.length, filteredMorning),
                            ..._buildGroupedOrders(filteredMorning),
                            const SizedBox(height: 16),
                          ],
                          
                          // Afternoon section
                          if (filteredAfternoon.isNotEmpty) ...[
                            _buildSectionHeader('🌆 Chiều', filteredAfternoon.length, filteredAfternoon),
                            ..._buildGroupedOrders(filteredAfternoon),
                            const SizedBox(height: 16),
                          ],

                          // Unassigned
                          if (_sessionFilter == null && filteredUnassigned.isNotEmpty) ...[
                            _buildSectionHeader('⏰ Chưa xác định', filteredUnassigned.length, filteredUnassigned),
                            ..._buildGroupedOrders(filteredUnassigned),
                          ],

                          const SizedBox(height: 80),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, int total, int pending, Color color, OrderSession session) {
    final isActive = _sessionFilter == session;
    return InkWell(
      onTap: () {
        setState(() {
          _sessionFilter = _sessionFilter == session ? null : session;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : color.withOpacity(0.3),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$total',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        'đơn hàng',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pending > 0)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pending chờ',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, List<Order> orders) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count đơn',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.share, size: 20),
            onPressed: () => _shareSession(title, orders),
            tooltip: 'Chia sẻ $title',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedOrders(List<Order> orders) {
    // Group orders by restaurant
    final ordersByRestaurant = <String, List<Order>>{};
    for (final order in orders) {
      final restaurantName = order.restaurantName ?? 'Nhà hàng';
      if (!ordersByRestaurant.containsKey(restaurantName)) {
        ordersByRestaurant[restaurantName] = [];
      }
      ordersByRestaurant[restaurantName]!.add(order);
    }

    // Sort restaurants alphabetically
    final sortedRestaurants = ordersByRestaurant.keys.toList()..sort();

    return sortedRestaurants.map((restaurantName) {
      final restaurantOrders = ordersByRestaurant[restaurantName]!;
      final pendingCount = restaurantOrders.where((o) => o.status != OrderStatus.delivered).length;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Restaurant header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(Icons.restaurant, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurantName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${restaurantOrders.length} đơn${pendingCount > 0 ? ' • $pendingCount chờ giao' : ''}',
                          style: TextStyle(
                            color: pendingCount > 0 ? AppColors.warning : AppColors.success,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pendingCount > 0)
                    IconButton(
                      icon: const Icon(Icons.local_shipping, size: 20),
                      onPressed: () => _markRestaurantDelivered(restaurantName, restaurantOrders),
                      tooltip: 'Giao hàng $restaurantName',
                      color: AppColors.success,
                    ),
                  IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    onPressed: () => _shareRestaurant(restaurantName, restaurantOrders),
                    tooltip: 'Chia sẻ $restaurantName',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              
              // List all orders with products
              ...restaurantOrders.asMap().entries.map((entry) {
                final index = entry.key;
                final order = entry.value;
                final isDelivered = order.status == OrderStatus.delivered;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push<DateTime?>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(
                            orderId: order.id,
                            restaurantName: order.restaurantName ?? 'Nhà hàng',
                          ),
                        ),
                      ).then((newDate) {
                        // If date changed during edit, switch to that date
                        if (newDate != null && mounted) {
                          setState(() {
                            _selectedDate = newDate;
                          });
                        }
                        loadOrders();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDelivered 
                            ? AppColors.success.withOpacity(0.05)
                            : AppColors.warning.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDelivered 
                              ? AppColors.success.withOpacity(0.2)
                              : AppColors.warning.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (restaurantOrders.length > 1)
                            Row(
                              children: [
                                Icon(
                                  isDelivered ? Icons.check_circle : Icons.pending,
                                  color: isDelivered ? AppColors.success : AppColors.warning,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Đơn ${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (order.status != OrderStatus.cancelled)
                                  InkWell(
                                    onTap: () {
                                      Navigator.push<DateTime?>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => OrderDetailScreen(
                                            orderId: order.id,
                                            restaurantName: order.restaurantName ?? 'Nhà hàng',
                                          ),
                                        ),
                                      ).then((newDate) {
                                        if (newDate != null && mounted) {
                                          setState(() {
                                            _selectedDate = newDate;
                                          });
                                        }
                                        loadOrders();
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          if (restaurantOrders.length == 1 && order.status != OrderStatus.cancelled)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () {
                                    Navigator.push<DateTime?>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => OrderDetailScreen(
                                          orderId: order.id,
                                          restaurantName: order.restaurantName ?? 'Nhà hàng',
                                        ),
                                      ),
                                    ).then((newDate) {
                                      if (newDate != null && mounted) {
                                        setState(() {
                                          _selectedDate = newDate;
                                        });
                                      }
                                      loadOrders();
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (order.items != null && order.items!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...order.items!.map((item) => Padding(
                              padding: const EdgeInsets.only(left: 26, top: 4),
                              child: Row(
                                children: [
                                  Text(
                                    '•',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      () {
                                        final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1);
                                        return '${item.productName} x$qtyStr';
                                      }(),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }).toList();
  }

  // Delivery methods
  Future<void> _markAllDelivered(List<Order> orders) async {
    final pendingOrders = orders.where((o) => o.status != OrderStatus.delivered).toList();
    if (pendingOrders.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tất cả đơn đã được giao')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận giao hàng'),
        content: Text('Đánh dấu ${pendingOrders.length} đơn hàng là đã giao?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final orderProvider = context.read<OrderProvider>();
    int successCount = 0;
    for (final order in pendingOrders) {
      final success = await orderProvider.updateOrderStatus(order.id, OrderStatus.delivered);
      if (success) successCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã giao $successCount/${pendingOrders.length} đơn hàng'),
          backgroundColor: AppColors.success,
        ),
      );
      loadOrders();
    }
  }

  Future<void> _markRestaurantDelivered(String restaurantName, List<Order> orders) async {
    final pendingOrders = orders.where((o) => o.status != OrderStatus.delivered).toList();
    if (pendingOrders.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tất cả đơn đã được giao')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận giao hàng'),
        content: Text('Đánh dấu ${pendingOrders.length} đơn của $restaurantName là đã giao?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final orderProvider = context.read<OrderProvider>();
    int successCount = 0;
    for (final order in pendingOrders) {
      final success = await orderProvider.updateOrderStatus(order.id, OrderStatus.delivered);
      if (success) successCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã giao $successCount đơn - $restaurantName'),
          backgroundColor: AppColors.success,
        ),
      );
      loadOrders();
    }
  }

  // Share methods
  String _formatOrdersMessage(String title, List<Order> orders) {
    final buffer = StringBuffer();
    buffer.writeln('📦 $title');
    buffer.writeln('${DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_selectedDate)}');
    buffer.writeln();

    // Group by restaurant
    final ordersByRestaurant = <String, List<Order>>{};
    for (final order in orders) {
      final restaurantName = order.restaurantName ?? 'Nhà hàng';
      ordersByRestaurant.putIfAbsent(restaurantName, () => []).add(order);
    }

    final sortedRestaurants = ordersByRestaurant.keys.toList()..sort();

    for (final restaurantName in sortedRestaurants) {
      final restaurantOrders = ordersByRestaurant[restaurantName]!;
      buffer.writeln('🏪 $restaurantName');

      int orderIndex = 1;
      for (final order in restaurantOrders) {
        // Only show order number if restaurant has more than 1 order
        if (restaurantOrders.length > 1) {
          buffer.writeln('Đơn $orderIndex:');
        }
        
        if (order.items != null && order.items!.isNotEmpty) {
          for (final item in order.items!) {
            final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1);
            buffer.writeln('• ${item.productName} x$qtyStr');
          }
        }
        buffer.writeln();
        orderIndex++;
      }
    }

    return buffer.toString();
  }

  void _shareAll() {
    if (_allOrders.isEmpty) return;
    final message = _formatOrdersMessage('GIAO HÀNG TRONG NGÀY', _allOrders);
    SharePreviewDialog.show(context, message: message);
  }

  void _shareSession(String title, List<Order> orders) {
    if (orders.isEmpty) return;
    final message = _formatOrdersMessage('GIAO HÀNG $title'.toUpperCase(), orders);
    SharePreviewDialog.show(context, message: message);
  }

  void _shareRestaurant(String restaurantName, List<Order> orders) {
    if (orders.isEmpty) return;
    
    final buffer = StringBuffer();
    buffer.writeln('📦 GIAO HÀNG - $restaurantName');
    buffer.writeln('${DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_selectedDate)}');
    buffer.writeln();

    int orderIndex = 1;
    for (final order in orders) {
      // Only show order number if restaurant has more than 1 order
      if (orders.length > 1) {
        buffer.writeln('Đơn $orderIndex:');
      }
      
      if (order.items != null && order.items!.isNotEmpty) {
        for (final item in order.items!) {
          final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1);
          buffer.writeln('• ${item.productName} x$qtyStr');
        }
      }
      buffer.writeln();
      orderIndex++;
    }

    SharePreviewDialog.show(context, message: buffer.toString());
  }
}
