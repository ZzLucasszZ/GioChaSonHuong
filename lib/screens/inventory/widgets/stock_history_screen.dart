import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/inventory_transaction.dart';
import '../../../providers/inventory_provider.dart';

/// Screen to show stock transaction history with date filtering and editing
class StockHistoryScreen extends StatefulWidget {
  const StockHistoryScreen({super.key});

  @override
  State<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends State<StockHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _showAllDates = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
  }

  Future<void> _loadTransactions() async {
    final provider = context.read<InventoryProvider>();
    if (_showAllDates) {
      await provider.loadRecentTransactions(limit: 100);
    } else {
      await provider.loadTransactionsByDate(_selectedDate);
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
        _showAllDates = false;
      });
      _loadTransactions();
    }
  }

  void _goToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _showAllDates = false;
    });
    _loadTransactions();
  }

  void _goToNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _showAllDates = false;
    });
    _loadTransactions();
  }

  void _showAll() {
    setState(() {
      _showAllDates = true;
    });
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử nhập/xuất kho'),
        actions: [
          if (!_showAllDates)
            TextButton(
              onPressed: _showAll,
              child: const Text('Tất cả'),
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
                IconButton(
                  onPressed: _goToPreviousDay,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Ngày trước',
                ),
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _showAllDates
                            ? Colors.grey.withOpacity(0.1)
                            : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 20,
                            color: _showAllDates ? Colors.grey : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _showAllDates
                                  ? 'Tất cả giao dịch gần đây'
                                  : DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_selectedDate),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _showAllDates ? Colors.grey : AppColors.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (!_showAllDates) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _showAll,
                              child: const Icon(Icons.close, size: 18, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _goToNextDay,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Ngày sau',
                ),
              ],
            ),
          ),

          // Transactions list
          Expanded(
            child: Consumer<InventoryProvider>(
              builder: (context, provider, _) {
                final transactions = provider.transactions;

                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _showAllDates
                              ? 'Chưa có giao dịch nào'
                              : 'Không có giao dịch ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final txn = transactions[index];
                    return _buildTransactionCard(txn);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(InventoryTransaction txn) {
    final isStockIn = txn.type == TransactionType.stockIn || txn.type == TransactionType.returned;
    final typeColor = isStockIn ? Colors.green : Colors.red;
    final typeIcon = isStockIn ? Icons.add_circle : Icons.remove_circle;
    final sign = isStockIn ? '+' : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showEditDialog(txn),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Type icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(typeIcon, color: typeColor),
              ),
              const SizedBox(width: 12),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.productName ?? 'Sản phẩm',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(txn.createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (txn.notes != null && txn.notes!.isNotEmpty)
                      Text(
                        txn.notes!,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
              // Quantity and type
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${txn.quantity.round()}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                  Text(
                    txn.type.displayName,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              // Edit indicator
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(InventoryTransaction txn) async {
    final quantityController = TextEditingController(text: txn.quantity.round().toString());
    final notesController = TextEditingController(text: txn.notes ?? '');

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Chỉnh sửa giao dịch')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.productName ?? 'Sản phẩm',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${txn.type.displayName} • ${DateFormat('dd/MM/yyyy HH:mm').format(txn.createdAt)}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Quantity
              TextFormField(
                controller: quantityController,
                autofocus: false,
                decoration: InputDecoration(
                  labelText: 'Số lượng',
                  suffixText: txn.productUnit ?? '',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              // Notes
              TextFormField(
                controller: notesController,
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, {'action': 'delete'}),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(quantityController.text);
              if (qty == null || qty <= 0) return;
              Navigator.pop(ctx, {
                'action': 'update',
                'quantity': qty,
                'notes': notesController.text.trim(),
              });
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) {
      quantityController.dispose();
      notesController.dispose();
      return;
    }

    // Capture values before disposing controllers
    final action = result['action'];
    final quantity = result['quantity'] as double?;
    final notes = result['notes'] as String?;

    // Defer disposal until dialog animation finishes
    Future.delayed(const Duration(milliseconds: 300), () {
      quantityController.dispose();
      notesController.dispose();
    });

    if (action == 'delete') {
      await _confirmDelete(txn);
    } else if (action == 'update' && quantity != null) {
      final provider = context.read<InventoryProvider>();
      final success = await provider.updateTransaction(
        transactionId: txn.id,
        newQuantity: quantity,
        notes: notes != null && notes.isNotEmpty ? notes : null,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã cập nhật giao dịch'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadTransactions();
      }
    }
  }

  Future<void> _confirmDelete(InventoryTransaction txn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Xóa giao dịch ${txn.type.displayName} ${txn.quantity.round()} ${txn.productUnit ?? ''} ${txn.productName ?? ''}?\n\nTồn kho sẽ được điều chỉnh lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<InventoryProvider>();
    final success = await provider.deleteTransaction(txn.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã xóa giao dịch'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadTransactions();
    }
  }
}
