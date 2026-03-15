import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/thousands_separator_formatter.dart';
import '../../../data/models/rental_invoice.dart';
import '../../../data/models/tenant.dart';
import '../../../providers/rental_provider.dart';

/// Per-month electricity/water readings (used when creating multiple months at once)
class _MonthEntry {
  final int month;
  final int year;
  final TextEditingController elecOldCtrl;
  final TextEditingController elecNewCtrl;
  final TextEditingController waterOldCtrl;
  final TextEditingController waterNewCtrl;

  /// True when this month's new readings were auto-filled (not entered by user yet).
  final bool isPendingMeter;

  _MonthEntry({
    required this.month,
    required this.year,
    String elecOld = '',
    String elecNew = '',
    String waterOld = '',
    String waterNew = '',
    this.isPendingMeter = false,
  }) : elecOldCtrl = TextEditingController(text: elecOld),
       elecNewCtrl = TextEditingController(text: elecNew),
       waterOldCtrl = TextEditingController(text: waterOld),
       waterNewCtrl = TextEditingController(text: waterNew);

  double get elecOld => double.tryParse(elecOldCtrl.text) ?? 0;
  double get elecNew => double.tryParse(elecNewCtrl.text) ?? 0;
  double get waterOld => double.tryParse(waterOldCtrl.text) ?? 0;
  double get waterNew => double.tryParse(waterNewCtrl.text) ?? 0;

  void dispose() {
    elecOldCtrl.dispose();
    elecNewCtrl.dispose();
    waterOldCtrl.dispose();
    waterNewCtrl.dispose();
  }
}

/// Dialog for creating/editing a rental invoice
class InvoiceFormDialog extends StatefulWidget {
  final Tenant tenant;
  final RentalInvoice? invoice;
  final VoidCallback onSaved;

  const InvoiceFormDialog({
    super.key,
    required this.tenant,
    this.invoice,
    required this.onSaved,
  });

  @override
  State<InvoiceFormDialog> createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends State<InvoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isSaving = false;
  int _monthsCount = 1; // for advance multi-month creation (create-only)

  bool get _multiMonth => !_isEditing && _monthsCount > 1;

  late int _month;
  late int _year;

  late TextEditingController _rentAmountCtrl;
  late TextEditingController _electricityOldCtrl;
  late TextEditingController _electricityNewCtrl;
  late TextEditingController _electricityRateCtrl;
  late TextEditingController _waterOldCtrl;
  late TextEditingController _waterNewCtrl;
  late TextEditingController _waterRateCtrl;
  late TextEditingController _otherFeesCtrl;
  late TextEditingController _otherFeesNoteCtrl;
  late TextEditingController _notesCtrl;

  // Computed totals
  double _electricityAmount = 0;
  double _waterAmount = 0;
  double _totalAmount = 0;

  // Per-month entries for multi-month mode
  List<_MonthEntry> _monthEntries = [];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.invoice != null;

    final inv = widget.invoice;
    final now = DateTime.now();

    _month = inv?.month ?? now.month;
    _year = inv?.year ?? now.year;

    _rentAmountCtrl = TextEditingController(
      text: formatNumber((inv?.rentAmount ?? widget.tenant.rentAmount).round()),
    );
    _electricityRateCtrl = TextEditingController(
      text: formatNumber(
        (inv?.electricityRate ?? widget.tenant.electricityRate).round(),
      ),
    );
    _waterRateCtrl = TextEditingController(
      text: formatNumber((inv?.waterRate ?? widget.tenant.waterRate).round()),
    );

