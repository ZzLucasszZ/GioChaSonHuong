import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart' as currency;
import '../../core/utils/thousands_separator_formatter.dart';
import '../../core/utils/vietnamese_utils.dart';
import '../../data/models/order.dart';
import '../../data/models/payment.dart';
import '../../data/models/restaurant.dart';
import '../../providers/order_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../home/order_detail_screen.dart';
import '../shared/share_preview_dialog.dart';
import 'restaurant_debt_detail_screen.dart';

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

class DebtTab extends StatefulWidget {
  const DebtTab({super.key});

  @override
  State<DebtTab> createState() => _DebtTabState();
}

class _DebtTabState extends State<DebtTab> {
  List<Order> _unpaidOrders = [];
  bool _isLoading = false;
  
  // Group orders by restaurant
  Map<String, List<Order>> _ordersByRestaurant = {};
  
  // General/reconciliation payment totals per restaurantId (not reflected in order.paidAmount)
  Map<String, double> _generalPaidByRestaurantId = {};

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadUnpaidOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadUnpaidOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orderProvider = context.read<OrderProvider>();
      final orders = await orderProvider.loadUnpaidOrders();
      
      // Load general payment totals (reconciliation payments not in order.paidAmount)
      final generalPaid = await orderProvider.getGeneralPaidByRestaurant();
      
      // Group by restaurant
      final grouped = <String, List<Order>>{};
      for (final order in orders) {
        final restaurantName = order.restaurantName ?? 'Unknown';
        if (!grouped.containsKey(restaurantName)) {
          grouped[restaurantName] = [];
        }
        grouped[restaurantName]!.add(order);
      }

