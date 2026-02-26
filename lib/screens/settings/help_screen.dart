import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hướng dẫn sử dụng'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 1. ĐẶT HÀNG ───
          _buildSection(
            icon: Icons.shopping_cart,
            title: '📦 Đặt hàng',
            content: [
              '🏪 Quản lý nhà hàng',
              '• Tạo nhà hàng mới: Nhập tên → nhấn "Tạo" (không cho trùng tên)',
              '• Đổi tên / Xóa nhà hàng: Nhấn menu ⋮ trên trang chi tiết',
              '• Tìm kiếm nhà hàng: Gõ có dấu hoặc không dấu đều được',
              '',
              '📋 Quản lý đơn hàng',
              '• Xem đơn theo ngày: Nhấn vào nhà hàng → dùng mũi tên ◀ ▶ hoặc lịch để chuyển ngày',
              '• Tạo đơn mới: Nhấn nút "Thêm đơn" → chọn buổi Sáng/Chiều',
              '• Nhập số bàn → nhấn "Áp dụng": Tự động tính số lượng theo công thức',
              '  — Đơn vị thường (Cái): số lượng = số bàn × mặc định/bàn',
              '  — Đơn vị Gói (Rế, Bánh Xếp): quy tròn lên = ⌈số bàn ÷ 2⌉',
              '  — Đơn vị cố định (Kg, Hộp, Chai...): không thay đổi theo số bàn',
              '• Khi thay đổi số bàn sau khi đã chỉnh sửa: Tỉ lệ của mỗi sản phẩm được giữ nguyên và nhân lại',
              '',
              '✏️ Chỉnh sửa đơn',
              '• Sửa nhanh: Nhấn vào đơn → nhấn icon ✏️ trên từng sản phẩm',
              '• Sửa toàn bộ: Nhấn icon ✏️ ở thanh trên → đổi ngày, buổi, số bàn, thêm/xóa sản phẩm',
              '• Xóa đơn: Nhấn icon 🗑️ trong chi tiết đơn',
              '',
              '📤 Chia sẻ',
              '• Chia sẻ đơn: Nhấn icon Share → xem trước → gửi qua Zalo, SMS, hoặc sao chép',
              '• Chia sẻ tất cả đơn trong ngày: Nhấn Share trên trang nhà hàng → gộp theo buổi Sáng/Chiều',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 2. TỒN KHO ───
          _buildSection(
            icon: Icons.inventory_2,
            title: '📊 Tồn kho',
            content: [
              '• Xem tồn kho: Hiển thị tồn hiện có, đã đặt, và còn lại',
              '• Cảnh báo màu:',
              '  — 🔴 Đỏ: Tồn kho âm (thiếu hàng)',
              '  — 🟠 Cam: Tồn kho ≤ mức cảnh báo tối thiểu',
              '  — 🟢 Xanh: Đủ hàng',
              '• Lọc theo ngày: Nhấn icon 📅 → xem tồn kho tính đến ngày đó',
              '• Nhập kho: Nhấn vào sản phẩm hoặc nút "Nhập kho" → nhập số lượng + ghi chú',
              '• Lịch sử nhập kho: Nhấn icon 📜 → xem/sửa/xóa từng phiếu nhập',
              '• Tìm kiếm: Gõ tên sản phẩm hoặc đơn vị (không dấu cũng được)',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 3. CÔNG NỢ ───
          _buildSection(
            icon: Icons.account_balance_wallet,
            title: '💰 Công nợ',
            content: [
              '📊 Tổng quan',
              '• Tổng nợ: Hiển thị tổng công nợ còn lại (đã trừ thanh toán)',
              '• Tìm kiếm nhà hàng: Gõ tên để lọc nhanh (hỗ trợ không dấu)',
              '• Nhấn tên nhà hàng → xem chi tiết công nợ',
              '',
              '💳 Thanh toán',
              '• Thanh toán đủ 1 đơn: Trong chi tiết đơn → "Thanh toán"',
              '• Thanh toán theo ngày: Nhấn "Thanh toán" trên nhóm ngày → trả hết đơn trong ngày',
              '• Thanh toán 1 phần: Nút "+" → "Thanh toán 1 phần" → nhập số tiền',
              '  — Số tiền được ghi nhận chung, trừ vào tổng công nợ',
              '  — Không ảnh hưởng từng đơn riêng lẻ (đơn vẫn hiển thị trong danh sách)',
              '• Thanh toán toàn bộ: Nhấn "Thanh toán toàn bộ" → tự động phân bổ từ đơn cũ nhất',
              '',
              '📝 Lịch sử thanh toán',
              '• Xem trong chi tiết nợ nhà hàng → mục "Lịch sử thanh toán"',
              '• Sửa thanh toán: Nhấn ⋮ → "Sửa" → đổi số tiền, ngày, ghi chú',
              '• Xóa thanh toán: Nhấn ⋮ → "Xóa" → số tiền sẽ được hoàn lại vào nợ',
              '',
              '📌 Nợ cũ (thêm thủ công)',
              '• Nút "+" → "Thêm nợ cũ" → chọn nhà hàng, ngày, số tiền',
              '• Dùng để ghi nhận nợ cũ không có đơn hàng cụ thể',
              '• Có thể sửa/xóa nợ cũ bằng cách nhấn vào hoặc giữ lâu',
              '',
              '📤 Chia sẻ công nợ',
              '• Nhấn icon Share → gửi bảng công nợ chi tiết gồm: đơn theo ngày, lịch sử thanh toán, và số dư còn lại',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 4. GIAO HÀNG ───
          _buildSection(
            icon: Icons.local_shipping,
            title: '🚚 Giao hàng',
            content: [
              '• Chọn ngày: Dùng mũi tên ◀ ▶ hoặc lịch để xem đơn theo ngày giao',
              '• Phân buổi: Đơn chia thành 🌅 Sáng và 🌆 Chiều; nhấn vào thẻ buổi để lọc',
              '• Nhóm theo nhà hàng: Trong mỗi buổi, đơn gộp theo tên nhà hàng',
              '• Trạng thái: Nền vàng = chờ giao, nền xanh = đã giao',
              '• Xác nhận giao từng đơn: Nhấn vào đơn → "Đã giao hàng"',
              '• Xác nhận giao theo nhà hàng: Nhấn icon 🚛 → giao tất cả đơn của nhà hàng đó',
              '• Xác nhận giao tất cả: Nhấn ✅ trên thanh tiêu đề',
              '',
              '📤 Chia sẻ',
              '• Chia sẻ tất cả đơn trong ngày: Nhấn icon Share trên thanh tiêu đề',
              '• Chia sẻ theo buổi: Nhấn Share trên phần Sáng hoặc Chiều',
              '• Chia sẻ theo nhà hàng: Nhấn Share trên nhóm nhà hàng',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 5. SẢN PHẨM ───
          _buildSection(
            icon: Icons.category,
            title: '🏷️ Sản phẩm',
            content: [
              '• Xem danh sách: Sản phẩm sắp xếp A-Z, hiển thị tên, đơn vị, giá, mức cảnh báo',
              '• Thêm sản phẩm: Nhấn "+" → nhập tên, đơn vị, giá, mức tồn kho tối thiểu',
              '• Sửa sản phẩm: Nhấn ⋮ → "Chỉnh sửa"',
              '• Xóa sản phẩm: Nhấn ⋮ → "Xóa" → xác nhận',
              '• Tìm kiếm: Gõ tên hoặc đơn vị sản phẩm',
              '⚠️ Lưu ý: Thay đổi giá chỉ áp dụng cho đơn hàng mới, đơn cũ giữ nguyên',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 6. SAO LƯU ───
          _buildSection(
            icon: Icons.backup,
            title: '💾 Sao lưu & Khôi phục',
            content: [
              '• Sao lưu: Nhấn "Sao lưu dữ liệu" → chọn nơi lưu file JSON',
              '• File backup chứa: tất cả sản phẩm, nhà hàng, đơn hàng, phiếu nhập kho, thanh toán',
              '• Khôi phục: Chọn file backup → xem thông tin (ngày, số sản phẩm/đơn) → xác nhận',
              '⚠️ Cảnh báo: Khôi phục sẽ thay thế toàn bộ dữ liệu hiện tại',
              '💡 Khuyến nghị: Sao lưu thường xuyên, đặc biệt trước khi khôi phục',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 7. CHIA SẺ ───
          _buildSection(
            icon: Icons.share,
            title: '📤 Chia sẻ & Gửi tin',
            content: [
              '• Xem trước nội dung: Hiển thị tin nhắn dạng chữ trước khi gửi',
              '• Sao chép: Nhấn icon 📋 để copy nội dung',
              '• Chia sẻ: Nhấn "Chia sẻ" → chọn ứng dụng (Zalo, Messenger, tin nhắn...)',
              '• Gửi SMS: Nhấn "SMS" → mở ứng dụng tin nhắn với nội dung có sẵn',
              '• Gửi Zalo: Nhấn "Zalo" → mở Zalo + tự copy nội dung, chỉ cần dán và gửi',
            ],
          ),
          const SizedBox(height: 16),

          // ─── TIPS ───
          _buildTipsSection(),
          const SizedBox(height: 32),
          _buildContactSection(),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<String> content,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...content.map((text) => Padding(
              padding: EdgeInsets.only(
                bottom: text.isEmpty ? 8 : 6,
              ),
              child: text.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: text.startsWith('⚠️') || text.startsWith('💡')
                            ? Colors.orange.shade800
                            : text.contains('🏪') || text.contains('📋') || text.contains('✏️') || text.contains('📤') || text.contains('💳') || text.contains('📝') || text.contains('📌') || text.contains('📊')
                                ? AppColors.primary
                                : Colors.grey[800],
                        fontWeight: text.contains('🏪') || text.contains('📋') || text.contains('✏️') || text.contains('📤') || text.contains('💳') || text.contains('📝') || text.contains('📌') || text.contains('📊')
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsSection() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.orange.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  '💡 Mẹo sử dụng',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...[
              '• Tìm kiếm không dấu: Gõ "nha hang" sẽ tìm thấy "Nhà hàng"',
              '• Số tiền tự format: Nhập 35673000 → hiển thị 35.673.000',
              '• Sản phẩm Kg: Cho phép nhập số thập phân (ví dụ: 1.5 kg)',
              '• Số bàn & Gói: Nhập 3 bàn → Rế/Bánh Xếp tự tính = 2 gói (⌈3÷2⌉)',
              '• Đơn vị cố định: Kg, Hộp, Chai, Lon... không nhân theo số bàn',
              '• Thanh toán 1 phần: Đơn hàng vẫn hiển thị để chia sẻ/xem lại',
              '• Thanh toán toàn bộ: Trả từ đơn cũ nhất → mới nhất',
              '• Đổi ngày giao: Khi sửa đơn đổi ngày, màn hình tự chuyển sang ngày mới',
              '• Icon màu: 🔴 Chưa trả, 🟡 Trả 1 phần, 🟢 Đã trả đủ',
              '• Sắp xếp: Danh sách nhà hàng và sản phẩm luôn theo A-Z',
            ].map((text) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.blue.shade900,
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.help_outline, size: 48, color: Colors.green.shade700),
            const SizedBox(height: 12),
            Text(
              'Cần hỗ trợ?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Liên hệ hỗ trợ kỹ thuật nếu gặp vấn đề',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
