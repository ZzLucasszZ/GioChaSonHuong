import '../../../core/constants/db_constants.dart';

/// Database migration for version 1
class MigrationV1 {
  MigrationV1._();

  static const String createRestaurantsTable = '''
    CREATE TABLE ${DbConstants.tableRestaurants} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colName} TEXT NOT NULL,
      ${DbConstants.colContactPerson} TEXT,
      ${DbConstants.colPhone} TEXT NOT NULL,
      ${DbConstants.colAddress} TEXT NOT NULL,
      ${DbConstants.colNotes} TEXT,
      ${DbConstants.colIsActive} INTEGER DEFAULT 1,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL
    )
  ''';

  static const String createProductsTable = '''
    CREATE TABLE ${DbConstants.tableProducts} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colName} TEXT NOT NULL,
      ${DbConstants.colSku} TEXT UNIQUE,
      ${DbConstants.colUnit} TEXT NOT NULL,
      ${DbConstants.colBasePrice} REAL NOT NULL DEFAULT 0,
      ${DbConstants.colCurrentStock} REAL NOT NULL DEFAULT 0,
      ${DbConstants.colMinStockAlert} REAL NOT NULL DEFAULT 0,
      ${DbConstants.colCategory} TEXT,
      ${DbConstants.colIsActive} INTEGER DEFAULT 1,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL
    )
  ''';

  static const String createRestaurantPricesTable = '''
    CREATE TABLE ${DbConstants.tableRestaurantPrices} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colRestaurantId} TEXT NOT NULL,
      ${DbConstants.colProductId} TEXT NOT NULL,
      ${DbConstants.colPrice} REAL NOT NULL,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL,
      FOREIGN KEY (${DbConstants.colRestaurantId}) REFERENCES ${DbConstants.tableRestaurants}(${DbConstants.colId}) ON DELETE CASCADE,
      FOREIGN KEY (${DbConstants.colProductId}) REFERENCES ${DbConstants.tableProducts}(${DbConstants.colId}) ON DELETE CASCADE,
      UNIQUE(${DbConstants.colRestaurantId}, ${DbConstants.colProductId})
    )
  ''';

  static const String createOrdersTable = '''
    CREATE TABLE ${DbConstants.tableOrders} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colRestaurantId} TEXT NOT NULL,
      ${DbConstants.colOrderDate} TEXT NOT NULL,
      ${DbConstants.colDeliveryDate} TEXT NOT NULL,
      ${DbConstants.colSession} TEXT NOT NULL DEFAULT 'morning',
      ${DbConstants.colStatus} TEXT NOT NULL DEFAULT 'pending',
      ${DbConstants.colTotalAmount} REAL NOT NULL DEFAULT 0,
      ${DbConstants.colPaidAmount} REAL NOT NULL DEFAULT 0,
      ${DbConstants.colPaymentStatus} TEXT NOT NULL DEFAULT 'unpaid',
      ${DbConstants.colNotes} TEXT,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL,
      FOREIGN KEY (${DbConstants.colRestaurantId}) REFERENCES ${DbConstants.tableRestaurants}(${DbConstants.colId}) ON DELETE RESTRICT
    )
  ''';

  static const String createOrderItemsTable = '''
    CREATE TABLE ${DbConstants.tableOrderItems} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colOrderId} TEXT NOT NULL,
      ${DbConstants.colProductId} TEXT NOT NULL,
      ${DbConstants.colProductName} TEXT NOT NULL,
      ${DbConstants.colUnit} TEXT NOT NULL,
      ${DbConstants.colQuantity} REAL NOT NULL,
      ${DbConstants.colUnitPrice} REAL NOT NULL,
      ${DbConstants.colSubtotal} REAL NOT NULL,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      FOREIGN KEY (${DbConstants.colOrderId}) REFERENCES ${DbConstants.tableOrders}(${DbConstants.colId}) ON DELETE CASCADE,
      FOREIGN KEY (${DbConstants.colProductId}) REFERENCES ${DbConstants.tableProducts}(${DbConstants.colId}) ON DELETE RESTRICT
    )
  ''';

  static const String createInventoryTransactionsTable = '''
    CREATE TABLE ${DbConstants.tableInventoryTransactions} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colProductId} TEXT NOT NULL,
      ${DbConstants.colType} TEXT NOT NULL,
      ${DbConstants.colQuantity} REAL NOT NULL,
      ${DbConstants.colStockBefore} REAL NOT NULL,
      ${DbConstants.colStockAfter} REAL NOT NULL,
      ${DbConstants.colReferenceType} TEXT,
      ${DbConstants.colReferenceId} TEXT,
      ${DbConstants.colNotes} TEXT,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      FOREIGN KEY (${DbConstants.colProductId}) REFERENCES ${DbConstants.tableProducts}(${DbConstants.colId}) ON DELETE RESTRICT
    )
  ''';

