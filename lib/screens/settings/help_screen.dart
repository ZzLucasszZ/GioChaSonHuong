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
          // ─── TỔNG QUAN ───
          _buildOverviewCard(),
          const SizedBox(height: 16),

          // ─── 1. ĐƠN HÀNG ───
          _buildSection(
            icon: Icons.shopping_cart,
            title: '📦 Tab 1 — Đơn hàng',
            content: [
              '🏪 Nhà hàng',
              '• Tạo nhà hàng: Nhập tên ở ô trên cùng → nhấn "Tạo" (không cho trùng tên)',
              '• Tìm nhà hàng: Gõ có dấu hoặc không dấu đều được',
              '• Đổi tên / Xóa: Nhấn vào nhà hàng → menu ⋮ ở góc trên',
              '• Xóa nhà hàng: Xóa luôn tất cả đơn hàng, thanh toán liên quan + hoàn kho',
              '• Danh sách sắp xếp theo A-Z',
              '',
              '📋 Đơn hàng',
              '• Nhấn vào nhà hàng → xem đơn theo ngày',
              '• Chuyển ngày: Mũi tên ◀ ▶, nhấn ngày để mở lịch, hoặc nhấn "Hôm nay"',
              '• Tạo đơn: Nhấn nút "Thêm đơn" ở dưới cùng',
              '',
              '🌅 Tạo đơn mới',
              '• Chọn buổi: 🌅 Sáng hoặc 🌆 Chiều',
              '• Nhập số bàn → nhấn "Áp dụng" để tự động tính:',
              '   — Đơn vị thường (Cái): số lượng = số bàn × mặc định/bàn',
              '   — Đơn vị Gói: quy tròn lên = ⌈số bàn ÷ 2⌉',
              '   — Đơn vị cố định (Kg, Hộp, Chai, Lon...): không đổi theo số bàn',
              '• Thêm sản phẩm: Nhấn "Thêm sản phẩm" → chọn từ danh sách',
              '• Sửa số lượng / giá trực tiếp trên từng dòng sản phẩm',
              '• Xóa sản phẩm: Nhấn icon 🗑️ trên dòng sản phẩm',
              '• Nhấn "Tạo đơn" khi hoàn tất (cần ít nhất 1 sản phẩm, số lượng > 0)',
              '',
              '✏️ Sửa đơn',
              '• Sửa nhanh từng SP: Nhấn vào đơn → nhấn ✏️ trên sản phẩm cần sửa',
              '• Sửa toàn bộ: Nhấn icon ✏️ ở thanh trên → đổi ngày, buổi, số bàn, thêm/xóa SP',
              '• Xóa đơn: Menu ⋮ → "Xóa đơn hàng"',
              '',
              '📤 Chia sẻ',
              '• Chia sẻ 1 đơn: Trong chi tiết đơn → nhấn icon Share',
              '• Chia sẻ tất cả đơn trong ngày: Trên trang nhà hàng → nhấn Share (gộp theo buổi)',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 2. KHO ───
          _buildSection(
            icon: Icons.inventory_2,
            title: '📊 Tab 2 — Kho',
            content: [
              '📦 Xem tồn kho',
              '• Mỗi sản phẩm hiển thị 3 số: Tồn kho / Đã đặt / Còn lại',
              '• Nhấn vào "Đã đặt" → xem chi tiết nhà hàng nào đặt bao nhiêu',
              '• Cảnh báo màu:',
              '   — 🔴 Đỏ: Tồn kho âm (thiếu hàng)',
              '   — 🟠 Cam: Tồn kho ≤ mức cảnh báo',
              '   — 🟢 Xanh: Đủ hàng',
              '• Lọc theo ngày: Nhấn icon 📅 → xem tồn tính đến ngày đó',
              '• Tìm kiếm: Gõ tên sản phẩm hoặc đơn vị',
              '',
              '📥 Nhập kho',
              '• Nhấn vào sản phẩm bất kỳ → nhập số lượng + ghi chú',
              '• Hoặc nhấn nút "Nhập kho" ở dưới cùng',
              '',
              '📜 Lịch sử nhập kho',
              '• Nhấn icon 📜 ở góc trên → xem toàn bộ lịch sử',
              '• Chuyển ngày: ◀ ▶ hoặc lịch, nhấn "Tất cả" để xem mọi ngày',
              '• Nhấn vào phiếu nhập → sửa số lượng hoặc ghi chú',
              '• Xóa phiếu nhập: Trong dialog sửa → nhấn "Xóa" (tồn kho sẽ bị điều chỉnh lại)',
              '',
              '👁️ Ẩn / Hiện sản phẩm',
              '• Giữ lâu sản phẩm → "Ẩn khỏi tồn kho" (SP không bị xóa, chỉ ẩn)',
              '• Nhấn icon 👁️ ở góc trên → xem danh sách SP đã ẩn → nhấn "Hiện lại"',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 3. CÔNG NỢ ───
          _buildSection(
            icon: Icons.account_balance_wallet,
            title: '💰 Tab 3 — Công nợ',
            content: [
              '📊 Tổng quan',
              '• Thẻ đỏ trên cùng: Tổng nợ còn lại, số đơn, số nhà hàng',
              '• Tìm kiếm nhà hàng: Gõ tên để lọc nhanh',
              '• Nhấn tên nhà hàng → xem chi tiết nợ + thống kê tiền hàng',
              '• Mở rộng nhà hàng → xem đơn nhóm theo ngày',
              '',
              '💳 Thanh toán',
              '• Thanh toán đủ 1 đơn: Trong chi tiết đơn → "Thanh toán"',
              '• Thanh toán theo ngày: Nhấn "Thanh toán" trên nhóm ngày → trả hết đơn trong ngày đó',
              '• Thanh toán 1 phần: Nút ＋ → "Thanh toán 1 phần" → nhập số tiền',
              '   — Số tiền ghi nhận chung, trừ vào tổng công nợ',
              '   — Đơn hàng vẫn hiển thị trong danh sách để xem lại',
              '• Thanh toán toàn bộ: Nhấn "Thanh toán toàn bộ" → tự động phân bổ từ đơn cũ → mới',
              '',
              '📝 Lịch sử thanh toán',
              '• Xem trong chi tiết nợ nhà hàng → mục "Lịch sử thanh toán"',
              '• Sửa: Nhấn ⋮ → "Sửa" → đổi số tiền, ngày, ghi chú',
              '• Xóa: Nhấn ⋮ → "Xóa" → số tiền được hoàn lại vào nợ',
              '',
              '📌 Nợ cũ',
              '• Nút ＋ → "Thêm nợ cũ" → chọn nhà hàng, ngày, số tiền',
              '• Dùng để ghi nhận nợ cũ không có đơn hàng cụ thể',
              '• Nhấn vào hoặc giữ lâu → sửa / xóa nợ cũ',
              '',
              '📤 Chia sẻ',
              '• Nhấn Share → bảng công nợ chi tiết gồm: đơn theo ngày, lịch sử thanh toán, số dư còn lại',
              '',
              '📈 Thống kê',
              '• Trong chi tiết nợ nhà hàng → "Thống kê tiền hàng"',
              '• Xem tổng tiền hàng theo tháng/năm, số đơn mỗi tháng',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 4. GIAO HÀNG ───
          _buildSection(
            icon: Icons.local_shipping,
            title: '🚚 Tab 4 — Giao',
            content: [
              '📅 Xem đơn giao',
              '• Chọn ngày: Mũi tên ◀ ▶ hoặc nhấn ngày để mở lịch',
              '• Hiển thị thứ + ngày tiếng Việt (VD: Thứ Hai, 26/02/2026)',
              '• Đơn chia theo buổi: 🌅 Sáng / 🌆 Chiều',
              '• Nhấn vào thẻ buổi để lọc chỉ xem buổi đó',
              '• Trong mỗi buổi, đơn nhóm theo nhà hàng (A-Z)',
              '',
              '🚛 Xác nhận giao hàng',
              '• Giao từng đơn: Nhấn vào đơn → "Đã giao hàng" (tự động trừ tồn kho)',
              '• Giao theo nhà hàng: Nhấn icon 🚛 trên nhóm nhà hàng',
              '• Giao tất cả: Nhấn ✅ trên thanh tiêu đề',
              '• Trạng thái: Nền vàng = chờ giao, nền xanh = đã giao',
              '',
              '📤 Chia sẻ',
              '• Tất cả: Nhấn Share trên thanh tiêu đề',
              '• Theo buổi: Nhấn Share trên phần Sáng hoặc Chiều',
              '• Theo nhà hàng: Nhấn Share trên nhóm nhà hàng',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 5. NHÀ CHO THUÊ ───
          _buildSection(
            icon: Icons.house,
            title: '🏠 Tab 5 — Thuê',
            content: [
              '👤 Quản lý khách thuê',
              '• Thêm khách: Nhấn "Thêm khách" ở dưới cùng',
              '• Nhập: Tên, SĐT, số phòng, tiền nhà, giá điện, giá nước, tiền cọc, ghi chú',
              '• Tiền cọc: ghi nhận trạng thái đã thu / chưa thu tiền cọc',
              '• Giá mặc định: Điện 3.500₫/kWh, Nước 4.000₫/m³',
              '• Nhấn vào khách → xem chi tiết + danh sách hóa đơn',
              '• Giữ lâu → sửa thông tin hoặc xóa khách thuê',
              '',
              '🧾 Tạo hóa đơn',
              '• Trong chi tiết khách → nhấn "Tạo hóa đơn"',
              '• Chọn tháng/năm → nhập số điện/nước cũ-mới → tiền tự động tính',
              '• Tạo nhiều tháng liên tiếp: Bật "Tạo nhiều tháng" → chọn số tháng',
              '   — Các tháng tiếp tạo sẵn, nhập số đồng hồ sau khi chốt',
              '   — Hiển thị "Chưa chốt sổ" cho tháng chưa có số đồng hồ',
              '• Có thể thêm phí khác (vệ sinh, internet...)',
              '• Không cho tạo trùng hóa đơn cùng tháng',
              '• Số điện/nước cũ tự động lấy từ hóa đơn tháng trước',
              '',
              '✏️ Quản lý hóa đơn',
              '• Nhấn vào hóa đơn → xem chi tiết đầy đủ',
              '• Giữ lâu → menu: Thu tiền nhà / Thu đầy đủ, chia sẻ, sửa, xóa',
              '• 5 trạng thái hóa đơn:',
              '   ❌ Chưa thanh toán — chưa thu gì, đã có số đồng hồ',
              '   ⚠️ Chưa thu — điện/nước chưa chốt sổ',
              '   🏠 Đã thu tiền nhà — chờ chốt điện/nước',
              '   🔔 Đã thu tiền nhà — cần thu điện/nước',
              '   ✅ Đã thanh toán đầy đủ',
              '• Tiêu thụ hiển thị "Chưa chốt sổ" thay vì số âm khi chưa nhập',
              '',
              '📤 Chia sẻ hóa đơn',
              '• Chia sẻ 1 hóa đơn: Nhấn vào hóa đơn → "Chia sẻ"',
              '• Chia sẻ nhiều: Nhấn icon Share trên thanh tiêu đề → chọn:',
              '   — Tất cả hóa đơn',
              '   — Chỉ đơn đã thanh toán',
              '   — Chỉ đơn chưa thanh toán',
              '• Nội dung: thông tin khách, chi tiết hóa đơn, tổng cần đóng',
              '• Tiền cọc chưa thu sẽ được thêm vào nội dung chia sẻ',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 6. SẢN PHẨM ───
          _buildSection(
            icon: Icons.category,
            title: '🏷️ Tab 6 — Sản phẩm',
            content: [
              '• Danh sách sắp xếp A-Z, hiển thị: tên, đơn vị, giá cơ bản, mức cảnh báo',
              '• Thêm: Nhấn ＋ ở góc trên → nhập tên, đơn vị, giá, mức tồn kho tối thiểu',
              '• Sửa: Nhấn ⋮ → "Chỉnh sửa"',
              '• Xóa: Nhấn ⋮ → "Xóa" (sản phẩm vẫn hiện trong đơn cũ)',
              '• Tìm kiếm: Gõ tên hoặc đơn vị',
              '⚠️ Thay đổi giá chỉ áp dụng cho đơn hàng mới — đơn cũ giữ nguyên giá lúc đặt',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 7. THANH TOÁN TRONG ĐƠN ───
          _buildSection(
            icon: Icons.payment,
            title: '💳 Thanh toán trong đơn hàng',
            content: [
              '• Mở chi tiết đơn → nhấn "Thanh toán" ở dưới cùng',
              '• Thanh toán đủ: Nhấn "Thanh toán đủ" → trả hết số tiền còn lại',
              '• Thanh toán 1 phần: Nhập số tiền → "Thanh toán một phần"',
              '• Trạng thái tự động cập nhật:',
              '   — 🔴 Chưa thanh toán (chưa trả đồng nào)',
              '   — 🟡 Thanh toán 1 phần (đã trả chưa đủ)',
              '   — 🟢 Đã thanh toán đủ',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 8. SAO LƯU ───
          _buildSection(
            icon: Icons.backup,
            title: '💾 Sao lưu & Khôi phục',
            content: [
              '☁️ Google Drive (tự động)',
              '• Đăng nhập Google trong màn hình Sao lưu',
              '• Auto-backup khi có thay đổi dữ liệu (tối đa 1 lần/giờ)',
              '• Giữ tối đa 5 bản backup trên Drive',
              '• Sao lưu thủ công: Nhấn "Sao lưu ngay"',
              '• Khôi phục: Chọn bản backup → "Khôi phục" → khởi động lại app',
              '• Xóa bản backup: Menu ⋮ → "Xóa"',
              '',
              '📁 File JSON (thủ công)',
              '• Xuất: Nhấn "Xuất file JSON" → chia sẻ qua Email, Zalo, Drive...',
              '• Nhập: Nhấn "Nhập file JSON" → chọn file .json → xem thông tin → xác nhận',
              '• File chứa: sản phẩm, nhà hàng, đơn hàng, tồn kho, thanh toán',
              '⚠️ Khôi phục sẽ thay thế toàn bộ dữ liệu hiện tại!',
              '💡 Nên sao lưu thường xuyên, đặc biệt trước khi khôi phục',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 9. CHIA SẺ ───
          _buildSection(
            icon: Icons.share,
            title: '📤 Chia sẻ',
            content: [
              '• Xem trước nội dung dạng chữ trước khi gửi',
              '• 📋 Sao chép: Nhấn icon copy ở góc trên',
              '• 📱 Chia sẻ: Nhấn "Chia sẻ" → chọn ứng dụng (Zalo, Messenger...)',
              '• 💬 SMS: Nhấn icon tin nhắn → mở app SMS với nội dung có sẵn',
              '• Zalo: Nhấn icon Zalo → mở Zalo + tự copy nội dung, chỉ cần dán và gửi',
              '',
              'Có thể chia sẻ từ nhiều nơi:',
              '• Đơn hàng (từng đơn hoặc tất cả trong ngày)',
              '• Công nợ (theo nhà hàng)',
              '• Giao hàng (tất cả / theo buổi / theo nhà hàng)',
              '• Nhà thuê (từng hóa đơn / tất cả / đã trả / chưa trả)',
            ],
          ),
          const SizedBox(height: 16),

          // ─── 9. LỆNH GIỌNG NÓI ───
          _buildSection(
            icon: Icons.mic,
            title: '🎙️ Lệnh giọng nói',
            content: [
              '🎙️ Cách kích hoạt',
              '• Nhấn nút micro ở góc dưới màn hình chính',
              '• Nói "Hi Tom" → app phản hồi → nói lệnh',
              '• Nói tự nhiên, cả câu dài đều được',
              '   VD: "Tom ơi tạo đơn hàng cho nhà hàng Yến Lan đi"',
              '',
              '📦 Đơn hàng',
              '• "Đơn hàng" — mở tab đơn',
              '• "Mở nhà hàng Yến Lan" — vào thẳng nhà hàng',
              '• "Tạo đơn cho Yến Lan" — mở form tạo đơn ngay',
              '• "Tạo nhà hàng" / "Thêm nhà hàng mới"',
              '• "Đơn hôm nay" — xem đơn trong ngày',
              '• "Tìm nhà hàng Sao Mai"',
              '',
              '📊 Kho',
              '• "Kho" / "Tồn kho"',
              '• "Nhập kho Giò bì" — mở form nhập kho',
              '• "Lịch sử nhập kho"',
              '',
              '💰 Công nợ',
              '• "Công nợ" — mở tab công nợ',
              '• "Công nợ Yến Lan" — vào chi tiết nợ nhà hàng',
              '• "Thanh toán cho Yến Lan" — mở màn hình thanh toán',
              '• "Thêm nợ cũ"',
              '',
              '🚚 Giao hàng',
              '• "Giao hàng" / "Giao hôm nay"',
              '• "Giao tất cả" — nhắc nhấn ✅ để xác nhận',
              '• "Chia sẻ giao hàng"',
              '',
              '🏠 Nhà thuê',
              '• "Nhà thuê" / "Cho thuê"',
              '• "Phòng 101" — vào chi tiết phòng',
              '• "Tạo hóa đơn phòng 101" — mở form tạo hóa đơn',
              '• "Thêm khách thuê" — mở form thêm khách mới',
              '• "Tìm khách thuê Nguyễn"',
              '',
              '🏷️ Sản phẩm',
              '• "Sản phẩm" — mở tab sản phẩm',
              '• "Thêm sản phẩm" — mở form thêm mới',
              '• "Tìm sản phẩm Giò"',
              '',
              '⚙️ Tiện ích',
              '• "Sao lưu" / "Backup"',
              '• "Hướng dẫn" / "Trợ giúp"',
            ],
          ),
          const SizedBox(height: 16),

          // ─── TIPS ───
          _buildTipsSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.apps, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Giò Chả Sơn Hương',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'App quản lý đơn hàng, tồn kho, công nợ, giao hàng và nhà cho thuê. '
              'Chạy offline hoàn toàn — không cần mạng (trừ sao lưu Google Drive).',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: const [
                _TabChip(icon: Icons.shopping_cart, label: 'Đơn hàng'),
                _TabChip(icon: Icons.inventory_2, label: 'Kho'),
                _TabChip(icon: Icons.account_balance_wallet, label: 'Công nợ'),
                _TabChip(icon: Icons.local_shipping, label: 'Giao'),
                _TabChip(icon: Icons.house, label: 'Thuê'),
                _TabChip(icon: Icons.category, label: 'Sản phẩm'),
              ],
            ),
          ],
        ),
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
                        color: _isSubheading(text)
                            ? AppColors.primary
                            : text.startsWith('⚠️') || text.startsWith('💡')
                                ? Colors.orange.shade800
                                : Colors.grey[800],
                        fontWeight: _isSubheading(text)
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

  bool _isSubheading(String text) {
    const subheadingEmojis = [
      '🏪', '📋', '🌅', '✏️', '📤', '📦', '📥', '📜',
      '📊', '💳', '📝', '📌', '📈', '📅', '🚛', '☁️', '📁',
      '👤', '🧾', '👁️',
      '🎙️', '💰', '🚚', '🏠', '🏷️', '⚙️',
    ];
    return subheadingEmojis.any((e) => text.startsWith(e));
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
              '• Tìm kiếm không dấu: Gõ "nha hang" → tìm thấy "Nhà hàng"',
              '• Số tiền tự phân cách: Nhập 35673000 → hiển thị 35.673.000',
              '• Sản phẩm Kg: Cho phép nhập số thập phân (VD: 1.5 kg)',
              '• Số bàn & Gói: 3 bàn → Rế/Bánh Xếp = 2 gói (⌈3÷2⌉)',
              '• Đơn vị cố định: Kg, Hộp, Chai, Lon, Bịch... không nhân theo số bàn',
              '• Đổi số bàn: Tỉ lệ SP hiện tại được giữ nguyên và nhân lại',
              '• Thanh toán 1 phần: Đơn vẫn hiển thị để xem lại và chia sẻ',
              '• Thanh toán toàn bộ: Phân bổ từ đơn cũ nhất → mới nhất',
              '• Đổi ngày giao: Khi sửa đơn đổi ngày, màn hình tự chuyển sang ngày mới',
              '• Icon màu đơn: 🔴 Chưa trả · 🟡 Trả 1 phần · 🟢 Đã trả đủ',
              '• Icon màu kho: 🔴 Thiếu · 🟠 Sắp hết · 🟢 Đủ',
              '• Sắp xếp: Nhà hàng và sản phẩm luôn theo A-Z',
              '• Giao hàng = trừ kho tự động (không cần trừ tay)',
              '• Ẩn SP khỏi kho: SP không bị xóa, vẫn có thể hiện lại',
              '• Nhà thuê: Số điện/nước cũ tự lấy từ hóa đơn trước',
              '• Nhà thuê: Chia sẻ lọc theo đã trả / chưa trả',
              '• Nhà thuê: Tiền cọc — đánh dấu đã thu trong thông tin khách thuê',
              '• Nhà thuê: Tạo nhiều tháng → nhập số điện/nước sau khi chốt sổ',
              '• Nhà thuê: Số tiêu thụ âm → hiển thị "Chưa chốt sổ", không phải lỗi',
              '• Google Drive: Đăng nhập 1 lần → app tự backup khi có thay đổi',
              '• Giọng nói: Nói "Hi Tom" → nói lệnh → app tự chuyển trang và thực hiện',
              '• Giọng nói: Hỗ trợ câu dài tự nhiên, hiểu cả không dấu / nói nhầm từ',
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
}

class _TabChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TabChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