    if (_isEditing) {
      _electricityOldCtrl = TextEditingController(
        text: inv!.electricityOld.toStringAsFixed(0),
      );
      _waterOldCtrl = TextEditingController(
        text: inv.waterOld.toStringAsFixed(0),
      );
      _otherFeesCtrl = TextEditingController(
        text: inv.otherFees > 0 ? formatNumber(inv.otherFees.round()) : '',
      );
      _otherFeesNoteCtrl = TextEditingController(text: inv.otherFeesNote ?? '');
      _notesCtrl = TextEditingController(text: inv.notes ?? '');
      if (inv.isPendingMeter) {
        // Advance invoice: new readings not entered yet.
        // Trường hợp có số mới thực sự (elecNew != elecOld và != 0) do data cũ
        // bị lưu nhầm isPendingMeter=true → vẫn hiển thị số đã có.
        final hasRealElecNew =
            inv.electricityNew > 0 && inv.electricityNew != inv.electricityOld;
        final hasRealWaterNew =
            inv.waterNew > 0 && inv.waterNew != inv.waterOld;
        _electricityNewCtrl = TextEditingController(
          text: hasRealElecNew ? inv.electricityNew.toStringAsFixed(0) : '',
        );
        _waterNewCtrl = TextEditingController(
          text: hasRealWaterNew ? inv.waterNew.toStringAsFixed(0) : '',
        );
        _prefillEditFromPrevMonth();
      } else {
        _electricityNewCtrl = TextEditingController(
          text: inv.electricityNew.toStringAsFixed(0),
        );
        _waterNewCtrl = TextEditingController(
          text: inv.waterNew.toStringAsFixed(0),
        );
        // Legacy pending check (all-zero readings from before isPendingMeter existed)
        if (inv.hasPendingMeterReading) _prefillEditFromPrevMonth();
      }
    } else {
      _electricityOldCtrl = TextEditingController();
      _electricityNewCtrl = TextEditingController();
      _waterOldCtrl = TextEditingController();
      _waterNewCtrl = TextEditingController();
      _otherFeesCtrl = TextEditingController();
      _otherFeesNoteCtrl = TextEditingController();
      _notesCtrl = TextEditingController();

      // Pre-fill old readings from latest invoice
      _prefillFromLatestInvoice();
    }

