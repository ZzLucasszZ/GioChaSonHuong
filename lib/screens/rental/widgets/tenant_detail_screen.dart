import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/tenant.dart';
import '../../../data/models/rental_invoice.dart';
import '../../../providers/rental_provider.dart';
import '../../shared/share_preview_dialog.dart';
import 'invoice_form_dialog.dart';
import 'payment_dialog.dart';
import 'tenant_form_dialog.dart';

/// Tenant detail screen showing tenant info + invoice list
class TenantDetailScreen extends StatefulWidget {
  final Tenant tenant;

  const TenantDetailScreen({super.key, required this.tenant});

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  late Tenant _tenant;
  List<RentalInvoice> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tenant = widget.tenant;
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    final provider = context.read<RentalProvider>();
    _invoices = await provider.loadInvoicesForTenant(_tenant.id);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refreshTenant() async {
    final provider = context.read<RentalProvider>();
    await provider.loadTenants();
    final updated = provider.getTenantById(_tenant.id);
    if (updated != null && mounted) {
      setState(() => _tenant = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Phòng ${_tenant.roomNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _invoices.isEmpty ? null : _showShareOptions,
            tooltip: 'Chia sẻ hóa đơn',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => TenantFormDialog(
                  tenant: _tenant,
                  onSaved: () async {
                    await _refreshTenant();
                    await _loadInvoices();
                  },
                ),
              );
            },
            tooltip: 'Sửa thông tin',
          ),
        ],
      ),
      body: Column(
        children: [
          // Tenant info card
          _buildTenantInfoCard(),

          // Invoices header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Hóa đơn',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_invoices.length} hóa đơn',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Invoices list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _invoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text(
                              'Chưa có hóa đơn',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInvoices,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                          itemCount: _invoices.length,
                          itemBuilder: (context, index) {
                            return _buildInvoiceCard(_invoices[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_tenant_detail_invoice',
        onPressed: () => _showInvoiceForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tạo hóa đơn'),
      ),
    );
  }

  Widget _buildTenantInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tenant.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (_tenant.phone != null && _tenant.phone!.isNotEmpty)
                        Text(
                          _tenant.phone!,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Tiền nhà:', formatCurrency(_tenant.rentAmount.round())),
            _buildInfoRow('Giá điện:', '${formatCurrency(_tenant.electricityRate.round())}/kWh'),
            _buildInfoRow('Giá nước:', '${formatCurrency(_tenant.waterRate.round())}/m³'),
            if (_tenant.depositAmount > 0) ...[
              _buildInfoRow('Tiền cọc:', formatCurrency(_tenant.depositAmount.round()),
                  color: Colors.green.shade700),
              _buildInfoRow(
                'Trạng thái cọc:',
                _tenant.isDepositPaid ? 'Đã thu' : 'Chưa thu',
                color: _tenant.isDepositPaid ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ],
            if (_tenant.notes != null && _tenant.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _tenant.notes!,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(RentalInvoice invoice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showInvoiceDetail(invoice),
        onLongPress: () => _showInvoiceActions(invoice),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Month badge
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _badgeColor(invoice.paymentStatus).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'T${invoice.month}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _badgeColor(invoice.paymentStatus),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${invoice.year}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _badgeColor(invoice.paymentStatus),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: _buildCardDetails(invoice),
              ),
              // Status column (right side)
              _buildPaymentColumn(invoice),
            ],
          ),
        ),
      ),
    );
  }

  /// Middle column of the invoice card — shows amount + payment status breakdown.
  Widget _buildCardDetails(RentalInvoice invoice) {
    final status = invoice.paymentStatus;
    final dateFmt = DateFormat('dd/MM/yy');

    Widget chip(String label, Color color, IconData icon) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );

    // ── rentPaidPending / rentPaidDue: show split status ──
    if (status == RentalPaymentStatus.rentPaidPending ||
        status == RentalPaymentStatus.rentPaidDue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatCurrency(invoice.rentAmount.round()),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          // Rent paid chip
          chip(
            '🏠 Nhà đã thu'
            '${invoice.rentPaidAt != null ? '  ${dateFmt.format(invoice.rentPaidAt!)}' : ''}',
            AppColors.success,
            Icons.check_circle,
          ),
          const SizedBox(height: 3),
          // Utility chip
          if (status == RentalPaymentStatus.rentPaidPending)
            chip('⚡ Điện/nước chưa chốt số', Colors.orange, Icons.electric_meter)
          else
            chip(
              '⚡ Điện/nước chưa thu  ${formatCurrency(
                (invoice.electricityAmount + invoice.waterAmount + invoice.otherFees).round()
              )}',
              Colors.orange,
              Icons.payments_outlined,
            ),
        ],
      );
    }

    // ── fullyPaid ──
    if (status == RentalPaymentStatus.fullyPaid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatCurrency(invoice.totalAmount.round()),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          if (!invoice.hasPendingMeterReading)
            Text(
              'Điện: ${invoice.electricityUsage.round()} kWh | Nước: ${invoice.waterUsage.round()} m³',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
        ],
      );
    }

    // ── unpaid / unpaidPending (default) ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          invoice.hasPendingMeterReading
              ? formatCurrency(invoice.rentAmount.round())
              : formatCurrency(invoice.totalAmount.round()),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        if (!invoice.hasPendingMeterReading)
          Text(
            'Điện: ${invoice.electricityUsage.round()} kWh | Nước: ${invoice.waterUsage.round()} m³',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          )
        else
          chip('⚡ Điện/nước chưa chốt số', Colors.orange, Icons.electric_meter),
      ],
    );
  }

  Color _badgeColor(RentalPaymentStatus status) {
    switch (status) {
      case RentalPaymentStatus.fullyPaid:
        return AppColors.success;
      case RentalPaymentStatus.rentPaidPending:
      case RentalPaymentStatus.rentPaidDue:
        return Colors.orange;
      case RentalPaymentStatus.unpaidPending:
      case RentalPaymentStatus.unpaid:
        return AppColors.error;
    }
  }

  /// Builds the right-hand payment column of an invoice card based on its 5-state status.
  Widget _buildPaymentColumn(RentalInvoice invoice) {
    final status = invoice.paymentStatus;

    Widget shareBtn() => InkWell(
          onTap: () => _shareInvoice(invoice),
          child: Icon(Icons.share, size: 18, color: AppColors.primary),
        );

    Widget badge(String label, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        );

    Widget actionBtn(String label, Color color, VoidCallback onTap) =>
        FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          child: Text(label),
        );

    switch (status) {
      case RentalPaymentStatus.fullyPaid:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            badge('Đã trả', AppColors.success),
            if (invoice.paidAt != null) ...[
              const SizedBox(height: 2),
              Text(
                DateFormat('dd/MM/yy').format(invoice.paidAt!),
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 4),
            shareBtn(),
          ],
        );

      case RentalPaymentStatus.rentPaidPending:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            badge('Đã thu tiền nhà', Colors.orange),
            const SizedBox(height: 4),
            actionBtn('Nhập điện/nước', Colors.orange, () => _openMeterEditor(invoice)),
            const SizedBox(height: 4),
            shareBtn(),
          ],
        );

      case RentalPaymentStatus.rentPaidDue:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            actionBtn('Thu điện nước', Colors.orange, () => _showPaymentDialog(invoice)),
            const SizedBox(height: 6),
            shareBtn(),
          ],
        );

      case RentalPaymentStatus.unpaidPending:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            actionBtn('Thu tiền nhà', AppColors.success, () => _showPaymentDialog(invoice)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _openMeterEditor(invoice),
              child: Text(
                'Nhập điện/nước',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.orange.shade700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            shareBtn(),
          ],
        );

      case RentalPaymentStatus.unpaid:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            actionBtn('Thu tiền', AppColors.success, () => _showPaymentDialog(invoice)),
            const SizedBox(height: 6),
            shareBtn(),
          ],
        );
    }
  }

  /// Opens InvoiceFormDialog pre-focused on meter readings.
  void _openMeterEditor(RentalInvoice invoice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InvoiceFormDialog(
        tenant: _tenant,
        invoice: invoice,
        onSaved: _loadInvoices,
      ),
    );
  }

  void _showPaymentDialog(RentalInvoice invoice) {
    final status = invoice.paymentStatus;

    // Pick dialog mode based on current payment state
    final mode = status == RentalPaymentStatus.unpaidPending
        ? PaymentMode.rentOnly
        : status == RentalPaymentStatus.rentPaidDue
            ? PaymentMode.utilityOnly
            : PaymentMode.full;

    showDialog<bool>(
      context: context,
      builder: (_) => PaymentDialog(
        invoice: invoice,
        tenant: _tenant,
        mode: mode,
        onConfirm: (paidAt, notes) async {
          final provider = context.read<RentalProvider>();
          bool success;

          if (mode == PaymentMode.rentOnly) {
            // Record only the rent portion; electricity/water to be settled later
            success = await provider.markRentPaid(invoice.id, paidAt: paidAt);
          } else {
            // Full or utility-only — both mark the invoice as fully paid
            success = await provider.toggleInvoicePaid(invoice.id, true, paidAt: paidAt);
          }

          if (success && mounted) {
            await _loadInvoices();
            final label = mode == PaymentMode.rentOnly
                ? 'Đã thu tiền nhà ${invoice.periodDisplay}'
                : mode == PaymentMode.utilityOnly
                    ? 'Đã thu điện nước ${invoice.periodDisplay}'
                    : 'Đã thu tiền ${invoice.periodDisplay}';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(label),
                backgroundColor: AppColors.success,
              ),
            );
          }
          return success;
        },
      ),
    );
  }

  void _showInvoiceForm({RentalInvoice? invoice}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InvoiceFormDialog(
        tenant: _tenant,
        invoice: invoice,
        onSaved: _loadInvoices,
      ),
    );
  }

  void _showInvoiceDetail(RentalInvoice invoice) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(invoice.periodDisplay),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Tiền nhà', formatCurrency(invoice.rentAmount.round())),
              const Divider(),
              _detailRow('Điện cũ → mới', '${invoice.electricityOld.round()} → ${invoice.electricityNew.round()} kWh'),
              if (invoice.hasPendingMeterReading)
                _detailRow('Tiêu thụ', 'Chưa chốt sổ', color: Colors.orange)
              else
                _detailRow('Tiêu thụ', '${invoice.electricityUsage.round()} kWh × ${formatCurrency(invoice.electricityRate.round())}'),
              _detailRow('Tiền điện', formatCurrency(invoice.electricityAmount.round()), bold: true),
              const Divider(),
              _detailRow('Nước cũ → mới', '${invoice.waterOld.round()} → ${invoice.waterNew.round()} m³'),
              if (invoice.hasPendingMeterReading)
                _detailRow('Tiêu thụ', 'Chưa chốt sổ', color: Colors.orange)
              else
                _detailRow('Tiêu thụ', '${invoice.waterUsage.round()} m³ × ${formatCurrency(invoice.waterRate.round())}'),
              _detailRow('Tiền nước', formatCurrency(invoice.waterAmount.round()), bold: true),
              if (invoice.otherFees > 0) ...[  
                const Divider(),
                _detailRow('Phí khác', formatCurrency(invoice.otherFees.round())),
                if (invoice.otherFeesNote != null && invoice.otherFeesNote!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      invoice.otherFeesNote!,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
              const Divider(thickness: 2),
              _detailRow(
                'TỔNG CỘNG',
                formatCurrency(invoice.totalAmount.round()),
                bold: true,
                color: AppColors.primary,
              ),
              const Divider(height: 12),
              _detailRow(
                'Trạng thái',
                switch (invoice.paymentStatus) {
                  RentalPaymentStatus.fullyPaid => '✅ Đã thanh toán đầy đủ',
                  RentalPaymentStatus.rentPaidPending => '🏠 Đã thu tiền nhà — chờ chốt điện/nước',
                  RentalPaymentStatus.rentPaidDue => '🏠 Đã thu tiền nhà — cần thu điện/nước',
                  RentalPaymentStatus.unpaidPending => '⚠️ Chưa thu — điện/nước chưa chốt',
                  RentalPaymentStatus.unpaid => '❌ Chưa thanh toán',
                },
                color: switch (invoice.paymentStatus) {
                  RentalPaymentStatus.fullyPaid => AppColors.success,
                  RentalPaymentStatus.rentPaidPending ||
                  RentalPaymentStatus.rentPaidDue =>
                    Colors.orange,
                  _ => AppColors.error,
                },
              ),
              if (invoice.rentPaidAt != null)
                _detailRow(
                  'Ngày thu tiền nhà',
                  DateFormat('dd/MM/yyyy').format(invoice.rentPaidAt!),
                ),
              if (invoice.paidAt != null)
                _detailRow(
                  'Ngày thu đầy đủ',
                  DateFormat('dd/MM/yyyy').format(invoice.paidAt!),
                ),
              if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Ghi chú: ${invoice.notes}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareInvoice(invoice);
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Chia sẻ'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: color ?? AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceActions(RentalInvoice invoice) {
    final status = invoice.paymentStatus;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Payment action tile based on status ──
            if (status == RentalPaymentStatus.fullyPaid)
              ListTile(
                leading: Icon(Icons.undo, color: AppColors.warning),
                title: const Text('Hoàn tác thanh toán đầy đủ'),
                subtitle: const Text('Xóa ngày thu, giữ lại tiền nhà đã thu'),
                onTap: () {
                  Navigator.pop(ctx);
                  _revertFullPayment(invoice);
                },
              )
            else if (status == RentalPaymentStatus.rentPaidDue) ...[
              ListTile(
                leading: Icon(Icons.bolt, color: Colors.orange),
                title: const Text('Thu điện nước'),
                subtitle: const Text('Chốt điện/nước và thu phần còn lại'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPaymentDialog(invoice);
                },
              ),
              ListTile(
                leading: Icon(Icons.undo, color: AppColors.warning),
                title: const Text('Hoàn tác thu tiền nhà'),
                subtitle: const Text('Xóa ghi nhận tiền nhà đã thu'),
                onTap: () {
                  Navigator.pop(ctx);
                  _revertRentPayment(invoice);
                },
              ),
            ] else if (status == RentalPaymentStatus.rentPaidPending) ...[
              ListTile(
                leading: Icon(Icons.electric_meter, color: Colors.orange),
                title: const Text('Nhập số điện/nước'),
                subtitle: const Text('Cập nhật chỉ số đồng hồ → có thể thu điện/nước'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openMeterEditor(invoice);
                },
              ),
              ListTile(
                leading: Icon(Icons.undo, color: AppColors.warning),
                title: const Text('Hoàn tác thu tiền nhà'),
                subtitle: const Text('Xóa ghi nhận tiền nhà đã thu'),
                onTap: () {
                  Navigator.pop(ctx);
                  _revertRentPayment(invoice);
                },
              ),
            ] else ...[
              ListTile(
                leading: Icon(Icons.payments_outlined, color: AppColors.success),
                title: Text(status == RentalPaymentStatus.unpaidPending
                    ? 'Thu tiền nhà'
                    : 'Thu tiền'),
                subtitle: const Text('Mở hộp thoại chọn ngày'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPaymentDialog(invoice);
                },
              ),
              if (status == RentalPaymentStatus.unpaidPending)
                ListTile(
                  leading: Icon(Icons.electric_meter, color: Colors.orange),
                  title: const Text('Nhập số điện/nước'),
                  subtitle: const Text('Cập nhật đồng hồ → rồi thu đủ một lần'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openMeterEditor(invoice);
                  },
                ),
            ],
            // ── Common actions ──
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Chia sẻ hóa đơn'),
              onTap: () {
                Navigator.pop(ctx);
                _shareInvoice(invoice);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Sửa hóa đơn'),
              onTap: () {
                Navigator.pop(ctx);
                _showInvoiceForm(invoice: invoice);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Xóa hóa đơn', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteInvoice(invoice);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Revert fully paid → retains rentPaidAt (goes to rentPaidDue or rentPaidPending).
  Future<void> _revertFullPayment(RentalInvoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hoàn tác thanh toán đầy đủ'),
        content: Text(
            'Chuyển ${invoice.periodDisplay} về trạng thái chưa thu điện/nước?\n\n'
            'Tiền nhà đã thu vẫn được giữ lại.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Hoàn tác'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<RentalProvider>();
    // Clear isPaid only (keeps rentPaidAt)
    final success = await provider.toggleInvoicePaid(invoice.id, false);
    if (mounted) {
      if (success) await _loadInvoices();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Đã hoàn tác — tiền nhà vẫn giữ' : 'Có lỗi xảy ra'),
          backgroundColor: success ? AppColors.warning : AppColors.error,
        ),
      );
    }
  }

  /// Revert rent-only payment (clears rentPaidAt entirely → back to unpaid/unpaidPending).
  Future<void> _revertRentPayment(RentalInvoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hoàn tác thu tiền nhà'),
        content: Text(
            'Xóa ghi nhận đã thu tiền nhà cho ${invoice.periodDisplay}?\n\n'
            'Hóa đơn sẽ về trạng thái chưa thu.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Hoàn tác'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<RentalProvider>();
    final success = await provider.clearRentPaid(invoice.id);
    if (mounted) {
      if (success) await _loadInvoices();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Đã xóa ghi nhận tiền nhà' : 'Có lỗi xảy ra'),
          backgroundColor: success ? AppColors.warning : AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmDeleteInvoice(RentalInvoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa hóa đơn ${invoice.periodDisplay}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<RentalProvider>();
      final success = await provider.deleteInvoice(invoice.id);
      if (mounted) {
        if (success) await _loadInvoices();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Đã xóa hóa đơn' : 'Không thể xóa'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }

  void _showShareOptions() {
    final paidCount = _invoices.where((i) => i.isPaid).length;
    final unpaidCount = _invoices.where((i) => !i.isPaid).length;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.share, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Chia sẻ hóa đơn',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: const Text('Tất cả hóa đơn'),
              subtitle: Text('${_invoices.length} hóa đơn'),
              onTap: () {
                Navigator.pop(ctx);
                _shareFilteredInvoices(_invoices, 'Tất cả');
              },
            ),
            ListTile(
              leading: Icon(Icons.check_circle, color: AppColors.success),
              title: const Text('Chỉ đơn đã thanh toán'),
              subtitle: Text('$paidCount hóa đơn'),
              enabled: paidCount > 0,
              onTap: paidCount > 0
                  ? () {
                      Navigator.pop(ctx);
                      _shareFilteredInvoices(
                        _invoices.where((i) => i.isPaid).toList(),
                        'Đã thanh toán',
                      );
                    }
                  : null,
            ),
            ListTile(
              leading: Icon(Icons.pending, color: AppColors.error),
              title: const Text('Chỉ đơn chưa thanh toán'),
              subtitle: Text('$unpaidCount hóa đơn'),
              enabled: unpaidCount > 0,
              onTap: unpaidCount > 0
                  ? () {
                      Navigator.pop(ctx);
                      _shareFilteredInvoices(
                        _invoices.where((i) => !i.isPaid).toList(),
                        'Chưa thanh toán',
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _shareFilteredInvoices(List<RentalInvoice> invoices, String filterLabel) {
    final message = _buildMultiInvoiceShareText(invoices, filterLabel);
    SharePreviewDialog.show(
      context,
      message: message,
      subject: 'Hóa đơn phòng ${_tenant.roomNumber} - $filterLabel',
    );
  }

  void _shareInvoice(RentalInvoice invoice) {
    final message = _buildInvoiceShareText(invoice);
    SharePreviewDialog.show(
      context,
      message: message,
      subject: 'Hóa đơn phòng ${_tenant.roomNumber} - ${invoice.periodDisplay}',
    );
  }

  String _buildMultiInvoiceShareText(List<RentalInvoice> invoices, String filterLabel) {
    final invoiceTotal = invoices.fold<double>(0, (sum, i) => sum + i.totalAmount);
    final remainingTotal = invoices.fold<double>(0, (sum, i) => sum + i.remainingAmount);
    final depositPending = !_tenant.isDepositPaid && _tenant.depositAmount > 0;
    final grandTotal = remainingTotal + (depositPending ? _tenant.depositAmount : 0);
    final buf = StringBuffer();
    buf.writeln('📋 TỔNG HỢP HÓA ĐƠN - PHÒNG ${_tenant.roomNumber}');
    buf.writeln('👤 Khách: ${_tenant.name}');
    buf.writeln(' ${invoices.length} hóa đơn | Tổng hóa đơn: ${formatCurrency(invoiceTotal.round())}');
    if (!_tenant.isDepositPaid) {
      final depositStr = _tenant.depositAmount > 0 ? ' ${formatCurrency(_tenant.depositAmount.round())}' : '';
      buf.writeln('⚠️ Cọc:$depositStr — Chưa thu');
    }
    buf.writeln('═══════════');

    for (final invoice in invoices) {
      buf.writeln('');
      buf.writeln('🗓 ${invoice.periodDisplay}');
      final rentSuffix = invoice.isRentPaid ? ' - đã thu' : '';
      buf.writeln('🏠 Nhà: ${formatCurrency(invoice.rentAmount.round())}$rentSuffix');
      if (invoice.hasPendingMeterReading) {
        buf.writeln('⚡ Điện: chưa chốt sổ');
        buf.writeln('💧 Nước: chưa chốt sổ');
      } else {
        final utilSuffix = invoice.isPaid ? ' - đã thu' : '';
        buf.writeln('⚡ Điện: ${invoice.electricityUsage.round()} kWh = ${formatCurrency(invoice.electricityAmount.round())}$utilSuffix');
        buf.writeln('💧 Nước: ${invoice.waterUsage.round()} m³ = ${formatCurrency(invoice.waterAmount.round())}$utilSuffix');
      }
      if (invoice.otherFees > 0) buf.writeln('📎 Khác: ${formatCurrency(invoice.otherFees.round())}');
      final invoiceRemaining = invoice.remainingAmount;
      if (invoice.paymentStatus == RentalPaymentStatus.fullyPaid) {
        buf.writeln('✅ Đã thanh toán đầy đủ');
      } else if (invoice.paymentStatus == RentalPaymentStatus.rentPaidPending) {
        buf.writeln('⏳ Điện/nước sẽ báo sau khi chốt sổ');
      } else {
        final note = invoice.hasPendingMeterReading ? ' (tạm tính)' : '';
        buf.writeln('💰 Nhờ thanh toán: ${formatCurrency(invoiceRemaining.round())}$note');
      }
      buf.writeln('──────────');
    }

    buf.writeln('');
    buf.writeln('💰 Tổng còn lại: ${formatCurrency(remainingTotal.round())}');
    if (depositPending) {
      buf.writeln('⚠️ Tiền cọc: +${formatCurrency(_tenant.depositAmount.round())} — chưa thu');
      buf.writeln('💰 Tổng cần đóng: ${formatCurrency(grandTotal.round())}');
    }
    return buf.toString();
  }

  String _buildInvoiceShareText(RentalInvoice invoice) {
    final status = invoice.paymentStatus;
    final buf = StringBuffer();
    buf.writeln('📋 HÓA ĐƠN PHÒNG ${_tenant.roomNumber}');
    buf.writeln(invoice.periodDisplay);
    buf.writeln('👤 Khách: ${_tenant.name}');
    buf.writeln('');
    final rentSuffix = invoice.isRentPaid ? ' - đã thu' : '';
    buf.writeln('🏠 Tiền nhà: ${formatCurrency(invoice.rentAmount.round())}$rentSuffix');
    if (invoice.hasPendingMeterReading) {
      buf.writeln('⚡ Điện: ${invoice.electricityOld.round()} > chưa chốt sổ');
      buf.writeln('💧 Nước: ${invoice.waterOld.round()} > chưa chốt sổ');
    } else {
      final utilSuffix = invoice.isPaid ? ' - đã thu' : '';
      buf.writeln('⚡ Điện: ${invoice.electricityOld.round()} > ${invoice.electricityNew.round()}  (${invoice.electricityUsage.round()} kWh x ${formatCurrency(invoice.electricityRate.round())} = ${formatCurrency(invoice.electricityAmount.round())}$utilSuffix)');
      buf.writeln('💧 Nước: ${invoice.waterOld.round()} > ${invoice.waterNew.round()}  (${invoice.waterUsage.round()} m3 x ${formatCurrency(invoice.waterRate.round())} = ${formatCurrency(invoice.waterAmount.round())}$utilSuffix)');
    }
    if (invoice.otherFees > 0) {
      buf.writeln('📎 Phí khác: ${formatCurrency(invoice.otherFees.round())}');
      if (invoice.otherFeesNote != null && invoice.otherFeesNote!.isNotEmpty) {
        buf.writeln('   (${invoice.otherFeesNote})');
      }
    }
    buf.writeln('──────────');
    buf.writeln('');
    final remaining = invoice.remainingAmount;
    switch (status) {
      case RentalPaymentStatus.fullyPaid:
        buf.writeln('Đã thanh toán đầy đủ');
      case RentalPaymentStatus.rentPaidPending:
        buf.writeln('Điện/nước sẽ báo sau khi chốt sổ');
      case RentalPaymentStatus.rentPaidDue:
        buf.writeln('Nhờ thanh toán (tiền điện + nước): ${formatCurrency(remaining.round())}');
      case RentalPaymentStatus.unpaidPending:
        buf.writeln('Nhờ thanh toán tiền nhà: ${formatCurrency(remaining.round())}');
        buf.writeln('(điện/nước sẽ báo sau khi chốt sổ)');
      case RentalPaymentStatus.unpaid:
        buf.writeln('Nhờ thanh toán: ${formatCurrency(remaining.round())}');
    }
    if (!_tenant.isDepositPaid && _tenant.depositAmount > 0) {
      final grandTotal = remaining + _tenant.depositAmount;
      buf.writeln('⚠️ Tiền cọc: +${formatCurrency(_tenant.depositAmount.round())} — chưa thu');
      if (remaining > 0) buf.writeln('💰 Tổng cần đóng: ${formatCurrency(grandTotal.round())}');
    } else if (!_tenant.isDepositPaid) {
      buf.writeln('⚠️ Tiền cọc: chưa thu');
    }
    if (invoice.notes != null && invoice.notes!.isNotEmpty) {
      buf.writeln('');
      buf.writeln('📝 ${invoice.notes}');
    }
    return buf.toString();
  }
}
