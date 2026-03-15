import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/rental_invoice.dart';
import '../../../data/models/tenant.dart';

/// Which portion of the invoice is being collected in this session.
enum PaymentMode {
  /// Collect everything at once (rent + electricity + water).
  full,

  /// Collect only the rent in advance (meter readings not yet available).
  rentOnly,

  /// Collect electricity/water portion after rent was pre-paid.
  utilityOnly,
}

/// Dialog for collecting payment on a rental invoice.
/// Adapts its UI based on [mode].
class PaymentDialog extends StatefulWidget {
  final RentalInvoice invoice;
  final Tenant tenant;
  final PaymentMode mode;

  /// Called with (paidAt, notes) when the user confirms. Return true on success.
  final Future<bool> Function(DateTime paidAt, String? notes) onConfirm;

  const PaymentDialog({
    super.key,
    required this.invoice,
    required this.tenant,
    required this.onConfirm,
    this.mode = PaymentMode.full,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  DateTime _paidAt = DateTime.now();
  final _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  static final _dateFmt = DateFormat('dd/MM/yyyy', 'vi_VN');

  RentalInvoice get _inv => widget.invoice;
  PaymentMode get _mode => widget.mode;

  double get _collectAmount {
    switch (_mode) {
      case PaymentMode.rentOnly:
        return _inv.rentAmount;
      case PaymentMode.utilityOnly:
        return _inv.electricityAmount + _inv.waterAmount + _inv.otherFees;
      case PaymentMode.full:
        return _inv.totalAmount;
    }
  }

  String get _title {
    switch (_mode) {
      case PaymentMode.rentOnly:
        return 'Thu tiền nhà';
      case PaymentMode.utilityOnly:
        return 'Thu điện nước';
      case PaymentMode.full:
        return 'Thu tiền';
    }
  }

  String get _confirmLabel {
    switch (_mode) {
      case PaymentMode.rentOnly:
        return 'Xác nhận thu tiền nhà';
      case PaymentMode.utilityOnly:
        return 'Xác nhận thu điện nước';
      case PaymentMode.full:
        return 'Xác nhận thu tiền';
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) setState(() => _paidAt = picked);
  }

  Future<void> _confirm() async {
    setState(() => _isSubmitting = true);
    final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
    final success = await widget.onConfirm(_paidAt, notes);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.payments_outlined, color: AppColors.success, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Phòng ${widget.tenant.roomNumber} · ${_inv.periodDisplay}',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Invoice breakdown ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    // ── rentOnly mode ──
                    if (_mode == PaymentMode.rentOnly) ...[
                      _breakdownRow(
                        Icons.home_outlined,
                        'Tiền nhà',
                        formatCurrency(_inv.rentAmount.round()),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Điện/nước chưa chốt — sẽ thu sau khi đọc đồng hồ',
                                style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                    // ── utilityOnly mode ──
                    else if (_mode == PaymentMode.utilityOnly) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Tiền nhà đã thu'
                                '${_inv.rentPaidAt != null ? ' ngày ${_dateFmt.format(_inv.rentPaidAt!)}' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _breakdownRow(
                        Icons.bolt,
                        'Tiền điện (${_inv.electricityUsage.round()} kWh)',
                        formatCurrency(_inv.electricityAmount.round()),
                        iconColor: Colors.orange,
                      ),
                      const SizedBox(height: 6),
                      _breakdownRow(
                        Icons.water_drop,
                        'Tiền nước (${_inv.waterUsage.round()} m³)',
                        formatCurrency(_inv.waterAmount.round()),
                        iconColor: Colors.blue,
                      ),
                      if (_inv.otherFees > 0) ...[
                        const SizedBox(height: 6),
                        _breakdownRow(
                          Icons.attach_file,
                          'Phí khác${_inv.otherFeesNote != null ? ' (${_inv.otherFeesNote})' : ''}',
                          formatCurrency(_inv.otherFees.round()),
                        ),
                      ],
                    ]
                    // ── full mode ──
                    else ...[
                      _breakdownRow(
                        Icons.home_outlined,
                        'Tiền nhà',
                        formatCurrency(_inv.rentAmount.round()),
                      ),
                      if (!_inv.hasPendingMeterReading) ...[
                        const SizedBox(height: 6),
                        _breakdownRow(
                          Icons.bolt,
                          'Tiền điện (${_inv.electricityUsage.round()} kWh)',
                          formatCurrency(_inv.electricityAmount.round()),
                          iconColor: Colors.orange,
                        ),
                        const SizedBox(height: 6),
                        _breakdownRow(
                          Icons.water_drop,
                          'Tiền nước (${_inv.waterUsage.round()} m³)',
                          formatCurrency(_inv.waterAmount.round()),
                          iconColor: Colors.blue,
                        ),
                      ],
                      if (_inv.otherFees > 0) ...[
                        const SizedBox(height: 6),
                        _breakdownRow(
                          Icons.attach_file,
                          'Phí khác${_inv.otherFeesNote != null ? ' (${_inv.otherFeesNote})' : ''}',
                          formatCurrency(_inv.otherFees.round()),
                        ),
                      ],
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _mode == PaymentMode.utilityOnly
                                ? 'TIỀN ĐIỆN + NƯỚC'
                                : _mode == PaymentMode.rentOnly
                                    ? 'TIỀN NHÀ'
                                    : 'TỔNG THANH TOÁN',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            formatCurrency(_collectAmount.round()),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Payment date ──────────────────────────────────
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ngày thu',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Text(
                            _dateFmt.format(_paidAt),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Notes ─────────────────────────────────────────
              TextField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: 'Ghi chú (tuỳ chọn)',
                  hintText: 'VD: Đã chuyển khoản, tiền mặt...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  prefixIcon: const Icon(Icons.notes, size: 18),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 20),

              // ── Buttons ───────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _confirm,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(_isSubmitting ? 'Đang xử lý...' : _confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakdownRow(IconData icon, String label, String value, {Color? iconColor}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor ?? AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
