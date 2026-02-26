import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/vietnamese_utils.dart';
import '../../data/models/models.dart';
import '../../providers/order_provider.dart';
import '../home/order_detail_screen.dart';
import '../shared/share_preview_dialog.dart';

String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key});

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  Map<String, List<Order>> _unpaidOrdersByRestaurant = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUnpaidOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUnpaidOrders() async {
    setState(() => _isLoading = true);
    
    try {
      final orderProvider = context.read<OrderProvider>();
      final orders = await orderProvider.loadUnpaidOrders();
      
      // Group by restaurant
      final grouped = <String, List<Order>>{};
      for (final order in orders) {
        final restaurantKey = '${order.restaurantId}___${order.restaurantName ?? 'Unknown'}';
        if (!grouped.containsKey(restaurantKey)) {
          grouped[restaurantKey] = [];
        }
        grouped[restaurantKey]!.add(order);
      }
      
      setState(() {
        _unpaidOrdersByRestaurant = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải dữ liệu: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  int _calculateRestaurantDebt(List<Order> orders) {
    return orders.fold<int>(0, (sum, order) => sum + order.debtAmount.round());
  }

  int _calculateTotalItems(Order order) {
    if (order.items == null || order.items!.isEmpty) return 0;
    return order.items!.fold<int>(0, (sum, item) {
      if (item.quantity < 0) return sum; // Skip invalid items
      return sum + item.quantity.round();
    });
  }

  Future<void> _shareRestaurantDebt(String restaurantName, List<Order> orders) async {
    final restaurantDebt = _calculateRestaurantDebt(orders);
    
    final buffer = StringBuffer();
    buffer.writeln('💳 CÔNG NỢ NHÀ HÀNG');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();
    buffer.writeln('🏪 Nhà hàng: $restaurantName');
    buffer.writeln('📊 Số đơn hàng: ${orders.length}');
    buffer.writeln('❌ Tổng nợ: ${CurrencyUtils.formatCurrency(restaurantDebt.toDouble())}');
    buffer.writeln();
    buffer.writeln('📋 CHI TIẾT:');
    buffer.writeln('─────────────────────');
    
    for (int i = 0; i < orders.length; i++) {
      final order = orders[i];
      final itemCount = _calculateTotalItems(order);
      
      buffer.writeln();
      buffer.writeln('${i + 1}. 📅 ${formatDate(order.deliveryDate)}');
      if (order.notes != null && order.notes!.isNotEmpty) {
        buffer.writeln('   📝 ${order.notes}');
      }
      buffer.writeln('   📦 Sản phẩm: $itemCount SP');
      buffer.writeln('   💰 Tổng: ${CurrencyUtils.formatCurrency(order.totalAmount)}');
      buffer.writeln('   ✅ Đã TT: ${CurrencyUtils.formatCurrency(order.paidAmount)}');
      buffer.writeln('   ❌ Còn nợ: ${CurrencyUtils.formatCurrency(order.debtAmount)}');
    }
    
    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 TỔNG NỢ: ${CurrencyUtils.formatCurrency(restaurantDebt.toDouble())}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    
    await SharePreviewDialog.show(
      context,
      message: buffer.toString(),
      subject: 'Công nợ - $restaurantName',
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDebt = _unpaidOrdersByRestaurant.values
        .expand((orders) => orders)
        .fold<int>(0, (sum, order) => sum + order.debtAmount.round());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Công nợ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadUnpaidOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _unpaidOrdersByRestaurant.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không có công nợ',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm nhà hàng...',
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
                    
                    // Total debt summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border(
                          bottom: BorderSide(color: Colors.red.shade200),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Tổng công nợ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyUtils.formatCurrency(totalDebt.toDouble()),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_unpaidOrdersByRestaurant.length} nhà hàng',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // List of restaurants with unpaid orders
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          // Filter by search query
                          var filteredEntries = _unpaidOrdersByRestaurant.entries.toList();
                          if (_searchQuery.isNotEmpty) {
                            final normalizedQuery = normalizeForSearch(_searchQuery);
                            filteredEntries = filteredEntries.where((entry) {
                              final restaurantName = entry.key.split('___')[1];
                              return normalizeForSearch(restaurantName).contains(normalizedQuery);
                            }).toList();
                          }

                          if (filteredEntries.isEmpty) {
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
                                    'Không tìm thấy nhà hàng nào',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: filteredEntries.length,
                            itemBuilder: (context, index) {
                              final entry = filteredEntries[index];
                              final restaurantKey = entry.key;
                              final restaurantName = restaurantKey.split('___')[1];
                              final orders = entry.value;
                              final restaurantDebt = _calculateRestaurantDebt(orders);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: Icon(
                                  Icons.restaurant,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                restaurantName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                '${orders.length} đơn hàng',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.share_outlined, size: 20),
                                    tooltip: 'Chia sẻ công nợ',
                                    onPressed: () => _shareRestaurantDebt(restaurantName, orders),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyUtils.formatCurrency(restaurantDebt.toDouble()),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[700],
                                        ),
                                      ),
                                      Text(
                                        'Còn nợ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              children: orders.map((order) {
                                final itemCount = _calculateTotalItems(order);
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => OrderDetailScreen(
                                          orderId: order.id,
                                          restaurantName: restaurantName,
                                        ),
                                      ),
                                    ).then((_) => _loadUnpaidOrders());
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: Colors.grey.shade200),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Date
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                formatDate(order.deliveryDate),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                order.notes ?? '',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Item count
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '$itemCount SP',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),

                                        // Total amount
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                CurrencyUtils.formatCurrency(order.totalAmount),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Nợ: ${CurrencyUtils.formatCurrency(order.debtAmount)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 20,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
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
}
