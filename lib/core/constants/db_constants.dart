/// Database table and column name constants
class DbConstants {
  DbConstants._();

  // Database info
  static const String databaseName = 'order_inventory.db';
  static const int databaseVersion = 4;

  // Table names
  static const String tableRestaurants = 'restaurants';
  static const String tableProducts = 'products';
  static const String tableRestaurantPrices = 'restaurant_prices';
  static const String tableOrders = 'orders';
  static const String tableOrderItems = 'order_items';
  static const String tableInventoryTransactions = 'inventory_transactions';
  static const String tablePayments = 'payments';
  static const String tableAppSettings = 'app_settings';

  // Common columns
  static const String colId = 'id';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  // Restaurants columns
  static const String colName = 'name';
  static const String colContactPerson = 'contact_person';
  static const String colPhone = 'phone';
  static const String colAddress = 'address';
  static const String colNotes = 'notes';
  static const String colIsActive = 'is_active';

  // Products columns
  static const String colSku = 'sku';
  static const String colUnit = 'unit';
  static const String colBasePrice = 'base_price';
  static const String colCurrentStock = 'current_stock';
  static const String colMinStockAlert = 'min_stock_alert';
  static const String colCategory = 'category';

  // Restaurant prices columns
  static const String colRestaurantId = 'restaurant_id';
  static const String colProductId = 'product_id';
  static const String colPrice = 'price';

  // Orders columns
  static const String colOrderDate = 'order_date';
  static const String colDeliveryDate = 'delivery_date';
  static const String colSession = 'session';
  static const String colStatus = 'status';
  static const String colTotalAmount = 'total_amount';
  static const String colPaidAmount = 'paid_amount';
  static const String colPaymentStatus = 'payment_status';

  // Order items columns
  static const String colOrderId = 'order_id';
  static const String colProductName = 'product_name';
  static const String colQuantity = 'quantity';
  static const String colUnitPrice = 'unit_price';
  static const String colSubtotal = 'subtotal';

  // Inventory transactions columns
  static const String colType = 'type';
  static const String colStockBefore = 'stock_before';
  static const String colStockAfter = 'stock_after';
  static const String colReferenceType = 'reference_type';
  static const String colReferenceId = 'reference_id';

  // Payments columns
  static const String colAmount = 'amount';
  static const String colMethod = 'method';
  static const String colPaymentDate = 'payment_date';

  // App settings columns
  static const String colKey = 'key';
  static const String colValue = 'value';
}
