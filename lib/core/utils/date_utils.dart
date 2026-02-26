import 'package:intl/intl.dart';

/// Date formatting utilities
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _displayDateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _displayDateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _dbDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dbDateTimeFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS");
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _monthYearFormat = DateFormat('MM/yyyy');

  /// Format DateTime to display string (dd/MM/yyyy)
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return _displayDateFormat.format(date);
  }

  /// Format DateTime to display string with time (dd/MM/yyyy HH:mm)
  static String formatDateTime(DateTime? date) {
    if (date == null) return '';
    return _displayDateTimeFormat.format(date);
  }

  /// Format DateTime to time string (HH:mm)
  static String formatTime(DateTime? date) {
    if (date == null) return '';
    return _timeFormat.format(date);
  }

  /// Format DateTime to month/year (MM/yyyy)
  static String formatMonthYear(DateTime? date) {
    if (date == null) return '';
    return _monthYearFormat.format(date);
  }

  /// Format DateTime to database string (yyyy-MM-dd)
  static String toDbDate(DateTime date) {
    return _dbDateFormat.format(date);
  }

  /// Format DateTime to database string with time (ISO8601)
  static String toDbDateTime(DateTime date) {
    return _dbDateTimeFormat.format(date);
  }

  /// Parse database date string to DateTime
  static DateTime? parseDbDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return _dbDateFormat.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// Parse database datetime string to DateTime
  static DateTime? parseDbDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// Get today's date (without time)
  static DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Get tomorrow's date
  static DateTime get tomorrow {
    return today.add(const Duration(days: 1));
  }

  /// Add days to a date
  static DateTime addDays(DateTime date, int days) {
    return date.add(Duration(days: days));
  }

  /// Check if two dates are the same day
  static bool isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) return false;
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Check if date is today
  static bool isToday(DateTime? date) {
    return isSameDay(date, today);
  }

  /// Get start of day
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get end of day
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Get relative time string (hôm nay, hôm qua, etc.)
  static String getRelativeDate(DateTime? date) {
    if (date == null) return '';
    
    final now = today;
    final diff = now.difference(startOfDay(date)).inDays;

    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    if (diff == -1) return 'Ngày mai';
    if (diff > 1 && diff <= 7) return '$diff ngày trước';
    if (diff < -1 && diff >= -7) return '${-diff} ngày nữa';
    
    return formatDate(date);
  }
}
