import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart' as currency;
import '../../core/utils/vietnamese_utils.dart';
import '../../data/models/order.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/order_provider.dart';
import '../home/order_detail_screen.dart';
import 'widgets/create_order_dialog.dart';

// Helper để lấy màu PaymentStatus
Color _getPaymentColor(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.unpaid:
      return AppColors.paymentUnpaid;
    case PaymentStatus.partial:
      return AppColors.paymentPartial;
    case PaymentStatus.paid:
      return AppColors.paymentPaid;
  }
}

// Helper để lấy màu OrderStatus
Color _getStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return AppColors.statusPending;
    case OrderStatus.confirmed:
      return AppColors.statusConfirmed;
    case OrderStatus.delivering:
      return AppColors.statusDelivering;
    case OrderStatus.delivered:
      return AppColors.statusDelivered;
    case OrderStatus.cancelled:
      return AppColors.statusCancelled;
  }
}

class OrderTab extends StatefulWidget {
  const OrderTab({super.key});

  @override
  State<OrderTab> createState() => _OrderTabState();
}

class _OrderTabState extends State<OrderTab> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedRestaurantId;
  bool _isLoadingRestaurants = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadRestaurants();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadRestaurants() async {
    if (_isLoadingRestaurants) return;
    setState(() {
      _isLoadingRestaurants = true;
    });
    await context.read<RestaurantProvider>().loadRestaurants();
    if (mounted) {
      setState(() {
        _isLoadingRestaurants = false;
      });
    }
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
      _loadOrders();
    }
  }

  void _loadOrders() {
    if (_selectedRestaurantId != null) {
      context.read<OrderProvider>().loadOrdersForDate(
            _selectedRestaurantId!,
            _selectedDate,
          );
    }
  }

  void _showCreateOrderDialog() {
    if (_selectedRestaurantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn nhà hàng trước'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CreateOrderDialog(
        restaurantId: _selectedRestaurantId!,
        selectedDate: _selectedDate,
        onOrderCreated: () {
          _loadOrders();
        },
      ),
    );
  }

  void _showAddRestaurantDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.restaurant, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('Thêm nhà hàng'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: false,
                  decoration: const InputDecoration(
                    labelText: 'Tên nhà hàng *',
                    prefixIcon: Icon(Icons.store),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên nhà hàng';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  autofocus: false,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: addressController,
                  autofocus: false,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final provider = this.context.read<RestaurantProvider>();
                final restaurant = await provider.createRestaurant(
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim().isNotEmpty 
                      ? phoneController.text.trim() 
                      : null,
                  address: addressController.text.trim().isNotEmpty 
                      ? addressController.text.trim() 
                      : null,
                );
                
                if (context.mounted) {
                  if (restaurant != null) {
                    Navigator.of(context).pop();
                    setState(() {
                      _selectedRestaurantId = restaurant.id;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã thêm nhà hàng "${restaurant.name}"'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } else if (provider.error != null) {
                    // Show error message if creation failed (e.g., duplicate name)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(provider.error!),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date & Restaurant selector
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                // Date display
                InkWell(
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
                        const Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Restaurant dropdown with add button
                Row(
                  children: [
                    Expanded(
                      child: Consumer<RestaurantProvider>(
                        builder: (context, provider, _) {
                          final restaurants = provider.restaurants;
                          return DropdownButtonFormField<String>(
                            value: _selectedRestaurantId,
                            decoration: const InputDecoration(
                              labelText: 'Chọn nhà hàng',
                              prefixIcon: Icon(Icons.restaurant),
                              border: OutlineInputBorder(),
                            ),
                            items: restaurants.map((r) {
                              return DropdownMenuItem<String>(
                                value: r.id,
                                child: Text(r.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedRestaurantId = value;
                              });
                              _loadOrders();
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add restaurant button
                    IconButton.filled(
                      onPressed: _showAddRestaurantDialog,
                      icon: const Icon(Icons.add),
                      tooltip: 'Thêm nhà hàng',
                    ),
                  ],
                ),
                // Search field
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Tìm kiếm đơn hàng...',
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
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ],
            ),
          ),

          // Orders list
          Expanded(
            child: _selectedRestaurantId == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu, size: 64, color: AppColors.textSecondary),
                        SizedBox(height: 16),
                        Text(
                          'Chọn nhà hàng để xem đơn hàng',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : Consumer<OrderProvider>(
                    builder: (context, provider, _) {
                      if (provider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
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
                                _searchQuery.isNotEmpty ? Icons.search_off : Icons.receipt_long,
                                size: 64,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty 
                                    ? 'Không tìm thấy đơn hàng nào'
                                    : 'Chưa có đơn hàng nào',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _showCreateOrderDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Tạo đơn hàng'),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      // Group by session
                      final morningOrders = orders.where((o) => o.session == OrderSession.morning).toList();
                      final afternoonOrders = orders.where((o) => o.session == OrderSession.afternoon).toList();

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (morningOrders.isNotEmpty) ...[
                            _buildSessionHeader('🌅 Sáng', morningOrders.length),
                            ...morningOrders.map((o) => _buildOrderCard(o)),
                            const SizedBox(height: 16),
                          ],
                          if (afternoonOrders.isNotEmpty) ...[
                            _buildSessionHeader('🌆 Chiều', afternoonOrders.length),
                            ...afternoonOrders.map((o) => _buildOrderCard(o)),
                          ],
                          if (morningOrders.isEmpty && afternoonOrders.isEmpty)
                            ...orders.map((o) => _buildOrderCard(o)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateOrderDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tạo đơn'),
      ),
    );
  }

  Widget _buildSessionHeader(String title, int count) {
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final paymentColor = _getPaymentColor(order.paymentStatus);
    final isDelivered = order.status == OrderStatus.delivered;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
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
            _loadOrders();
          });
        },
        leading: CircleAvatar(
          backgroundColor: paymentColor.withOpacity(0.2),
          child: Icon(
            isDelivered ? Icons.check_circle : Icons.receipt_long,
            color: paymentColor,
          ),
        ),
        title: Text(
          currency.formatCurrency(order.totalAmount.round()),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order.notes != null && order.notes!.isNotEmpty)
              Text(order.notes!),
            Row(
              children: [
                _buildStatusBadge(order.paymentStatus.displayName, paymentColor),
                const SizedBox(width: 8),
                _buildStatusBadge(
                  isDelivered ? 'Đã giao' : 'Chờ giao',
                  isDelivered ? AppColors.success : AppColors.warning,
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
