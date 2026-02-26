import 'package:intl/intl.dart';

/// Format number to Vietnamese currency
String formatCurrency(int amount) {
  final formatter = NumberFormat('#,###', 'vi_VN');
  return '${formatter.format(amount)}₫';
}

/// Format number without currency symbol
String formatNumber(int amount) {
  final formatter = NumberFormat('#,###', 'vi_VN');
  return formatter.format(amount);
}

/// Parse currency string to number
int? parseCurrency(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
  return int.tryParse(cleaned);
}
