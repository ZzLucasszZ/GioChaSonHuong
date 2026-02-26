/// App-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Order Manager';
  static const String appVersion = '1.0.0';

  // Default Values
  static const int defaultDeliveryDays = 1;
  
  // Units for products
  static const List<String> productUnits = [
    'kg',
    'g',
    'lít',
    'ml',
    'chai',
    'lon',
    'thùng',
    'hộp',
    'gói',
    'cái',
    'con',
    'bó',
    'chục',
  ];

  // Product categories
  static const List<Map<String, String>> productCategories = [
    {'value': 'meat', 'label': 'Thịt'},
    {'value': 'seafood', 'label': 'Hải sản'},
    {'value': 'vegetable', 'label': 'Rau củ'},
    {'value': 'fruit', 'label': 'Trái cây'},
    {'value': 'spice', 'label': 'Gia vị'},
    {'value': 'drink', 'label': 'Đồ uống'},
    {'value': 'other', 'label': 'Khác'},
  ];

  // Date formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String dbDateFormat = 'yyyy-MM-dd';
  static const String dbDateTimeFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS";
}