      setState(() {
        _unpaidOrders = orders;
        _ordersByRestaurant = grouped;
        _generalPaidByRestaurantId = generalPaid;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double get _totalDebt {
    return _unpaidOrders.fold(0, (sum, order) => sum + order.debtAmount);
  }

  /// General payments total across all restaurants
  double get _totalGeneralPaid {
    return _generalPaidByRestaurantId.values.fold(0.0, (sum, v) => sum + v);
  }

  /// Actual remaining debt = order debts - general payments
  double get _actualTotalRemaining => _totalDebt - _totalGeneralPaid;

  /// Get general paid amount for a specific restaurant by its ID
  double _getGeneralPaidForRestaurant(String restaurantId) {
    return _generalPaidByRestaurantId[restaurantId] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Công nợ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadUnpaidOrders,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFabOptions,
        backgroundColor: AppColors.error,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _unpaidOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: AppColors.success),
                      const SizedBox(height: 16),
                      Text(
                        'Không có công nợ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tất cả đơn hàng đã được thanh toán',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Total debt card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.error, const Color(0xFFE57373)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Tổng công nợ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currency.formatCurrency(_actualTotalRemaining.round()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_unpaidOrders.length} đơn • ${_ordersByRestaurant.length} nhà hàng',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _unpaidOrders.isNotEmpty ? _payAllDebts : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white70),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.payment, size: 18),
                              label: const Text('Thanh toán toàn bộ'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Restaurant list
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          // Filter restaurants by search query
                          var restaurantNames = _ordersByRestaurant.keys.toList();
                          if (_searchQuery.isNotEmpty) {
                            final normalizedQuery = normalizeForSearch(_searchQuery);
                            restaurantNames = restaurantNames.where((name) =>
                              normalizeForSearch(name).contains(normalizedQuery)
                            ).toList();
                          }

                          if (restaurantNames.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Không tìm thấy nhà hàng',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: restaurantNames.length,
                            itemBuilder: (context, index) {
                              final restaurantName = restaurantNames[index];
                              final orders = _ordersByRestaurant[restaurantName]!;
                              final orderDebt = orders.fold(0.0, (sum, o) => sum + o.debtAmount);
                              final restaurantId = orders.first.restaurantId;
                              final generalPaid = _getGeneralPaidForRestaurant(restaurantId);
                              final totalDebt = orderDebt - generalPaid;

                              return _buildRestaurantCard(restaurantName, orders, totalDebt);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildRestaurantCard(String restaurantName, List<Order> orders, double totalDebt) {
    // Group orders by date
    final ordersByDate = <String, List<Order>>{};
    for (final order in orders) {
      final dateKey = DateFormat('dd/MM/yyyy').format(order.deliveryDate);
      if (!ordersByDate.containsKey(dateKey)) {
        ordersByDate[dateKey] = [];
      }
      ordersByDate[dateKey]!.add(order);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: GestureDetector(
          onTap: () => _navigateToRestaurantDebt(restaurantName, orders),
          child: CircleAvatar(
            backgroundColor: AppColors.error.withOpacity(0.1),
            child: Icon(Icons.restaurant, color: AppColors.error),
          ),
        ),
        title: GestureDetector(
          onTap: () => _navigateToRestaurantDebt(restaurantName, orders),
          child: Text(
            restaurantName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        subtitle: GestureDetector(
          onTap: () => _navigateToRestaurantDebt(restaurantName, orders),
          child: Text(
            '${orders.length} đơn • Nợ: ${currency.formatCurrency(totalDebt.round())}',
            style: TextStyle(color: AppColors.error),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 20),
              onPressed: () => _shareRestaurantDebt(restaurantName, orders, totalDebt),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          // Orders grouped by date with pay button
          ...ordersByDate.entries.map((entry) {
            final dateKey = entry.key;
            final dateOrders = entry.value;
            final dateDebt = dateOrders.fold(0.0, (sum, o) => sum + o.debtAmount);

            return Column(
              children: [
                // Date header with pay button
                Container(
                  padding: const EdgeInsets.all(12),
                  color: AppColors.surface,
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateKey,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                currency.formatCurrency(dateDebt.round()),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        onPressed: () => _shareRestaurantDebt(restaurantName, dateOrders, dateDebt),
                        tooltip: 'Chia sẻ ngày này',
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                        onPressed: () => _payByDate(dateOrders, dateDebt),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          backgroundColor: AppColors.success,
                        ),
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Thanh toán'),
                      ),
                    ],
                  ),
                ),
                // Orders for this date
                ...dateOrders.map((order) => _buildOrderTile(order)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Future<void> _payAllDebts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thanh toán toàn bộ'),
        content: Text(
          'Thanh toán tất cả ${_unpaidOrders.length} đơn hàng của ${_ordersByRestaurant.length} nhà hàng với tổng số tiền ${currency.formatCurrency(_actualTotalRemaining.round())}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Thanh toán'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final amountToPay = _actualTotalRemaining;
      final orderProvider = context.read<OrderProvider>();

      // Distribute across all orders oldest-first, capped at actualTotalRemaining
      double remaining = amountToPay;
      final sorted = List<Order>.from(_unpaidOrders)
        ..sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));
      for (final order in sorted) {
        if (remaining <= 0) break;
        final debt = order.debtAmount;
        if (debt <= 0) continue;
        final pay = remaining >= debt ? debt : remaining;
        await orderProvider.updatePayment(context, order.id, pay);
        remaining -= pay;
      }

      await loadUnpaidOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thanh toán toàn bộ ${currency.formatCurrency(amountToPay.round())}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _navigateToRestaurantDebt(String restaurantName, List<Order> orders) {
    if (orders.isEmpty) return;
    final restaurantId = orders.first.restaurantId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDebtDetailScreen(
          restaurantName: restaurantName,
          restaurantId: restaurantId,
        ),
      ),
    ).then((_) => loadUnpaidOrders());
  }

  /// Check if an order is a manual debt (no items)
  bool _isManualDebt(Order order) {
    return order.items == null || order.items!.isEmpty;
  }

  Widget _buildOrderTile(Order order) {
    final paymentColor = _getPaymentColor(order.paymentStatus);
    final isManual = _isManualDebt(order);
    
    return ListTile(
      dense: true,
      onTap: () {
        if (isManual) {
          _showEditManualDebtDialog(order);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                orderId: order.id,
                restaurantName: order.restaurantName ?? 'Nhà hàng',
              ),
            ),
          ).then((_) => loadUnpaidOrders());
        }
      },
      onLongPress: () => _showOrderActions(order),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: paymentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isManual ? Icons.edit_note : Icons.receipt_outlined,
          size: 18,
          color: paymentColor,
        ),
      ),
      title: Text(
        order.notes ?? (isManual ? 'Nợ cũ' : 'Đơn hàng'),
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        isManual
            ? 'Nợ: ${currency.formatCurrency(order.debtAmount.round())}'
            : '${order.session?.displayName ?? ''} • Nợ: ${currency.formatCurrency(order.debtAmount.round())}',
        style: TextStyle(
          fontSize: 12,
          color: order.debtAmount > 0 ? AppColors.error : AppColors.success,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isManual) ...[
            InkWell(
              onTap: () => _showEditManualDebtDialog(order),
              child: Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _confirmDeleteDebt(order),
              child: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
            ),
          ] else
            const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    );
  }

  void _showOrderActions(Order order) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isManualDebt(order)) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Sửa'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditManualDebtDialog(order);
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.blue),
                title: const Text('Xem chi tiết'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(
                        orderId: order.id,
                        restaurantName: order.restaurantName ?? 'Nhà hàng',
                      ),
                    ),
                  ).then((_) => loadUnpaidOrders());
                },
              ),
            ListTile(
              leading: Icon(Icons.delete, color: AppColors.error),
              title: const Text('Xóa'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteDebt(order);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDebt(Order order) async {
    final isManual = _isManualDebt(order);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          isManual
              ? 'Xóa nợ ${currency.formatCurrency(order.debtAmount.round())} ngày ${DateFormat('dd/MM/yyyy').format(order.deliveryDate)}?'
              : 'Xóa đơn hàng ${currency.formatCurrency(order.totalAmount.round())} ngày ${DateFormat('dd/MM/yyyy').format(order.deliveryDate)}?\n\nĐơn hàng sẽ bị xóa hoàn toàn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final provider = context.read<OrderProvider>();
        final success = await provider.deleteManualDebt(order.id);
        if (success && mounted) {
          await loadUnpaidOrders();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa ${isManual ? "nợ" : "đơn hàng"}'),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể xóa ${isManual ? "nợ" : "đơn hàng"}'),
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

  Future<void> _showEditManualDebtDialog(Order order) async {
    DateTime selectedDate = order.deliveryDate;
    final amountController = TextEditingController(text: currency.formatNumber(order.debtAmount.round()));
    final notesController = TextEditingController(text: order.notes ?? 'Nợ cũ');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sửa nợ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      locale: const Locale('vi', 'VN'),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ngày *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(selectedDate),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Amount input
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền nợ *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                    suffixText: '₫',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                ),
                const SizedBox(height: 16),

                // Notes
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final amountText = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
                if (amountText.isEmpty || int.tryParse(amountText) == null || int.parse(amountText) <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final amountText = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
      final amount = double.parse(amountText);

      final provider = context.read<OrderProvider>();
      final success = await provider.updateManualDebt(
        orderId: order.id,
        date: selectedDate,
        amount: amount,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
      );

      if (success && mounted) {
        await loadUnpaidOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật nợ thành ${currency.formatCurrency(amount.round())}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      amountController.dispose();
      notesController.dispose();
    });
  }

  void _showFabOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.error.withOpacity(0.1),
                  child: Icon(Icons.add_circle_outline, color: AppColors.error),
                ),
                title: const Text('Thêm nợ cũ'),
                subtitle: const Text('Ghi nhận khoản nợ mới'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddManualDebtDialog();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.success.withOpacity(0.1),
                  child: Icon(Icons.payment, color: AppColors.success),
                ),
                title: const Text('Thanh toán 1 phần'),
                subtitle: const Text('Ghi nhận thanh toán một phần'),
                onTap: () {
                  Navigator.pop(context);
                  _showPartialPaymentDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPartialPaymentDialog() async {
    if (_unpaidOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có đơn nợ nào')),
      );
      return;
    }

    String? selectedRestaurantName;
    DateTime paymentDate = DateTime.now();
    final amountController = TextEditingController();
    final restaurantNames = _ordersByRestaurant.keys.toList()..sort();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final ordersForRestaurant = selectedRestaurantName != null
              ? (_ordersByRestaurant[selectedRestaurantName] ?? [])
              : <Order>[];
          final orderDebt = ordersForRestaurant.fold(0.0, (sum, o) => sum + o.debtAmount);
          final generalPaid = ordersForRestaurant.isNotEmpty
              ? _getGeneralPaidForRestaurant(ordersForRestaurant.first.restaurantId)
              : 0.0;
          final restaurantDebt = orderDebt - generalPaid;

          return AlertDialog(
            title: const Text('Thanh toán 1 phần'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant picker
                  DropdownButtonFormField<String>(
                    value: selectedRestaurantName,
                    decoration: const InputDecoration(
                      labelText: 'Nhà hàng *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.restaurant),
                    ),
                    items: restaurantNames.map((name) {
                      final orders = _ordersByRestaurant[name] ?? [];
                      final orderDebt = orders.fold(0.0, (sum, o) => sum + o.debtAmount);
                      final gPaid = orders.isNotEmpty ? _getGeneralPaidForRestaurant(orders.first.restaurantId) : 0.0;
                      final debt = orderDebt - gPaid;
                      return DropdownMenuItem(
                        value: name,
                        child: Text('$name (${currency.formatCurrency(debt.round())})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedRestaurantName = value);
                    },
                    isExpanded: true,
                  ),
                  if (selectedRestaurantName != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tổng nợ (${ordersForRestaurant.length} đơn):', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(currency.formatCurrency(restaurantDebt.round()),
                              style: TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Date picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: paymentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        locale: const Locale('vi', 'VN'),
                      );
                      if (picked != null) {
                        setDialogState(() => paymentDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Ngày trả nợ *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(paymentDate),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount input
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Số tiền thanh toán *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.attach_money),
                      suffixText: '₫',
                      helperText: selectedRestaurantName != null
                          ? 'Tối đa: ${currency.formatCurrency(restaurantDebt.round())}'
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Số tiền sẽ được ghi nhận và trừ vào tổng công nợ.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  if (selectedRestaurantName == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng chọn nhà hàng')),
                    );
                    return;
                  }
                  final amountText = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
                  if (amountText.isEmpty || int.tryParse(amountText) == null || int.parse(amountText) <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
                    );
                    return;
                  }
                  final amount = int.parse(amountText);
                  if (amount > restaurantDebt.round()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Số tiền không được vượt quá ${currency.formatCurrency(restaurantDebt.round())}')),
                    );
                    return;
                  }
                  Navigator.of(context).pop(true);
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                child: const Text('Thanh toán'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && selectedRestaurantName != null && mounted) {
      final amountText = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
      final amount = double.parse(amountText);

      // Get restaurantId from orders
      final ordersForSelected = _ordersByRestaurant[selectedRestaurantName] ?? [];
      if (ordersForSelected.isEmpty) return;
      final restaurantId = ordersForSelected.first.restaurantId;

      final orderProvider = context.read<OrderProvider>();

      // Create a single general payment record (not linked to any order)
      final success = await orderProvider.insertPaymentRecordOnly(
        restaurantId: restaurantId,
        amount: amount,
        paymentDate: paymentDate,
        notes: 'Thanh toán 1 phần',
      );

      if (success) {
        await loadUnpaidOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã thanh toán ${currency.formatCurrency(amount.round())} cho $selectedRestaurantName ngày ${DateFormat('dd/MM/yyyy').format(paymentDate)}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      amountController.dispose();
    });
  }

  Future<void> _showAddManualDebtDialog() async {
    final restaurantProvider = context.read<RestaurantProvider>();
    if (restaurantProvider.restaurants.isEmpty) {
      await restaurantProvider.loadRestaurants();
    }
    final restaurants = restaurantProvider.restaurants;

    if (restaurants.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa có nhà hàng nào')),
        );
      }
      return;
    }

    Restaurant? selectedRestaurant;
    DateTime selectedDate = DateTime.now();
    final amountController = TextEditingController();
    final notesController = TextEditingController(text: 'Nợ cũ');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm nợ cũ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restaurant picker
                DropdownButtonFormField<Restaurant>(
                  value: selectedRestaurant,
                  decoration: const InputDecoration(
                    labelText: 'Nhà hàng *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.restaurant),
                  ),
                  items: restaurants.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.name, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedRestaurant = value);
                  },
                  isExpanded: true,
                ),
                const SizedBox(height: 16),

                // Date picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      locale: const Locale('vi', 'VN'),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ngày *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(selectedDate),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Amount input
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền nợ *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                    suffixText: '₫',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                ),
                const SizedBox(height: 16),

