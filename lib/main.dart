import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/logger.dart';
import 'data/database/database_helper.dart';
import 'providers/restaurant_provider.dart';
import 'providers/order_provider.dart';
import 'providers/product_provider.dart';
import 'providers/inventory_provider.dart';
import 'screens/main_screen.dart';
import 'scripts/seed_products.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error(
      'Flutter Error',
      error: details.exception,
      stackTrace: details.stack,
      tag: 'FlutterError',
    );
    FlutterError.presentError(details);
  };
  
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error(
      'Uncaught Error',
      error: error,
      stackTrace: stack,
      tag: 'PlatformError',
    );
    return true;
  };
  
  // Initialize database factory for desktop platforms
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize Vietnamese locale for date formatting
  await initializeDateFormatting('vi_VN', null);
  
  // Initialize database
  AppLogger.info('Initializing database...');
  final dbHelper = DatabaseHelper.instance;
  
  try {
    await dbHelper.database; // Ensure database is created
    AppLogger.success('Database initialized successfully');
    
    // Seed initial products (only runs once)
    AppLogger.info('Seeding products...');
    await seedProducts();
    AppLogger.success('Products seeded successfully');
  } catch (e, stack) {
    AppLogger.error('Failed to initialize database', error: e, stackTrace: stack);
    rethrow;
  }
  
  runApp(MainApp(dbHelper: dbHelper));
}

class MainApp extends StatelessWidget {
  final DatabaseHelper dbHelper;
  
  const MainApp({super.key, required this.dbHelper});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RestaurantProvider(dbHelper),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(dbHelper),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductProvider(dbHelper),
        ),
        ChangeNotifierProvider(
          create: (_) => InventoryProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Giò Chả Sơn Hương',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('vi', 'VN'),
          Locale('en', 'US'),
        ],
        locale: const Locale('vi', 'VN'),
        home: const MainScreen(),
      ),
    );
  }
}
