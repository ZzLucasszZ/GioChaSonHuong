import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/vietnamese_utils.dart';
import '../../providers/rental_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../screens/debt/restaurant_debt_detail_screen.dart';
import '../../screens/home/restaurant_detail_screen.dart';
import '../../screens/inventory/widgets/add_stock_dialog.dart';
import '../../screens/inventory/widgets/stock_history_screen.dart';
import '../../screens/rental/widgets/invoice_form_dialog.dart';
import '../../screens/rental/widgets/tenant_detail_screen.dart';
import '../../screens/rental/widgets/tenant_form_dialog.dart';
import '../../screens/settings/backup_screen.dart';
import '../../screens/settings/help_screen.dart';
import 'voice_command.dart';

/// Callback to switch the bottom navigation tab.
typedef TabSwitcher = void Function(int index);

/// Callback to set search query on a tab.
typedef SearchSetter = void Function(String query);

/// Executes a [VoiceCommand] by performing navigation and actions.
///
/// Requires:
/// - [context]: BuildContext for navigation and providers
/// - [switchTab]: Callback to change the bottom nav tab index
/// - [setSearchQuery]: Optional callback to set search text in current tab
class VoiceCommandExecutor {
  static const String _tag = 'VoiceExecutor';

  final BuildContext context;
  final TabSwitcher switchTab;
  final SearchSetter? setSearchQuery;

  VoiceCommandExecutor({
    required this.context,
    required this.switchTab,
    this.setSearchQuery,
  });

  /// Execute a parsed voice command. Returns a user-facing result message.
  Future<String> execute(VoiceCommand command) async {
    AppLogger.info('Executing: ${command.intent} params=${command.params}', tag: _tag);

    switch (command.intent) {
      // ─── Navigation ───
      case VoiceIntent.navigateOrders:
        switchTab(0);
        return 'Đã mở Đơn hàng';

      case VoiceIntent.navigateInventory:
        switchTab(1);
        return 'Đã mở Kho';

      case VoiceIntent.navigateDebt:
        switchTab(2);
        return 'Đã mở Công nợ';

      case VoiceIntent.navigateDelivery:
        switchTab(3);
        return 'Đã mở Giao hàng';

      case VoiceIntent.navigateRental:
        switchTab(4);
        return 'Đã mở Nhà thuê';

      case VoiceIntent.navigateProducts:
        switchTab(5);
        return 'Đã mở Sản phẩm';

      // ─── Search ───
      case VoiceIntent.searchRestaurant:
        return _searchRestaurant(command);

      case VoiceIntent.searchProduct:
        switchTab(5); // Products tab
        final query = command.params['value'] ?? '';
        setSearchQuery?.call(query);
        return 'Tìm sản phẩm: $query';

      case VoiceIntent.searchDebt:
        switchTab(2); // Debt tab
        final debtQuery = command.params['value'] ?? '';
        setSearchQuery?.call(debtQuery);
        return 'Tìm công nợ: $debtQuery';

      case VoiceIntent.searchTenant:
        switchTab(4); // Rental tab
        final tenantQuery = command.params['value'] ?? '';
        setSearchQuery?.call(tenantQuery);
        return 'Tìm khách thuê: $tenantQuery';

      // ─── Order actions ───
      case VoiceIntent.viewRestaurant:
        return _viewRestaurant(command);

      case VoiceIntent.createOrder:
        return _createOrder(command);

      case VoiceIntent.createRestaurant:
        switchTab(0);
        return 'Đã mở Đơn hàng — nhập tên nhà hàng ở ô trên cùng rồi nhấn Tạo';

      case VoiceIntent.viewTodayOrders:
        switchTab(0);
        return 'Đơn hàng hôm nay';

      // ─── Inventory ───
      case VoiceIntent.stockIn:
        return _openStockIn();

      case VoiceIntent.viewStock:
        switchTab(1);
        return 'Đã mở Kho';

      case VoiceIntent.viewStockHistory:
        _navigateTo(const StockHistoryScreen());
        return 'Đã mở lịch sử nhập kho';

      // ─── Delivery ───
      case VoiceIntent.viewTodayDelivery:
        switchTab(3);
        return 'Giao hàng hôm nay';

      case VoiceIntent.deliverAll:
        switchTab(3);
        return 'Đã mở Giao hàng — nhấn ✅ trên thanh tiêu đề để giao tất cả';

      case VoiceIntent.shareDelivery:
        switchTab(3);
        return 'Đã mở Giao hàng — nhấn Share trên thanh tiêu đề để chia sẻ';

      // ─── Debt ───
      case VoiceIntent.viewDebt:
        return _viewDebt(command);

      case VoiceIntent.payDebt:
        return _payDebt(command);

      case VoiceIntent.addLegacyDebt:
        switchTab(2);
        return 'Đã mở Công nợ — nhấn ＋ → "Thêm nợ cũ"';

      // ─── Rental ───
      case VoiceIntent.viewRoom:
        return _viewRoom(command);

      case VoiceIntent.createInvoice:
        return _createInvoice(command);

      case VoiceIntent.addTenant:
        return _openAddTenant();

      case VoiceIntent.enterMeterReading:
        return _enterMeterReading(command);

      case VoiceIntent.markRentPaid:
        return _markRentPaid(command);

      case VoiceIntent.shareTenantInvoices:
        return _shareTenantInvoices(command);

      // ─── Products ───
      case VoiceIntent.addProduct:
        switchTab(5);
        return 'Đã mở Sản phẩm — nhấn ＋ ở góc trên để thêm';

      // ─── Utility ───
      case VoiceIntent.openBackup:
        _navigateTo(const BackupScreen());
        return 'Đã mở Sao lưu';

      case VoiceIntent.openHelp:
        _navigateTo(const HelpScreen());
        return 'Đã mở Hướng dẫn';

      // ─── Unknown ───
      case VoiceIntent.unknown:
        return 'Không nhận diện được lệnh: "${command.rawText}"';
    }
  }

