import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/vietnamese_utils.dart';
import '../../providers/restaurant_provider.dart';
import '../debt/debt_screen.dart';
import '../settings/backup_screen.dart';
import '../settings/help_screen.dart';
import 'restaurant_detail_screen.dart';

/// Home screen - Restaurant list with create form
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load restaurants on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RestaurantProvider>().loadRestaurants();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createRestaurant() async {
    if (_formKey.currentState?.validate() ?? false) {
      final provider = context.read<RestaurantProvider>();
      final result = await provider.createRestaurant(name: _nameController.text);
      
      if (mounted) {
        if (result != null) {
          _nameController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tạo nhà hàng "${result.name}"'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (provider.error != null) {
          // Show error message if creation failed (e.g., duplicate name)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.error!),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _navigateToDetail(String restaurantId, String restaurantName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetailScreen(
          restaurantId: restaurantId,
          restaurantName: restaurantName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý đơn hàng'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Hướng dẫn sử dụng',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.backup),
            tooltip: 'Sao lưu & Khôi phục',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BackupScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Công nợ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebtScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Create restaurant form
          _buildCreateForm(),
          
          const Divider(height: 1),
          
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm nhà hàng...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Restaurant list
          Expanded(
            child: _buildRestaurantList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: Form(
        key: _formKey,
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _nameController,
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Nhập tên nhà hàng...',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _createRestaurant(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _createRestaurant,
              icon: const Icon(Icons.add),
              label: const Text('Tạo'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantList() {
    return Consumer<RestaurantProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  provider.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red[700]),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => provider.loadRestaurants(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        var restaurants = provider.restaurants;
        
        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          final normalizedQuery = normalizeForSearch(_searchQuery);
          restaurants = restaurants.where((r) => 
              normalizeForSearch(r.name).contains(normalizedQuery)
          ).toList();
        }
        
        // Sort alphabetically
        restaurants.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (restaurants.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _searchQuery.isNotEmpty ? Icons.search_off : Icons.store_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty 
                      ? 'Không tìm thấy nhà hàng nào'
                      : 'Chưa có nhà hàng nào',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nhập tên và nhấn "Tạo" để thêm nhà hàng mới',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: restaurants.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final restaurant = restaurants[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  restaurant.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                restaurant.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: restaurant.phone.isNotEmpty
                  ? Text(restaurant.phone)
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _navigateToDetail(restaurant.id, restaurant.name),
            );
          },
        );
      },
    );
  }
}
