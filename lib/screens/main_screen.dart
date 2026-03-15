import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/logger.dart';
import '../data/database/database_helper.dart';
import '../providers/wake_word_provider.dart';
import 'home/home_screen.dart';
import 'inventory/inventory_tab.dart';
import 'debt/debt_tab.dart';
import 'delivery/delivery_tab.dart';
import 'rental/rental_tab.dart';
import 'settings/product_management_screen.dart';
import 'shared/voice_input_overlay.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  String? _pendingSearchQuery;

  /// Provider managing wake word listener state and persistence.
  late final WakeWordProvider _wakeProvider;
  bool _isOverlayOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wakeProvider = WakeWordProvider(
      dbHelper: DatabaseHelper.instance,
      onWakeWord: _onWakeWordDetected,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _wakeProvider.init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wakeProvider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wakeProvider.onBackground();
    } else if (state == AppLifecycleState.resumed) {
      _wakeProvider.onForeground();
    }
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _setSearchQuery(String query) {
    setState(() => _pendingSearchQuery = query);
    // Clear after this frame so the query is consumed only once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pendingSearchQuery = null;
    });
  }

  Widget _getCurrentTab() {
    final sq = _pendingSearchQuery;
    switch (_currentIndex) {
      case 0:
        return HomeScreen(initialSearchQuery: sq);
      case 1:
        return InventoryTab(initialSearchQuery: sq);
      case 2:
        return DebtTab(initialSearchQuery: sq);
      case 3:
        return const DeliveryTab();
      case 4:
        return const RentalTab();
      case 5:
        return ProductManagementScreen(initialSearchQuery: sq);
      default:
        return HomeScreen(initialSearchQuery: sq);
    }
  }

  /// Called when the background listener detects "Hi Tom".
  void _onWakeWordDetected() {
    if (_isOverlayOpen) return;
    AppLogger.info('Wake word detected — opening voice overlay', tag: 'Main');
    _openVoiceOverlay(skipPhase1: true);
  }

  Future<void> _openVoiceOverlay({required bool skipPhase1}) async {
    _isOverlayOpen = true;
    _wakeProvider.onOverlayOpened();

    await VoiceInputOverlay.show(
      context,
      switchTab: _switchTab,
      setSearchQuery: _setSearchQuery,
      skipPhase1: skipPhase1,
    );

    _isOverlayOpen = false;
    _wakeProvider.onOverlayClosed();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WakeWordProvider>.value(
      value: _wakeProvider,
      child: Scaffold(
        body: _getCurrentTab(),
        bottomNavigationBar: NavigationBar(
        height: 62,
        selectedIndex: _currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined, size: 22),
            selectedIcon: Icon(Icons.shopping_cart, size: 22),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined, size: 22),
            selectedIcon: Icon(Icons.inventory_2, size: 22),
            label: 'Kho',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined, size: 22),
            selectedIcon: Icon(Icons.account_balance_wallet, size: 22),
            label: 'Công nợ',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined, size: 22),
            selectedIcon: Icon(Icons.local_shipping, size: 22),
            label: 'Giao',
          ),
          NavigationDestination(
            icon: Icon(Icons.house_outlined, size: 22),
            selectedIcon: Icon(Icons.house, size: 22),
            label: 'Thuê',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined, size: 22),
            selectedIcon: Icon(Icons.category, size: 22),
            label: 'Sản phẩm',
          ),
        ],
      ),
      ),
    );
  }
}