  // ─── PRIVATE ACTION METHODS ───────────────────────────────

  String _searchRestaurant(VoiceCommand command) {
    final query = command.params['value'] ?? '';

    if (query.isEmpty) {
      switchTab(0);
      return 'Đã mở Đơn hàng — nhập tên nhà hàng để tìm';
    }

    // Try to find and navigate to the matching restaurant
    try {
      final provider = context.read<RestaurantProvider>();
      final restaurants = provider.restaurants;
      final normalizedQuery = normalizeForSearch(query);

      final match = restaurants.where((r) {
        return normalizeForSearch(r.name).contains(normalizedQuery);
      }).toList();

      if (match.length == 1) {
        // Exact match — navigate directly to restaurant detail
        _navigateTo(RestaurantDetailScreen(
          restaurantId: match.first.id,
          restaurantName: match.first.name,
        ));
        return 'Mở nhà hàng: ${match.first.name}';
      }

      // 0 or multiple matches — set search filter
      switchTab(0);
      setSearchQuery?.call(query);
      if (match.isEmpty) {
        return 'Không tìm thấy "$query" — đang tìm...';
      }
      return 'Tìm thấy ${match.length} nhà hàng — chọn để xem';
    } catch (e) {
      switchTab(0);
      setSearchQuery?.call(query);
      return 'Tìm nhà hàng: $query';
    }
  }

  String _viewRestaurant(VoiceCommand command) {
    final restaurantName = command.params['restaurant'] ?? '';

    if (restaurantName.isEmpty) {
      switchTab(0);
      return 'Đã mở Đơn hàng — chọn nhà hàng để xem';
    }

    try {
      final provider = context.read<RestaurantProvider>();
      final restaurants = provider.restaurants;
      final normalizedQuery = normalizeForSearch(restaurantName);

      final match = restaurants.where((r) {
        return normalizeForSearch(r.name).contains(normalizedQuery);
      }).toList();

      if (match.isEmpty) {
        switchTab(0);
        setSearchQuery?.call(restaurantName);
        return 'Không tìm thấy "$restaurantName" — đang tìm...';
      }

      if (match.length == 1) {
        _navigateTo(RestaurantDetailScreen(
          restaurantId: match.first.id,
          restaurantName: match.first.name,
        ));
        return 'Mở nhà hàng: ${match.first.name}';
      }

      switchTab(0);
      setSearchQuery?.call(restaurantName);
      return 'Tìm thấy ${match.length} nhà hàng — chọn để xem';
    } catch (e) {
      switchTab(0);
      return 'Đã mở Đơn hàng';
    }
  }