    _recalculate();
  }

  /// Pre-fill old readings when creating a new invoice.
  /// Looks for the directly preceding month only (no gaps).
  /// - Nếu tháng trước đã chốt số: lấy electricityNew (số mới thực tế)
  /// - Nếu tháng trước chưa chốt (advance): lấy electricityOld (số được chép từ tháng trước nữa)
  Future<void> _prefillFromLatestInvoice() async {
    final provider = context.read<RentalProvider>();
    int prevMonth = _month - 1;
    int prevYear = _year;
    if (prevMonth < 1) {
      prevMonth = 12;
      prevYear--;
    }
    final prev = await provider.getInvoiceForMonth(
      widget.tenant.id,
      prevMonth,
      prevYear,
    );
    if (prev != null && mounted) {
      setState(() {
        // Pending: electricityNew là placeholder (= old), dùng electricityOld.
        // Đã chốt: dùng electricityNew (số thực).
        final eVal = prev.hasPendingMeterReading
            ? prev.electricityOld
            : prev.electricityNew;
        final wVal = prev.hasPendingMeterReading
            ? prev.waterOld
            : prev.waterNew;
        if (eVal > 0) _electricityOldCtrl.text = eVal.toStringAsFixed(0);
        if (wVal > 0) _waterOldCtrl.text = wVal.toStringAsFixed(0);
        _recalculate();
      });
    }
  }

  /// When editing a pending invoice (0→0 readings), prefill old reading from
  /// the previous month's invoice's new reading — but only if that invoice
  /// itself has actual readings (not also pending).
  Future<void> _prefillEditFromPrevMonth() async {
    final provider = context.read<RentalProvider>();
    int prevMonth = _month - 1;
    int prevYear = _year;
    if (prevMonth < 1) {
      prevMonth = 12;
      prevYear--;
    }
    final prev = await provider.getInvoiceForMonth(
      widget.tenant.id,
      prevMonth,
      prevYear,
    );
    if (prev != null && mounted) {
      setState(() {
        final eVal = prev.hasPendingMeterReading
            ? prev.electricityOld
            : prev.electricityNew;
        final wVal = prev.hasPendingMeterReading
            ? prev.waterOld
            : prev.waterNew;
        if (eVal > 0) _electricityOldCtrl.text = eVal.toStringAsFixed(0);
        if (wVal > 0) _waterOldCtrl.text = wVal.toStringAsFixed(0);
        _recalculate();
      });
    }
  }

  @override
  void dispose() {
    _rentAmountCtrl.dispose();
    _electricityOldCtrl.dispose();
    _electricityNewCtrl.dispose();
    _electricityRateCtrl.dispose();
    _waterOldCtrl.dispose();
    _waterNewCtrl.dispose();
    _waterRateCtrl.dispose();
    _otherFeesCtrl.dispose();
    _otherFeesNoteCtrl.dispose();
    _notesCtrl.dispose();
    for (final e in _monthEntries) {
      e.dispose();
    }
    super.dispose();
  }

  /// Strip thousands separators to get raw number string
  String _strip(String text) => text.replaceAll(RegExp(r'[^\d]'), '');

  void _recalculate() {
    final rent = double.tryParse(_strip(_rentAmountCtrl.text)) ?? 0;
    final other = double.tryParse(_strip(_otherFeesCtrl.text)) ?? 0;
    final eRate = double.tryParse(_strip(_electricityRateCtrl.text)) ?? 0;
    final wRate = double.tryParse(_strip(_waterRateCtrl.text)) ?? 0;

    if (_multiMonth && _monthEntries.isNotEmpty) {
      double totalElec = 0, totalWater = 0;
      for (final e in _monthEntries) {
        totalElec += (e.elecNew - e.elecOld).clamp(0, double.infinity) * eRate;
        totalWater +=
            (e.waterNew - e.waterOld).clamp(0, double.infinity) * wRate;
      }
      setState(() {
        _electricityAmount = totalElec;
        _waterAmount = totalWater;
        _totalAmount = rent * _monthsCount + totalElec + totalWater + other;
      });
    } else {
      final eOld = double.tryParse(_electricityOldCtrl.text) ?? 0;
      final eNew = double.tryParse(_electricityNewCtrl.text) ?? 0;
      final wOld = double.tryParse(_waterOldCtrl.text) ?? 0;
      final wNew = double.tryParse(_waterNewCtrl.text) ?? 0;
      setState(() {
        _electricityAmount = (eNew - eOld) * eRate;
        _waterAmount = (wNew - wOld) * wRate;
        _totalAmount = rent + _electricityAmount + _waterAmount + other;
      });
    }
  }

  /// Rebuild per-month entries when count changes.
  /// Preserves existing values; auto-propagates elecNew/waterNew → next month's old reading.
  void _rebuildMonthEntries(int newCount) {
    final oldVals = _monthEntries
        .map(
          (e) => (
            elecOld: e.elecOldCtrl.text,
            elecNew: e.elecNewCtrl.text,
            waterOld: e.waterOldCtrl.text,
            waterNew: e.waterNewCtrl.text,
            isPendingMeter: e.isPendingMeter,
          ),
        )
        .toList();

    for (final e in _monthEntries) {
      e.dispose();
    }

    final newEntries = <_MonthEntry>[];
    int m = _month, y = _year;

    for (int i = 0; i < newCount; i++) {
      if (i < oldVals.length) {
        newEntries.add(
          _MonthEntry(
            month: m,
            year: y,
            elecOld: oldVals[i].elecOld,
            elecNew: oldVals[i].elecNew,
            waterOld: oldVals[i].waterOld,
            waterNew: oldVals[i].waterNew,
            isPendingMeter: oldVals[i].isPendingMeter,
          ),
        );
      } else {
        // Auto-fill OLD reading from previous month's new reading.
        // NEW reading is left EMPTY — user must fill it in when the meter is read.
        // Do NOT pre-fill new = old (placeholder) because that causes negative
        // usage when the user later enters a real new value for the previous month
        // and the cascade propagates old upward while new stays at the stale value.
        final prevElecNew = newEntries.isNotEmpty
            ? newEntries.last.elecNewCtrl.text
            : _electricityOldCtrl.text;
        final prevWaterNew = newEntries.isNotEmpty
            ? newEntries.last.waterNewCtrl.text
            : _waterOldCtrl.text;
        // For the seed old value: if prior month's new is empty (also pending),
        // fall back to prior month's old so we don't lose the chain.
        final seedElecOld = prevElecNew.trim().isNotEmpty
            ? prevElecNew
            : (newEntries.isNotEmpty ? newEntries.last.elecOldCtrl.text : _electricityOldCtrl.text);
        final seedWaterOld = prevWaterNew.trim().isNotEmpty
            ? prevWaterNew
            : (newEntries.isNotEmpty ? newEntries.last.waterOldCtrl.text : _waterOldCtrl.text);
        AppLogger.debug('[MultiMonth] Auto-create entry idx=$i m=$m/$y '
            'elecOld=$seedElecOld elecNew=(empty) '
            'waterOld=$seedWaterOld waterNew=(empty) isPendingMeter=true');
        newEntries.add(
          _MonthEntry(
            month: m,
            year: y,
            elecOld: seedElecOld,
            elecNew: '', // intentionally empty — pending until user fills in
            waterOld: seedWaterOld,
            waterNew: '', // intentionally empty — pending until user fills in
            isPendingMeter: true,
          ),
        );
      }
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }

    setState(() {
      _monthsCount = newCount;
      _monthEntries = newEntries;
    });
    _recalculate();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    _isEditing ? 'Sửa hóa đơn' : 'Tạo hóa đơn',
                    style: const TextStyle(
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
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // Month/Year selector
                      _buildSectionHeader(
                        _multiMonth ? 'Tháng bắt đầu' : 'Kỳ hóa đơn',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _month,
                              decoration: const InputDecoration(
                                labelText: 'Tháng',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: List.generate(12, (i) => i + 1)
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text('Tháng $m'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _month = v!;
                                  if (!_isEditing) {
                                    // Reset khi đổi tháng — prefill sẽ lấy lại từ tháng trước mới
                                    _electricityOldCtrl.clear();
                                    _waterOldCtrl.clear();
                                  }
                                });
                                if (_multiMonth)
                                  _rebuildMonthEntries(_monthsCount);
                                if (!_isEditing) _prefillFromLatestInvoice();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _year,
                              decoration: const InputDecoration(
                                labelText: 'Năm',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items:
                                  List.generate(
                                        5,
                                        (i) => DateTime.now().year - 1 + i,
                                      )
                                      .map(
                                        (y) => DropdownMenuItem(
                                          value: y,
                                          child: Text('$y'),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _year = v!;
                                  if (!_isEditing) {
                                    _electricityOldCtrl.clear();
                                    _waterOldCtrl.clear();
                                  }
                                });
                                if (_multiMonth)
                                  _rebuildMonthEntries(_monthsCount);
                                if (!_isEditing) _prefillFromLatestInvoice();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Multi-month stepper (create only)
                      if (!_isEditing) ...[
                        _buildSectionHeader('📅 Số tháng thanh toán'),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: _monthsCount > 1
                                  ? () => _rebuildMonthEntries(_monthsCount - 1)
                                  : null,
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '$_monthsCount tháng',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: _monthsCount < 12
                                  ? () => _rebuildMonthEntries(_monthsCount + 1)
                                  : null,
                            ),
                          ],
                        ),
                        if (_multiMonth)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tiền điện & nước nhập chỉ số riêng từng tháng bên dưới.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],

                      // Rent + shared rates
                      _buildSectionHeader('🏠 Tiền nhà'),
                      _buildNumberField(
                        controller: _rentAmountCtrl,
                        label: 'Tiền nhà',
                        suffix: '₫',
                        isCurrency: true,
                        onChanged: () => _recalculate(),
                      ),
                      const SizedBox(height: 16),

                      // Shared rates (always shown)
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              controller: _electricityRateCtrl,
                              label: 'Đơn giá điện',
                              suffix: '₫/kWh',
                              isCurrency: true,
                              onChanged: () => _recalculate(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNumberField(
                              controller: _waterRateCtrl,
                              label: 'Đơn giá nước',
                              suffix: '₫/m³',
                              isCurrency: true,
                              onChanged: () => _recalculate(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Multi-month: per-month cards with readings
                      if (_multiMonth) ...[
                        _buildSectionHeader('⚡💧 Chỉ số điện nước từng tháng'),
                        ..._monthEntries.asMap().entries.map(
                          (entry) =>
                              _buildMonthEntryCard(entry.key, entry.value),
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        // Single-month electricity
                        _buildSectionHeader('⚡ Tiền điện'),
                        Row(
                          children: [
                            Expanded(
                              child: _buildNumberField(
                                controller: _electricityOldCtrl,
                                label: 'Chỉ số cũ',
                                suffix: 'kWh',
                                required: false,
                                onChanged: () => _recalculate(),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.arrow_forward, size: 16),
                            ),
                            Expanded(
                              child: _buildNumberField(
                                controller: _electricityNewCtrl,
                                label: 'Chỉ số mới',
                                suffix: 'kWh',
                                required: false,
                                onChanged: () => _recalculate(),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return null; // trống = chưa chốt
                                  final nv = double.tryParse(v) ?? 0;
                                  final ov = double.tryParse(_electricityOldCtrl.text) ?? 0;
                                  if (nv < ov) return 'Phải ≥ cũ';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // elec rate is already shown above
                        if (_electricityAmount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Text(
                              '= ${formatCurrency(_electricityAmount.round())}',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),

                        // Single-month water
                        _buildSectionHeader('💧 Tiền nước'),
                        Row(
                          children: [
                            Expanded(
                              child: _buildNumberField(
                                controller: _waterOldCtrl,
                                label: 'Chỉ số cũ',
                                suffix: 'm³',
                                required: false,
                                onChanged: () => _recalculate(),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.arrow_forward, size: 16),
                            ),
                            Expanded(
                              child: _buildNumberField(
                                controller: _waterNewCtrl,
                                label: 'Chỉ số mới',
                                suffix: 'm³',
                                required: false,
                                onChanged: () => _recalculate(),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return null; // trống = chưa chốt
                                  final nv = double.tryParse(v) ?? 0;
                                  final ov = double.tryParse(_waterOldCtrl.text) ?? 0;
                                  if (nv < ov) return 'Phải ≥ cũ';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        if (_waterAmount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '= ${formatCurrency(_waterAmount.round())}',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],

                      // Other fees
                      _buildSectionHeader('📎 Phí khác (nếu có)'),
                      _buildNumberField(
                        controller: _otherFeesCtrl,
                        label: 'Phí khác',
                        suffix: '₫',
                        required: false,
                        isCurrency: true,
                        onChanged: () => _recalculate(),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _otherFeesNoteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú phí khác',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        controller: _notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú chung',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Total
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'TỔNG CỘNG',
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              formatCurrency(_totalAmount.round()),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEditing ? 'Cập nhật' : 'Tạo hóa đơn'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    String? suffix,
    bool required = true,
    bool isCurrency = false,
    VoidCallback? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: isCurrency
          ? [
              FilteringTextInputFormatter.digitsOnly,
              ThousandsSeparatorInputFormatter(),
            ]
          : [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator:
          validator ??
          (v) {
            if (required && (v == null || v.isEmpty)) return 'Bắt buộc';
            return null;
          },
      onChanged: (_) => onChanged?.call(),
    );
  }

  /// Card displaying one month's electricity + water input fields.
  Widget _buildMonthEntryCard(int index, _MonthEntry e) {
    final eRate = double.tryParse(_strip(_electricityRateCtrl.text)) ?? 0;
    final wRate = double.tryParse(_strip(_waterRateCtrl.text)) ?? 0;
    final rent = double.tryParse(_strip(_rentAmountCtrl.text)) ?? 0;
    final eAmt = (e.elecNew - e.elecOld).clamp(0, double.infinity) * eRate;
    final wAmt = (e.waterNew - e.waterOld).clamp(0, double.infinity) * wRate;
    final monthTotal = rent + eAmt + wAmt;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: month label + subtotal
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tháng ${e.month}/${e.year}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (e.isPendingMeter ||
                          e.elecNewCtrl.text.trim().isEmpty ||
                          e.waterNewCtrl.text.trim().isEmpty ||
                          (e.elecOld == e.elecNew &&
                              e.waterOld == e.waterNew)) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '⚡ Chưa chốt',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          formatCurrency(monthTotal.round()),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Electricity row
            Row(
              children: [
                const Icon(Icons.bolt, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                const SizedBox(
                  width: 36,
                  child: Text('Điện', style: TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: _buildSmallNumberField(
                    controller: e.elecOldCtrl,
                    label: 'Cũ (kWh)',
                    onChanged: () {
                      setState(() {});
                      _recalculate();
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('→', style: TextStyle(fontSize: 14)),
                ),
                Expanded(
                  child: _buildSmallNumberField(
                    controller: e.elecNewCtrl,
                    label: 'Mới (kWh)',
                    onChanged: () {
                      // Propagate to next month's OLD reading only.
                      // Next month's NEW stays empty (pending) — do NOT copy new→new
                      // because that would create stale placeholder data causing
                      // negative usage if user then edits the current month's new again.
                      if (index + 1 < _monthEntries.length) {
                        _monthEntries[index + 1].elecOldCtrl.text =
                            e.elecNewCtrl.text;
                        AppLogger.debug('[MultiMonth] Propagate elec: '
                            'month[$index].new=${e.elecNewCtrl.text} '
                            '→ month[${index+1}].old');
                      }
                      setState(() {});
                      _recalculate();
                    },
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // trống = chưa chốt, cho phép
                      final nv = double.tryParse(v) ?? 0;
                      if (nv < e.elecOld) return '≥ cũ';
                      return null;
                    },
                  ),
                ),
                if (eAmt > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    formatCurrency(eAmt.round()),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Water row
            Row(
              children: [
                const Icon(Icons.water_drop, size: 14, color: Colors.blue),
                const SizedBox(width: 4),
                const SizedBox(
                  width: 36,
                  child: Text('Nước', style: TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: _buildSmallNumberField(
                    controller: e.waterOldCtrl,
                    label: 'Cũ (m³)',
                    onChanged: () {
                      setState(() {});
                      _recalculate();
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('→', style: TextStyle(fontSize: 14)),
                ),
                Expanded(
                  child: _buildSmallNumberField(
                    controller: e.waterNewCtrl,
                    label: 'Mới (m³)',
                    onChanged: () {
                      if (index + 1 < _monthEntries.length) {
                        _monthEntries[index + 1].waterOldCtrl.text =
                            e.waterNewCtrl.text;
                        AppLogger.debug('[MultiMonth] Propagate water: '
                            'month[$index].new=${e.waterNewCtrl.text} '
                            '→ month[${index+1}].old');
                      }
                      setState(() {});
                      _recalculate();
                    },
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // trống = chưa chốt, cho phép
                      final nv = double.tryParse(v) ?? 0;
                      if (nv < e.waterOld) return '≥ cũ';
                      return null;
                    },
                  ),
                ),
                if (wAmt > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    formatCurrency(wAmt.round()),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Compact number field used inside per-month cards.
  Widget _buildSmallNumberField({
    required TextEditingController controller,
    required String label,
    VoidCallback? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      style: const TextStyle(fontSize: 13),
      validator:
          validator ??
          (v) => null, // readings are optional; empty → treated as 0
      onChanged: (_) => onChanged?.call(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<RentalProvider>();

    final rentAmount = double.tryParse(_strip(_rentAmountCtrl.text)) ?? 0;
    final electricityOld = double.tryParse(_electricityOldCtrl.text) ?? 0;
    final electricityNew = double.tryParse(_electricityNewCtrl.text) ?? 0;
    final electricityRate =
        double.tryParse(_strip(_electricityRateCtrl.text)) ?? 0;
    final waterOld = double.tryParse(_waterOldCtrl.text) ?? 0;
    final waterNew = double.tryParse(_waterNewCtrl.text) ?? 0;
    final waterRate = double.tryParse(_strip(_waterRateCtrl.text)) ?? 0;
    final otherFees = double.tryParse(_strip(_otherFeesCtrl.text)) ?? 0;

    bool success;
    String? errorMsg;

    if (_isEditing) {
      final isStillPending =
          _electricityNewCtrl.text.trim().isEmpty ||
          _waterNewCtrl.text.trim().isEmpty;
      final electricityAmount =
          (electricityNew - electricityOld).clamp(0, double.infinity) *
          electricityRate;
      final waterAmount =
          (waterNew - waterOld).clamp(0, double.infinity) * waterRate;
      final totalAmount =
          rentAmount + electricityAmount + waterAmount + otherFees;

      final updated = widget.invoice!.copyWith(
        month: _month,
        year: _year,
        rentAmount: rentAmount,
        electricityOld: electricityOld,
        electricityNew: electricityNew,
        electricityRate: electricityRate,
        electricityAmount: electricityAmount,
        waterOld: waterOld,
        waterNew: waterNew,
        waterRate: waterRate,
        waterAmount: waterAmount,
        otherFees: otherFees,
        otherFeesNote: _otherFeesNoteCtrl.text.trim().isEmpty
            ? null
            : _otherFeesNoteCtrl.text.trim(),
        totalAmount: totalAmount,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        isPendingMeter: isStillPending,
      );

      success = await provider.updateInvoice(updated);
    } else if (_monthsCount > 1) {
      // Multi-month: each month has its own electricity/water readings
      final eRate = double.tryParse(_strip(_electricityRateCtrl.text)) ?? 0;
      final wRate = double.tryParse(_strip(_waterRateCtrl.text)) ?? 0;
      final otherFeesNote = _otherFeesNoteCtrl.text.trim().isEmpty
          ? null
          : _otherFeesNoteCtrl.text.trim();
      final notes = _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim();

      final invoices = _monthEntries.asMap().entries.map((entry) {
        final i = entry.key;
        final me = entry.value;
        final fees = i == 0 ? otherFees : 0.0;
        // Multi-month batch: ALWAYS created as pending (isPendingMeter=true),
        // regardless of whether the user filled in readings for the first month.
        // This ensures every batch invoice starts in 'unpaidPending' state so
        // the user must explicitly confirm via 'Sửa hóa đơn' / 'Nhập điện/nước'
        // before it becomes actionable for payment collection.
        // Readings entered for month 1 ARE stored in the DB and will be
        // pre-filled when the user opens the edit form to confirm.
        const isPending = true;
        AppLogger.debug('[MultiMonth] Save entry[$i] '
            'm=${me.month}/${me.year} '
            'elecOld=${me.elecOld} elecNew=${me.elecNew} (raw="${me.elecNewCtrl.text}") '
            'waterOld=${me.waterOld} waterNew=${me.waterNew} (raw="${me.waterNewCtrl.text}") '
            'isPending=$isPending');
        return RentalInvoice.create(
          tenantId: widget.tenant.id,
          month: me.month,
          year: me.year,
          rentAmount: rentAmount,
          electricityOld: me.elecOld,
          electricityNew: me.elecNew,
          electricityRate: eRate,
          waterOld: me.waterOld,
          waterNew: me.waterNew,
          waterRate: wRate,
          otherFees: fees,
          otherFeesNote: i == 0 ? otherFeesNote : null,
          notes: notes,
          isPendingMeter: isPending,
        );
      }).toList();

      final inserted = await provider.createInvoiceBatch(invoices);
      success = inserted > 0;
      if (!success) {
        errorMsg = provider.error ?? 'Tất cả tháng đã có hóa đơn';
      } else if (inserted < _monthsCount) {
        if (mounted) {
          setState(() => _isSaving = false);
          Navigator.pop(context);
          widget.onSaved();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã tạo $inserted/$_monthsCount hóa đơn (một số tháng đã tồn tại)',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    } else {
      final result = await provider.createInvoice(
        tenantId: widget.tenant.id,
        month: _month,
        year: _year,
        rentAmount: rentAmount,
        electricityOld: electricityOld,
        electricityNew: electricityNew,
        electricityRate: electricityRate,
        waterOld: waterOld,
        waterNew: waterNew,
        waterRate: waterRate,
        otherFees: otherFees,
        otherFeesNote: _otherFeesNoteCtrl.text.trim().isEmpty
            ? null
            : _otherFeesNoteCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        isPendingMeter:
            _electricityNewCtrl.text.trim().isEmpty ||
            _waterNewCtrl.text.trim().isEmpty,
      );
      success = result != null;
      if (!success) errorMsg = provider.error;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Đã cập nhật hóa đơn'
                  : _monthsCount > 1
                  ? 'Đã tạo $_monthsCount hóa đơn'
                  : 'Đã tạo hóa đơn',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg ?? 'Có lỗi xảy ra'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