  static const String createPaymentsTable = '''
    CREATE TABLE ${DbConstants.tablePayments} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colRestaurantId} TEXT NOT NULL,
      ${DbConstants.colOrderId} TEXT,
      ${DbConstants.colAmount} REAL NOT NULL,
      ${DbConstants.colMethod} TEXT NOT NULL,
      ${DbConstants.colPaymentDate} TEXT NOT NULL,
      ${DbConstants.colNotes} TEXT,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      FOREIGN KEY (${DbConstants.colRestaurantId}) REFERENCES ${DbConstants.tableRestaurants}(${DbConstants.colId}) ON DELETE CASCADE,
      FOREIGN KEY (${DbConstants.colOrderId}) REFERENCES ${DbConstants.tableOrders}(${DbConstants.colId}) ON DELETE SET NULL
    )
  ''';

  static const String createAppSettingsTable = '''
    CREATE TABLE ${DbConstants.tableAppSettings} (
      ${DbConstants.colKey} TEXT PRIMARY KEY,
      ${DbConstants.colValue} TEXT NOT NULL
    )
  ''';

  // Indexes
  static const List<String> createIndexes = [
    // Restaurants indexes
    'CREATE INDEX idx_restaurants_name ON ${DbConstants.tableRestaurants}(${DbConstants.colName})',
    'CREATE INDEX idx_restaurants_active ON ${DbConstants.tableRestaurants}(${DbConstants.colIsActive})',
    
    // Products indexes
    'CREATE INDEX idx_products_name ON ${DbConstants.tableProducts}(${DbConstants.colName})',
    'CREATE INDEX idx_products_sku ON ${DbConstants.tableProducts}(${DbConstants.colSku})',
    'CREATE INDEX idx_products_category ON ${DbConstants.tableProducts}(${DbConstants.colCategory})',
    'CREATE INDEX idx_products_stock ON ${DbConstants.tableProducts}(${DbConstants.colCurrentStock}, ${DbConstants.colMinStockAlert})',
    
    // Restaurant prices indexes
    'CREATE INDEX idx_restaurant_prices_restaurant ON ${DbConstants.tableRestaurantPrices}(${DbConstants.colRestaurantId})',
    'CREATE INDEX idx_restaurant_prices_product ON ${DbConstants.tableRestaurantPrices}(${DbConstants.colProductId})',
    
    // Orders indexes
    'CREATE INDEX idx_orders_restaurant ON ${DbConstants.tableOrders}(${DbConstants.colRestaurantId})',
    'CREATE INDEX idx_orders_order_date ON ${DbConstants.tableOrders}(${DbConstants.colOrderDate})',
    'CREATE INDEX idx_orders_delivery_date ON ${DbConstants.tableOrders}(${DbConstants.colDeliveryDate})',
    'CREATE INDEX idx_orders_status ON ${DbConstants.tableOrders}(${DbConstants.colStatus})',
    'CREATE INDEX idx_orders_payment_status ON ${DbConstants.tableOrders}(${DbConstants.colPaymentStatus})',
    
    // Order items indexes
    'CREATE INDEX idx_order_items_order ON ${DbConstants.tableOrderItems}(${DbConstants.colOrderId})',
    'CREATE INDEX idx_order_items_product ON ${DbConstants.tableOrderItems}(${DbConstants.colProductId})',
    
    // Inventory transactions indexes
    'CREATE INDEX idx_inventory_product ON ${DbConstants.tableInventoryTransactions}(${DbConstants.colProductId})',
    'CREATE INDEX idx_inventory_type ON ${DbConstants.tableInventoryTransactions}(${DbConstants.colType})',
    'CREATE INDEX idx_inventory_created ON ${DbConstants.tableInventoryTransactions}(${DbConstants.colCreatedAt})',
    'CREATE INDEX idx_inventory_reference ON ${DbConstants.tableInventoryTransactions}(${DbConstants.colReferenceType}, ${DbConstants.colReferenceId})',
    
    // Payments indexes
    'CREATE INDEX idx_payments_restaurant ON ${DbConstants.tablePayments}(${DbConstants.colRestaurantId})',
    'CREATE INDEX idx_payments_order ON ${DbConstants.tablePayments}(${DbConstants.colOrderId})',
    'CREATE INDEX idx_payments_date ON ${DbConstants.tablePayments}(${DbConstants.colPaymentDate})',
    'CREATE INDEX idx_payments_created ON ${DbConstants.tablePayments}(${DbConstants.colCreatedAt})',
  ];

  // Default settings
  static const List<Map<String, String>> defaultSettings = [
    {'key': 'company_name', 'value': ''},
    {'key': 'company_phone', 'value': ''},
    {'key': 'company_address', 'value': ''},
    {'key': 'default_delivery_days', 'value': '1'},
  ];
}