  String _createOrder(VoiceCommand command) {
    final restaurantName = command.params['restaurant'] ?? '';

    if (restaurantName.isEmpty) {
      switchTab(0);
      return 'Đã mở Đơn hàng — chọn nhà hàng để tạo đơn';
    }

    // Find matching restaurant
    try {
      final provider = context.read<RestaurantProvider>();
      final restaurants = provider.restaurants;
      final normalizedQuery = normalizeForSearch(restaurantName);

      final match = restaurants.where((r) {
        return normalizeForSearch(r.name).contains(normalizedQuery);
      }).toList();

      if (match.isEmpty) {
        switchTab(0);
        setSearchQuery?.call(restaurantName);
        return 'Không tìm thấy "$restaurantName" — đang tìm...';
      }

      if (match.length == 1) {
        // Navigate to restaurant AND auto-open Add Order dialog
        _navigateTo(RestaurantDetailScreen(
          restaurantId: match.first.id,
          restaurantName: match.first.name,
          autoOpenOrder: true,
        ));
        return 'Tạo đơn hàng — ${match.first.name}';
      }

      // Multiple matches — search on tab
      switchTab(0);
      setSearchQuery?.call(restaurantName);
      return 'Tìm thấy ${match.length} nhà hàng — chọn để tạo đơn';
    } catch (e) {
      switchTab(0);
      return 'Đã mở Đơn hàng';
    }
  }

  String _viewDebt(VoiceCommand command) {
    final restaurantName = command.params['restaurant'] ?? '';
    switchTab(2); // Debt tab

    if (restaurantName.isNotEmpty) {
      // Try to find restaurant and navigate to debt detail
      try {
        final provider = context.read<RestaurantProvider>();
        final normalizedQuery = normalizeForSearch(restaurantName);
        final match = provider.restaurants.where((r) {
          return normalizeForSearch(r.name).contains(normalizedQuery);
        }).toList();

        if (match.length == 1) {
          _navigateTo(RestaurantDebtDetailScreen(
            restaurantName: match.first.name,
            restaurantId: match.first.id,
          ));
          return 'Công nợ: ${match.first.name}';
        }
      } catch (_) {}

      setSearchQuery?.call(restaurantName);
      return 'Tìm công nợ: $restaurantName';
    }

    return 'Đã mở Công nợ';
  }

  String _payDebt(VoiceCommand command) {
    final restaurantName = command.params['restaurant'] ?? '';
    switchTab(2); // Debt tab

    if (restaurantName.isNotEmpty) {
      // Try to find restaurant and navigate to debt detail for payment
      try {
        final provider = context.read<RestaurantProvider>();
        final normalizedQuery = normalizeForSearch(restaurantName);
        final match = provider.restaurants.where((r) {
          return normalizeForSearch(r.name).contains(normalizedQuery);
        }).toList();

        if (match.length == 1) {
          _navigateTo(RestaurantDebtDetailScreen(
            restaurantName: match.first.name,
            restaurantId: match.first.id,
          ));
          return 'Thanh toán cho: ${match.first.name}';
        }
      } catch (_) {}

      setSearchQuery?.call(restaurantName);
      return 'Tìm "$restaurantName" — chọn nhà hàng để thanh toán';
    }

    return 'Đã mở Công nợ — chọn nhà hàng để thanh toán';
  }

  String _viewRoom(VoiceCommand command) {
    final roomNumber = command.params['room'] ?? '';
    switchTab(4); // Rental tab

    if (roomNumber.isNotEmpty) {
      // Try to find and navigate to the room
      try {
        final provider = context.read<RentalProvider>();
        final tenants = provider.tenants;
        final match = tenants.where(
          (t) => normalizeForSearch(t.roomNumber) == normalizeForSearch(roomNumber),
        ).toList();

        if (match.isNotEmpty) {
          _navigateTo(TenantDetailScreen(tenant: match.first));
          return 'Phòng ${match.first.roomNumber} — ${match.first.name}';
        }
      } catch (_) {}
      return 'Không tìm thấy phòng $roomNumber';
    }

    return 'Đã mở Nhà thuê';
  }

