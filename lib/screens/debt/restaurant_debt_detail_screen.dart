import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart' as currency;
import '../../core/utils/thousands_separator_formatter.dart';
import '../../data/models/order.dart';
import '../../data/models/payment.dart';
import '../../providers/order_provider.dart';
import '../home/order_detail_screen.dart';
import '../shared/share_preview_dialog.dart';

class RestaurantDebtDetailScreen extends StatefulWidget {
  final String restaurantName;
  final String restaurantId;

  const RestaurantDebtDetailScreen({
    super.key,
    required this.restaurantName,
    required this.restaurantId,
  });

  @override
  State<RestaurantDebtDetailScreen> createState() =>
      _RestaurantDebtDetailScreenState();
}

class _RestaurantDebtDetailScreenState
    extends State<RestaurantDebtDetailScreen> {
  List<Order> _orders = [];
  List<Payment> _payments = [];
  List<Map<String, dynamic>> _monthlyRevenue = [];
  bool _isLoading = true;
  double _totalDebt = 0;
  double _totalPaidGeneral = 0; // Only reconciliation payments (order_id IS NULL)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrders());
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final provider = context.read<OrderProvider>();
      final allUnpaid = await provider.loadUnpaidOrders();
      final restaurantOrders = allUnpaid
          .where((o) => o.restaurantId == widget.restaurantId)
          .toList()
        ..sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));

      // Load payment history (all payments for this restaurant)
      final payments = await provider.getPaymentsByRestaurant(widget.restaurantId);

      // Load monthly revenue stats
      final monthlyRevenue = await provider.getMonthlyRevenue(widget.restaurantId);

      if (!mounted) return;
      setState(() {
        _orders = restaurantOrders;
        _payments = payments;
        _monthlyRevenue = monthlyRevenue;
        _totalDebt = restaurantOrders.fold(0.0, (sum, o) => sum + o.debtAmount);
        _totalPaidGeneral = _generalPayments
            .fold(0.0, (sum, p) => sum + p.amount);
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('[DebtDetail] Error loading data: $e\n$stack');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Actual remaining debt = order debts - general/reconciliation payments only.
  /// Linked payment records are already reflected in order.paidAmount (via debtAmount).
  double get _actualRemaining {
    final remaining = _totalDebt - _totalPaidGeneral;
    return remaining < 0 ? 0 : remaining;
  }

  /// All general/partial payments (not linked to specific orders)
  List<Payment> get _generalPayments => _payments.where((p) => p.orderId == null).toList();

  bool _isManualDebt(Order order) {
    return order.items == null || order.items!.isEmpty;
  }

  /// Group orders by date
  Map<String, List<Order>> _groupByDate() {
    final grouped = <String, List<Order>>{};
    for (final order in _orders) {
      final key = DateFormat('dd/MM/yyyy').format(order.deliveryDate);
      grouped.putIfAbsent(key, () => []).add(order);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final ordersByDate = _groupByDate();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurantName),
        actions: [
          if (_orders.isNotEmpty || _generalPayments.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Chia sẻ công nợ',
              onPressed: () => _showSharePreview(
                _buildDebtMessage(widget.restaurantName, _orders, _actualRemaining),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_debt_detail_add',
        onPressed: _showFabOptions,
        backgroundColor: AppColors.error,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_orders.isEmpty && _generalPayments.isEmpty && _monthlyRevenue.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: 64, color: AppColors.success),
                      const SizedBox(height: 16),
                      const Text(
                        'Không còn công nợ',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
                  children: [
                    // Header card (only when there are orders)
                    if (_orders.isNotEmpty) _buildHeaderCard(),
                    // Payment history section (only general/partial payments)
                    if (_generalPayments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildPaymentHistorySection(),
                      ),
                    // Empty debt message when only payments exist
                    if (_orders.isEmpty && _generalPayments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle,
                                size: 48, color: AppColors.success),
                            const SizedBox(height: 12),
                            const Text(
                              'Đã thanh toán hết công nợ',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    // Orders grouped by date
                    if (_orders.isNotEmpty)
                      ...ordersByDate.entries.map((entry) {
                        final dateDebt = entry.value.fold(
                            0.0, (sum, o) => sum + o.debtAmount);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildDateSection(
                              entry.key, entry.value, dateDebt),
                        );
                      }),
                    // Revenue stats section
                    if (_monthlyRevenue.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildRevenueSection(),
                      ),
                  ],
                ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.restaurantName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currency.formatCurrency(_actualRemaining.round()),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_orders.length} đơn chưa thanh toán',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _orders.isNotEmpty ? _payAll : null,
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
    );
  }

  Widget _buildPaymentHistorySection() {
    final payments = _generalPayments;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.receipt_long, color: Colors.green),
        title: Text(
          'Lịch sử thanh toán (${payments.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Đã trả: ${currency.formatCurrency(_totalPaidGeneral.round())}',
          style: const TextStyle(color: Colors.green),
        ),
        initiallyExpanded: true,
        children: [
          const Divider(height: 1),
          ...payments.map((payment) {
            final dateStr =
                DateFormat('dd/MM/yyyy').format(payment.paymentDate);
            return ListTile(
              dense: true,
              leading: Icon(
                payment.method == PaymentMethod.bankTransfer
                    ? Icons.account_balance
                    : Icons.payments,
                size: 20,
                color: Colors.green,
              ),
              title: Text(
                currency.formatCurrency(payment.amount.round()),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              subtitle: Text(
                '${payment.method.displayName} • $dateStr'
                '${payment.notes != null ? ' • ${payment.notes}' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Sửa'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Xóa', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditPaymentDialog(payment);
                  } else if (value == 'delete') {
                    _confirmDeletePayment(payment);
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showEditPaymentDialog(Payment payment) async {
    DateTime editDate = payment.paymentDate;
    final amountController = TextEditingController(
      text: currency.formatNumber(payment.amount.round()),
    );
    final notesController = TextEditingController(text: payment.notes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sửa thanh toán'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: editDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      locale: const Locale('vi', 'VN'),
                    );
                    if (picked != null) {
                      setDialogState(() => editDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ngày thanh toán',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(editDate)),
                  ),
                ),
                const SizedBox(height: 16),
                // Amount
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền *',
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

    if (result == true && mounted) {
      final amountText = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
      final newAmount = double.parse(amountText);
      final provider = context.read<OrderProvider>();
      final success = await provider.editPaymentRecord(
        payment.id,
        newAmount: newAmount,
        newPaymentDate: editDate,
        newNotes: notesController.text.isNotEmpty ? notesController.text : null,
      );

      if (success && mounted) {
        await _loadOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật thanh toán: ${currency.formatCurrency(newAmount.round())}'),
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

  Future<void> _confirmDeletePayment(Payment payment) async {
    final dateStr = DateFormat('dd/MM/yyyy').format(payment.paymentDate);
    final amountStr = currency.formatCurrency(payment.amount.round());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thanh toán'),
        content: Text(
          'Bạn có chắc muốn xóa khoản thanh toán $amountStr ngày $dateStr?\n\n'
          '${payment.orderId != null ? 'Số tiền đã trả sẽ được hoàn lại vào đơn hàng tương ứng.' : 'Công nợ sẽ được cộng lại tương ứng.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<OrderProvider>();
      final success = await provider.deletePaymentRecord(payment.id);

      if (success && mounted) {
        await _loadOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa thanh toán $amountStr'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Widget _buildDateSection(
      String dateKey, List<Order> orders, double dateDebt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Date header with pay button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 16, color: AppColors.textSecondary),
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
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _payByDate(orders, dateDebt),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    backgroundColor: AppColors.success,
                  ),
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Thanh toán'),
                ),
              ],
            ),
          ),
          // Orders for this date
          ...orders.map((order) => _buildOrderTile(order)),
        ],
      ),
    );
  }

  Widget _buildOrderTile(Order order) {
    final isManual = _isManualDebt(order);

    return ListTile(
      onTap: () {
        if (!isManual) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                orderId: order.id,
                restaurantName: order.restaurantName ?? widget.restaurantName,
              ),
            ),
          ).then((_) => _loadOrders());
        }
      },
      onLongPress: () => _showOrderActions(order),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isManual ? Icons.edit_note : Icons.receipt_outlined,
          size: 20,
          color: AppColors.error,
        ),
      ),
      title: Text(
        isManual
            ? (order.notes ?? 'Nợ cũ')
            : '${order.session?.displayName ?? ''} - ${order.items?.length ?? 0} sản phẩm',
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: isManual
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.items != null)
                  ...order.items!.take(3).map((item) {
                    final qtyStr = item.quantity % 1 == 0
                        ? item.quantity.toInt().toString()
                        : item.quantity.toStringAsFixed(1);
                    return Text(
                      '• ${item.productName}: $qtyStr ${item.unit}',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    );
                  }),
                if (order.items != null && order.items!.length > 3)
                  Text(
                    '... và ${order.items!.length - 3} sản phẩm khác',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic),
                  ),
              ],
            ),
      trailing: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currency.formatCurrency(order.debtAmount.round()),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.error,
                fontSize: 14,
              ),
            ),
            if (!isManual && order.paidAmount > 0)
              Text(
                'Đã TT: ${currency.formatCurrency(order.paidAmount.round())}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.success,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOrderActions(Order order) {
    final isManual = _isManualDebt(order);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isManual)
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
                        restaurantName: order.restaurantName ?? widget.restaurantName,
                      ),
                    ),
                  ).then((_) => _loadOrders());
                },
              ),
            ListTile(
              leading: Icon(Icons.delete, color: AppColors.error),
              title: Text('Xóa ${isManual ? "nợ" : "đơn hàng"}'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteOrder(order);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOrder(Order order) async {
    final isManual = _isManualDebt(order);
    final dateStr = DateFormat('dd/MM/yyyy').format(order.deliveryDate);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          isManual
              ? 'Xóa nợ ${currency.formatCurrency(order.debtAmount.round())} ngày $dateStr?'
              : 'Xóa đơn hàng ${currency.formatCurrency(order.totalAmount.round())} ngày $dateStr?\n\nĐơn hàng sẽ bị xóa hoàn toàn.',
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
        final bool success;
        if (isManual) {
          success = await provider.deleteManualDebt(order.id);
        } else {
          success = await provider.deleteOrder(order.id, order.restaurantId);
        }
        if (success && mounted) {
          await _loadOrders();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã xóa ${isManual ? "nợ" : "đơn hàng"}'),
                backgroundColor: AppColors.success,
              ),
            );
          }
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

    if (confirmed == true && mounted) {
      final orderProvider = context.read<OrderProvider>();
      for (final order in orders) {
        await orderProvider.updatePayment(context, order.id, order.debtAmount);
      }
      await _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Đã thanh toán ${currency.formatCurrency(totalDebt.round())}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _payAll() async {
    final amountToPay = _actualRemaining;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thanh toán toàn bộ'),
        content: Text(
          'Thanh toán tất cả ${_orders.length} đơn hàng với tổng số tiền ${currency.formatCurrency(amountToPay.round())} cho ${widget.restaurantName}?',
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
      final orderProvider = context.read<OrderProvider>();

      // Distribute _actualRemaining across orders oldest-first
      // This avoids double-counting with existing general payments
      double remaining = amountToPay;
      final sorted = List<Order>.from(_orders)
        ..sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));
      for (final order in sorted) {
        if (remaining <= 0) break;
        final debt = order.debtAmount;
        if (debt <= 0) continue;
        final pay = remaining >= debt ? debt : remaining;
        await orderProvider.updatePayment(context, order.id, pay);
        remaining -= pay;
      }

      await _loadOrders();
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
    if (_orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có đơn nợ nào')),
      );
      return;
    }

    DateTime paymentDate = DateTime.now();
    final amountController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Thanh toán 1 phần - ${widget.restaurantName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Debt summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text('Còn nợ:',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                currency.formatCurrency(_actualRemaining.round()),
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_orders.length} đơn chưa thanh toán',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
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
                      helperText: 'Tối đa: ${currency.formatCurrency(_actualRemaining.round())}',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                    autofocus: true,
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
                  final amountText = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
                  if (amountText.isEmpty || int.tryParse(amountText) == null || int.parse(amountText) <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
                    );
                    return;
                  }
                  final amount = int.parse(amountText);
                  if (amount > _actualRemaining.round()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Số tiền không được vượt quá ${currency.formatCurrency(_actualRemaining.round())}')),
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

    if (result == true && mounted) {
      final amountText = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
      final amount = double.parse(amountText);

      final orderProvider = context.read<OrderProvider>();

      // Create a single general payment record (not linked to any order)
      final success = await orderProvider.insertPaymentRecordOnly(
        restaurantId: widget.restaurantId,
        amount: amount,
        paymentDate: paymentDate,
        notes: 'Thanh toán 1 phần',
      );

      if (success) {
        await _loadOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã thanh toán ${currency.formatCurrency(amount.round())} ngày ${DateFormat('dd/MM/yyyy').format(paymentDate)}'),
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
    DateTime selectedDate = DateTime.now();
    final amountController = TextEditingController();
    final notesController = TextEditingController(text: 'Nợ cũ');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Thêm nợ - ${widget.restaurantName}'),
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
                  autofocus: true,
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
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final amountText = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
      final amount = double.parse(amountText);

      final orderProvider = context.read<OrderProvider>();
      final success = await orderProvider.createManualDebt(
        restaurantId: widget.restaurantId,
        date: selectedDate,
        amount: amount,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
      );

      if (success && mounted) {
        await _loadOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm nợ ${currency.formatCurrency(amount.round())}'),
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

  Widget _buildRevenueSection() {
    // Group by year
    final byYear = <String, List<Map<String, dynamic>>>{};
    double grandTotal = 0;
    int grandCount = 0;
    for (final row in _monthlyRevenue) {
      final month = row['month']?.toString() ?? '';
      final year = month.length >= 4 ? month.substring(0, 4) : 'N/A';
      byYear.putIfAbsent(year, () => []).add(row);
      grandTotal += (row['total_amount'] as num?)?.toDouble() ?? 0;
      grandCount += (row['order_count'] as num?)?.toInt() ?? 0;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Icons.bar_chart, color: AppColors.primary),
        title: const Text(
          'Thống kê tiền hàng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Tổng: ${currency.formatCurrency(grandTotal.round())} ($grandCount đơn)',
          style: TextStyle(color: AppColors.primary),
        ),
        initiallyExpanded: false,
        children: [
          const Divider(height: 1),
          ...byYear.entries.map((yearEntry) {
            final year = yearEntry.key;
            final months = yearEntry.value;
            final yearTotal = months.fold<double>(
                0, (sum, m) => sum + ((m['total_amount'] as num?)?.toDouble() ?? 0));
            final yearCount = months.fold<int>(
                0, (sum, m) => sum + ((m['order_count'] as num?)?.toInt() ?? 0));

            return ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(
                'Năm $year',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                '${currency.formatCurrency(yearTotal.round())} • $yearCount đơn',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              initiallyExpanded: yearEntry.key == byYear.keys.first,
              children: months.map((m) {
                final monthStr = m['month']?.toString() ?? '';
                final amount = (m['total_amount'] as num?)?.toDouble() ?? 0;
                final count = (m['order_count'] as num?)?.toInt() ?? 0;

                // Format month display: "2025-01" → "Tháng 01"
                final monthNum = monthStr.length >= 7 ? monthStr.substring(5, 7) : monthStr;
                final displayMonth = 'Tháng $monthNum';

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: Icon(Icons.calendar_month, size: 18, color: AppColors.textSecondary),
                  title: Text(
                    displayMonth,
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currency.formatCurrency(amount.round()),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '$count đơn',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  String _buildDebtMessage(
      String restaurantName, List<Order> orders, double totalDebt) {
    final buffer = StringBuffer();
    buffer.writeln('📋 CÔNG NỢ: $restaurantName');
    buffer.writeln('═══════════════════');

    final sortedOrders = List<Order>.from(orders)
      ..sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));

    // Group orders by date and sum totals
    final dailyTotals = <String, double>{};
    double totalOriginal = 0;
    for (final order in sortedOrders) {
      final dateKey = DateFormat('dd/MM').format(order.deliveryDate);
      dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + order.totalAmount;
      totalOriginal += order.totalAmount;
    }

    final lines = dailyTotals.entries
        .map((e) => {'date': e.key, 'amount': currency.formatCurrency(e.value.round())})
        .toList();

    int maxLen = 0;
    for (final line in lines) {
      if (line['amount']!.length > maxLen) maxLen = line['amount']!.length;
    }

    for (final line in lines) {
      final padded = line['amount']!.padLeft(maxLen);
      buffer.writeln('${line['date']}:  $padded');
    }

    buffer.writeln('═══════════════════');

    // Payment history section (only general/partial payments)
    final generalPmts = _generalPayments;
    if (generalPmts.isNotEmpty) {
      buffer.writeln('💰 Tổng nợ: ${currency.formatCurrency(totalOriginal.round())}');
      buffer.writeln('');
      buffer.writeln('✅ ĐÃ THANH TOÁN:');
      for (final payment in generalPmts) {
        final dateStr =
            DateFormat('dd/MM/yyyy').format(payment.paymentDate);
        final amountStr =
            currency.formatCurrency(payment.amount.round());
        buffer.writeln('  $dateStr:  -$amountStr');
      }
      buffer.writeln('───────────────────');
      buffer.writeln(
          ' Còn nợ: ${currency.formatCurrency(totalDebt.round())}');
    } else {
      buffer.writeln('💰 TỔNG: ${currency.formatCurrency(totalDebt.round())}');
    }

    return buffer.toString();
  }

  void _showSharePreview(String message) {
    SharePreviewDialog.show(context, message: message);
  }
}
