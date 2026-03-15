/// Represents a parsed voice command with intent and parameters.
class VoiceCommand {
  final VoiceIntent intent;
  final Map<String, String> params;
  final String rawText;
  final double confidence;

  const VoiceCommand({
    required this.intent,
    this.params = const {},
    required this.rawText,
    this.confidence = 1.0,
  });

  String? get param => params['value'];

  @override
  String toString() =>
      'VoiceCommand($intent, params=$params, raw="$rawText", confidence=$confidence)';
}

/// All supported voice command intents.
enum VoiceIntent {
  // ─── Navigation ───
  navigateOrders,       // "đơn hàng", "mở đơn hàng"
  navigateInventory,    // "kho", "tồn kho"
  navigateDebt,         // "công nợ"
  navigateDelivery,     // "giao hàng", "giao"
  navigateRental,       // "nhà thuê", "cho thuê"
  navigateProducts,     // "sản phẩm"

  // ─── Search ───
  searchRestaurant,     // "tìm [nhà hàng]"
  searchProduct,        // "tìm sản phẩm [tên]"
  searchDebt,           // "tìm công nợ [nhà hàng]"
  searchTenant,         // "tìm khách thuê [tên]", "tìm phòng [số]"

  // ─── Order actions ───
  viewRestaurant,       // "mở nhà hàng [tên]", "xem nhà hàng [tên]"
  createOrder,          // "tạo đơn cho [nhà hàng]"
  createRestaurant,     // "tạo nhà hàng", "thêm nhà hàng"
  viewTodayOrders,      // "đơn hôm nay"

  // ─── Inventory actions ───
  stockIn,              // "nhập kho [sản phẩm]"
  viewStock,            // "xem tồn kho"
  viewStockHistory,     // "lịch sử kho", "lịch sử nhập kho"

  // ─── Delivery actions ───
  viewTodayDelivery,    // "giao hôm nay"
  deliverAll,           // "giao tất cả", "giao hết"
  shareDelivery,        // "chia sẻ giao hàng"

  // ─── Debt actions ───
  viewDebt,             // "công nợ [nhà hàng]"
  payDebt,              // "thanh toán cho [nhà hàng]"
  addLegacyDebt,        // "thêm nợ cũ"

  // ─── Rental actions ───
  viewRoom,             // "phòng [số]", "xem phòng [số]"
  createInvoice,        // "tạo hóa đơn phòng [số]"
  addTenant,            // "thêm khách thuê"
  enterMeterReading,    // "chốt sổ phòng [số]", "nhập điện nước phòng [số]"
  markRentPaid,         // "thu tiền nhà phòng [số]"
  shareTenantInvoices,  // "chia sẻ hóa đơn phòng [số]"

  // ─── Products ───
  addProduct,           // "thêm sản phẩm"

  // ─── Utility ───
  openBackup,           // "sao lưu"
  openHelp,             // "hướng dẫn", "trợ giúp"

  // ─── Unknown ───
  unknown,
}

/// Human-readable description for each intent (Vietnamese).
extension VoiceIntentDescription on VoiceIntent {
  String get description {
    switch (this) {
      case VoiceIntent.navigateOrders:
        return 'Mở tab Đơn hàng';
      case VoiceIntent.navigateInventory:
        return 'Mở tab Kho';
      case VoiceIntent.navigateDebt:
        return 'Mở tab Công nợ';
      case VoiceIntent.navigateDelivery:
        return 'Mở tab Giao hàng';
      case VoiceIntent.navigateRental:
        return 'Mở tab Nhà thuê';
      case VoiceIntent.navigateProducts:
        return 'Mở tab Sản phẩm';
      case VoiceIntent.searchRestaurant:
        return 'Tìm nhà hàng';
      case VoiceIntent.searchProduct:
        return 'Tìm sản phẩm';
      case VoiceIntent.searchDebt:
        return 'Tìm công nợ';
      case VoiceIntent.searchTenant:
        return 'Tìm khách thuê';
      case VoiceIntent.viewRestaurant:
        return 'Xem nhà hàng';
      case VoiceIntent.createOrder:
        return 'Tạo đơn hàng';
      case VoiceIntent.createRestaurant:
        return 'Tạo nhà hàng';
      case VoiceIntent.viewTodayOrders:
        return 'Xem đơn hôm nay';
      case VoiceIntent.stockIn:
        return 'Nhập kho';
      case VoiceIntent.viewStock:
        return 'Xem tồn kho';
      case VoiceIntent.viewStockHistory:
        return 'Xem lịch sử nhập kho';
      case VoiceIntent.viewTodayDelivery:
        return 'Xem giao hàng hôm nay';
      case VoiceIntent.deliverAll:
        return 'Giao tất cả';
      case VoiceIntent.shareDelivery:
        return 'Chia sẻ giao hàng';
      case VoiceIntent.viewDebt:
        return 'Xem công nợ';
      case VoiceIntent.payDebt:
        return 'Thanh toán công nợ';
      case VoiceIntent.addLegacyDebt:
        return 'Thêm nợ cũ';
      case VoiceIntent.viewRoom:
        return 'Xem phòng';
      case VoiceIntent.createInvoice:
        return 'Tạo hóa đơn';
      case VoiceIntent.addTenant:
        return 'Thêm khách thuê';
      case VoiceIntent.enterMeterReading:
        return 'Nhập số đồng hồ';
      case VoiceIntent.markRentPaid:
        return 'Thu tiền nhà';
      case VoiceIntent.shareTenantInvoices:
        return 'Chia sẻ hóa đơn';
      case VoiceIntent.addProduct:
        return 'Thêm sản phẩm';
      case VoiceIntent.openBackup:
        return 'Mở sao lưu';
      case VoiceIntent.openHelp:
        return 'Mở hướng dẫn';
      case VoiceIntent.unknown:
        return 'Không nhận diện được';
    }
  }
}