  String _createInvoice(VoiceCommand command) {
    final roomNumber = command.params['room'] ?? '';
    switchTab(4); // Rental tab

    if (roomNumber.isNotEmpty) {
      // Try to find tenant and open invoice form
      try {
        final provider = context.read<RentalProvider>();
        final tenants = provider.tenants;
        final match = tenants.where(
          (t) => normalizeForSearch(t.roomNumber) == normalizeForSearch(roomNumber),
        ).toList();

        if (match.isNotEmpty) {
          showDialog(
            context: context,
            builder: (_) => InvoiceFormDialog(
              tenant: match.first,
              onSaved: () {
                provider.loadTenants();
              },
            ),
          );
          return 'Tạo hóa đơn — phòng ${match.first.roomNumber}';
        }
      } catch (_) {}
      return 'Không tìm thấy phòng $roomNumber';
    }

    return 'Đã mở Nhà thuê — chọn phòng để tạo hóa đơn';
  }

  /// Navigate to room detail and hint about meter entry.
  String _enterMeterReading(VoiceCommand command) {
    final roomNumber = command.params['room'] ?? '';
    switchTab(4);

    if (roomNumber.isNotEmpty) {
      try {
        final match = context.read<RentalProvider>().tenants.where(
          (t) => normalizeForSearch(t.roomNumber) == normalizeForSearch(roomNumber),
        ).toList();
        if (match.isNotEmpty) {
          _navigateTo(TenantDetailScreen(tenant: match.first));
          return 'Phòng ${match.first.roomNumber} — nhấn biểu tượng ⚡ trên hóa đơn để nhập số đồng hồ';
        }
      } catch (_) {}
      return 'Không tìm thấy phòng $roomNumber';
    }
    return 'Đã mở Nhà thuê — chọn phòng rồi nhấn ⚡ để nhập số đồng hồ';
  }

  /// Navigate to room detail and hint about collecting rent.
  String _markRentPaid(VoiceCommand command) {
    final roomNumber = command.params['room'] ?? '';
    switchTab(4);

    if (roomNumber.isNotEmpty) {
      try {
        final match = context.read<RentalProvider>().tenants.where(
          (t) => normalizeForSearch(t.roomNumber) == normalizeForSearch(roomNumber),
        ).toList();
        if (match.isNotEmpty) {
          _navigateTo(TenantDetailScreen(tenant: match.first));
          return 'Phòng ${match.first.roomNumber} — giữ lâu hóa đơn → "Thu tiền nhà" hoặc "Thu đầy đủ"';
        }
      } catch (_) {}
      return 'Không tìm thấy phòng $roomNumber';
    }
    return 'Đã mở Nhà thuê — chọn phòng rồi giữ lâu hóa đơn để thu tiền';
  }

  /// Navigate to room detail and hint about sharing invoices.
  String _shareTenantInvoices(VoiceCommand command) {
    final roomNumber = command.params['room'] ?? '';
    switchTab(4);

    if (roomNumber.isNotEmpty) {
      try {
        final match = context.read<RentalProvider>().tenants.where(
          (t) => normalizeForSearch(t.roomNumber) == normalizeForSearch(roomNumber),
        ).toList();
        if (match.isNotEmpty) {
          _navigateTo(TenantDetailScreen(tenant: match.first));
          return 'Phòng ${match.first.roomNumber} — nhấn icon Share ở góc trên để chia sẻ';
        }
      } catch (_) {}
      return 'Không tìm thấy phòng $roomNumber';
    }
    return 'Đã mở Nhà thuê — chọn phòng rồi nhấn Share để chia sẻ hóa đơn';
  }

  // ─── NAVIGATION HELPER ────────────────────────────────────

  String _openStockIn() {
    switchTab(1);
    showDialog(
      context: context,
      builder: (_) => const AddStockDialog(),
    );
    return 'Mở nhập kho';
  }

  String _openAddTenant() {
    switchTab(4);
    // Capture provider locally — the executor's context (from the overlay)
    // will be invalid after the overlay route is removed.
    final provider = context.read<RentalProvider>();
    showDialog(
      context: context,
      builder: (_) => TenantFormDialog(
        onSaved: () {
          try {
            provider.loadTenants();
          } catch (_) {}
        },
      ),
    );
    return 'Thêm khách thuê mới';
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Show a brief feedback snackbar.
  static void showFeedback(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
