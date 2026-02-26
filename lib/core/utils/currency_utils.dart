import 'package:intl/intl.dart';

/// Currency formatting utilities
class CurrencyUtils {
  CurrencyUtils._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final NumberFormat _compactFormat = NumberFormat.compactCurrency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final NumberFormat _numberFormat = NumberFormat.decimalPattern('vi_VN');

  /// Format number to currency string (1,000,000₫)
  static String formatCurrency(double? amount) {
    if (amount == null) return '0₫';
    return _currencyFormat.format(amount);
  }

  /// Format number to compact currency (1M₫, 1K₫)
  static String formatCompactCurrency(double? amount) {
    if (amount == null) return '0₫';
    return _compactFormat.format(amount);
  }

  /// Format number with thousand separators (1,000,000)
  static String formatNumber(double? number) {
    if (number == null) return '0';
    
    // Remove decimal if it's a whole number
    if (number == number.roundToDouble()) {
      return _numberFormat.format(number.toInt());
    }
    return _numberFormat.format(number);
  }

  /// Format quantity with unit (10 kg, 5 chai)
  static String formatQuantity(double? quantity, String? unit) {
    if (quantity == null) return '';
    final formattedQty = formatNumber(quantity);
    if (unit == null || unit.isEmpty) return formattedQty;
    return '$formattedQty $unit';
  }

  /// Parse currency string to number
  static double? parseCurrency(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      // Remove currency symbol and thousand separators
      final cleaned = text
          .replaceAll('₫', '')
          .replaceAll('.', '')
          .replaceAll(',', '')
          .trim();
      return double.tryParse(cleaned);
    } catch (e) {
      return null;
    }
  }

  /// Parse number string to double
  static double? parseNumber(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      // Remove thousand separators (both . and ,)
      final cleaned = text.replaceAll('.', '').replaceAll(',', '.').trim();
      return double.tryParse(cleaned);
    } catch (e) {
      return null;
    }
  }

  /// Format price with sign (+1,000₫ or -1,000₫)
  static String formatPriceChange(double? amount) {
    if (amount == null) return '0₫';
    final formatted = formatCurrency(amount.abs());
    return amount >= 0 ? '+$formatted' : '-$formatted';
  }

  /// Format debt status
  static String formatDebt(double totalAmount, double paidAmount) {
    final debt = totalAmount - paidAmount;
    if (debt <= 0) return 'Đã thanh toán';
    return 'Còn nợ ${formatCurrency(debt)}';
  }
}
