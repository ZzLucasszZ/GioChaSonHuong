import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/order_repository.dart';

/// Dialog showing which orders/restaurants make up the "Đã đặt" quantity
/// for a specific product.
class OrderedBreakdownDialog extends StatelessWidget {
  final Product product;
  final int totalOrdered;
  final OrderRepository orderRepository;
  final DateTime? untilDate;

  const OrderedBreakdownDialog({
    super.key,
    required this.product,
    required this.totalOrdered,
    required this.orderRepository,
    this.untilDate,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Đã đặt: $totalOrdered ${product.unit}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Body — order list
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: orderRepository.getOrderedQuantityBreakdown(
                  product.id,
                  untilDate: untilDate,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Lỗi: ${snapshot.error}',
                        style: TextStyle(color: AppColors.error),
                      ),
                    );
                  }

                  final rows = snapshot.data ?? [];

                  if (rows.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Không có đơn hàng nào'),
                    );
                  }

                  // Group by delivery_date
                  final grouped = <String, List<Map<String, dynamic>>>{};
                  for (final row in rows) {
                    final dateStr = row['delivery_date'] as String;
                    grouped.putIfAbsent(dateStr, () => []).add(row);
                  }

                  final dateKeys = grouped.keys.toList()..sort();

                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: dateKeys.length,
                    itemBuilder: (context, index) {
                      final dateStr = dateKeys[index];
                      final orders = grouped[dateStr]!;
                      final date = AppDateUtils.parseDbDate(dateStr) ?? DateTime.now();
                      final formattedDate = _formatDate(date);

                      // Sum for this date
                      final dateTotal = orders.fold<double>(
                        0,
                        (sum, r) => sum + ((r['quantity'] as num?)?.toDouble() ?? 0),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index > 0) const Divider(height: 20),
                          // Date header
                          Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_formatQty(dateTotal)} ${product.unit}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.info,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Order rows
                          ...orders.map((row) => _buildOrderRow(row)),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderRow(Map<String, dynamic> row) {
    final restaurantName = row['restaurant_name'] as String? ?? '';
    final session = row['session'] as String?;
    final quantity = (row['quantity'] as num?)?.toDouble() ?? 0;
    final status = row['status'] as String? ?? '';

    final sessionLabel = session != null
        ? OrderSessionExtension.fromString(session).displayName
        : '';
    final statusLabel = _statusLabel(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const SizedBox(width: 20),
          // Session icon
          if (sessionLabel.isNotEmpty) ...[
            Text(
              sessionLabel,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 6),
          ],
          // Restaurant name
          Expanded(
            child: Text(
              restaurantName,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 10,
                color: _statusColor(status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Quantity
          Text(
            '${_formatQty(quantity)} ${product.unit}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    final weekday = weekdays[date.weekday - 1];
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$weekday, $d/$m/${date.year}';
  }

  String _formatQty(double qty) {
    return qty == qty.roundToDouble() ? qty.round().toString() : qty.toStringAsFixed(1);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ';
      case 'confirmed':
        return 'Xác nhận';
      case 'delivering':
        return 'Đang giao';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.info;
      case 'delivering':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }
}