                // Notes
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedRestaurant == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng chọn nhà hàng')),
                  );
                  return;
                }
                final amountText = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
                if (amountText.isEmpty || int.tryParse(amountText) == null || int.parse(amountText) <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedRestaurant != null) {
      final amountText = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
      final amount = double.parse(amountText);
      
      final orderProvider = context.read<OrderProvider>();
      final success = await orderProvider.createManualDebt(
        restaurantId: selectedRestaurant!.id,
        date: selectedDate,
        amount: amount,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
      );

      if (success && mounted) {
        await loadUnpaidOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm nợ ${currency.formatCurrency(amount.round())} cho ${selectedRestaurant!.name}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }

    // Deferred disposal
    Future.delayed(const Duration(milliseconds: 300), () {
      amountController.dispose();
      notesController.dispose();
    });
  }

  Future<void> _payByDate(List<Order> orders, double totalDebt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thanh toán'),
        content: Text(
          'Thanh toán ${orders.length} đơn hàng với tổng số tiền ${currency.formatCurrency(totalDebt.round())}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Thanh toán'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final orderProvider = context.read<OrderProvider>();
      
      for (final order in orders) {
        await orderProvider.updatePayment(context, order.id, order.debtAmount);
      }
      
      await loadUnpaidOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thanh toán ${currency.formatCurrency(totalDebt.round())}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _shareRestaurantDebt(String restaurantName, List<Order> orders, double totalDebt) async {
    if (orders.isEmpty) return;
    final provider = context.read<OrderProvider>();
    final restaurantId = orders.first.restaurantId;
    final payments = await provider.getPaymentsByRestaurant(restaurantId);

    final allGeneral = payments.where((p) => p.orderId == null).toList();
    final generalPaid = allGeneral.fold<double>(0, (sum, p) => sum + p.amount);
    final rawDebt = totalDebt - generalPaid;
    final actualDebt = rawDebt < 0 ? 0.0 : rawDebt;
    final message = _buildDebtMessage(restaurantName, orders, actualDebt, allGeneral);
    if (mounted) {
      SharePreviewDialog.show(context, message: message);
    }
  }

  String _buildDebtMessage(String restaurantName, List<Order> orders, double totalDebt, List<Payment> payments) {
    final buffer = StringBuffer();
    buffer.writeln('📋 CÔNG NỢ: $restaurantName');
    buffer.writeln('═══════════════════');

    // Sort orders by date ascending (oldest first)
    final sortedOrders = List<Order>.from(orders)
      ..sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));

    // Show original order amounts (totalAmount)
    final lines = <Map<String, String>>[];
    double totalOriginal = 0;
    for (final order in sortedOrders) {
      final dateKey = DateFormat('dd/MM').format(order.deliveryDate);
      final amountStr = currency.formatCurrency(order.totalAmount.round());
      lines.add({'date': dateKey, 'amount': amountStr});
      totalOriginal += order.totalAmount;
    }
    
    // Find max amount string length for right-alignment
    int maxLen = 0;
    for (final line in lines) {
      if (line['amount']!.length > maxLen) maxLen = line['amount']!.length;
    }
    
    // Write aligned lines
    for (final line in lines) {
      final padded = line['amount']!.padLeft(maxLen);
      buffer.writeln('${line['date']}:  $padded');
    }

    buffer.writeln('═══════════════════');

    // Payment history section (only partial/general payments)
    if (payments.isNotEmpty) {
      buffer.writeln('💰 Tổng nợ: ${currency.formatCurrency(totalOriginal.round())}');
      buffer.writeln('');
      buffer.writeln('✅ ĐÃ THANH TOÁN:');
      for (final payment in payments) {
        final dateStr =
            DateFormat('dd/MM/yyyy').format(payment.paymentDate);
        final amountStr =
            currency.formatCurrency(payment.amount.round());
        buffer.writeln('  $dateStr:  -$amountStr');
      }
      buffer.writeln('───────────────────');
      buffer.writeln(
          '🔴 Còn nợ: ${currency.formatCurrency(totalDebt.round())}');
    } else {
      buffer.writeln('💰 TỔNG: ${currency.formatCurrency(totalDebt.round())}');
    }

    return buffer.toString();
  }
}
