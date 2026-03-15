import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/thousands_separator_formatter.dart';
import '../../../data/models/tenant.dart';
import '../../../providers/rental_provider.dart';

/// Dialog for creating/editing a tenant
class TenantFormDialog extends StatefulWidget {
  final Tenant? tenant;
  final VoidCallback? onSaved;

  const TenantFormDialog({super.key, this.tenant, this.onSaved});

  @override
  State<TenantFormDialog> createState() => _TenantFormDialogState();
}

class _TenantFormDialogState extends State<TenantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _roomCtrl;
  late final TextEditingController _rentCtrl;
  late final TextEditingController _electricityRateCtrl;
  late final TextEditingController _waterRateCtrl;
  late final TextEditingController _depositAmountCtrl;
  late final TextEditingController _notesCtrl;
  bool _isDepositPaid = false;
  bool _isSaving = false;

  bool get isEditing => widget.tenant != null;

  @override
  void initState() {
    super.initState();
    final t = widget.tenant;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _phoneCtrl = TextEditingController(text: t?.phone ?? '');
    _roomCtrl = TextEditingController(text: t?.roomNumber ?? '');
    _rentCtrl = TextEditingController(text: t != null ? formatNumber(t.rentAmount.round()) : '');
    _electricityRateCtrl = TextEditingController(text: t != null ? formatNumber(t.electricityRate.round()) : '3.500');
    _waterRateCtrl = TextEditingController(text: t != null ? formatNumber(t.waterRate.round()) : '4.000');
    _depositAmountCtrl = TextEditingController(text: t != null && t.depositAmount > 0 ? formatNumber(t.depositAmount.round()) : '');
    _isDepositPaid = t?.isDepositPaid ?? false;
    _notesCtrl = TextEditingController(text: t?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _roomCtrl.dispose();
    _rentCtrl.dispose();
    _electricityRateCtrl.dispose();
    _waterRateCtrl.dispose();
    _depositAmountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Sửa khách thuê' : 'Thêm khách thuê'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _roomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Số phòng *',
                    hintText: 'VD: P01, A1...',
                    prefixIcon: Icon(Icons.meeting_room),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Nhập số phòng' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên khách thuê *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Nhập tên' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tiền nhà (đ/tháng) *',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
                  validator: (v) {
                    final raw = v?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
                    if (raw.isEmpty) return 'Nhập tiền nhà';
                    if (double.tryParse(raw) == null) return 'Số không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _electricityRateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Giá điện (đ/kWh) *',
                    prefixIcon: Icon(Icons.bolt),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
                  validator: (v) {
                    final raw = v?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
                    if (raw.isEmpty) return 'Nhập giá điện';
                    if (double.tryParse(raw) == null) return 'Số không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _waterRateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Giá nước (đ/m³) *',
                    prefixIcon: Icon(Icons.water_drop),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
                  validator: (v) {
                    final raw = v?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
                    if (raw.isEmpty) return 'Nhập giá nước';
                    if (double.tryParse(raw) == null) return 'Số không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _depositAmountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tiền cọc (đ)',
                    prefixIcon: Icon(Icons.savings),
                    hintText: '0 nếu không có',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  value: _isDepositPaid,
                  onChanged: (v) => setState(() => _isDepositPaid = v),
                  title: const Text('Trạng thái tiền cọc'),
                  subtitle: Text(
                    _isDepositPaid ? 'Đã thu tiền cọc' : 'Chưa thu tiền cọc',
                    style: TextStyle(
                      color: _isDepositPaid ? Colors.green.shade700 : Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  secondary: Icon(
                    _isDepositPaid ? Icons.check_circle : Icons.pending,
                    color: _isDepositPaid ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEditing ? 'Lưu' : 'Thêm'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = context.read<RentalProvider>();

    bool success;
    if (isEditing) {
      final updated = widget.tenant!.copyWith(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        roomNumber: _roomCtrl.text.trim(),
        rentAmount: double.parse(_rentCtrl.text.replaceAll(RegExp(r'[^\d]'), '')),
        electricityRate: double.parse(_electricityRateCtrl.text.replaceAll(RegExp(r'[^\d]'), '')),
        waterRate: double.parse(_waterRateCtrl.text.replaceAll(RegExp(r'[^\d]'), '')),
        depositAmount: double.tryParse(_depositAmountCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0,
        isDepositPaid: _isDepositPaid,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );
      success = await provider.updateTenant(updated);
    } else {
      final tenant = await provider.createTenant(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        roomNumber: _roomCtrl.text.trim(),
        rentAmount: double.parse(_rentCtrl.text.replaceAll(RegExp(r'[^\d]'), '')),
        electricityRate: double.parse(_electricityRateCtrl.text.replaceAll(RegExp(r'[^\d]'), '')),
        waterRate: double.parse(_waterRateCtrl.text.replaceAll(RegExp(r'[^\d]'), '')),
        depositAmount: double.tryParse(_depositAmountCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0,
        isDepositPaid: _isDepositPaid,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );
      success = tenant != null;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Đã cập nhật' : 'Đã thêm khách thuê'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Có lỗi xảy ra'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
