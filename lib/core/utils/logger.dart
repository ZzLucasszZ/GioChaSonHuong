import 'package:flutter/foundation.dart';

/// Simple logger utility for the app
class AppLogger {
  static const String _tag = 'OrderInventoryApp';

  /// Log info message
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      print('ℹ️ [${tag ?? _tag}] $message');
    }
  }

  /// Log warning message
  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      print('⚠️ [${tag ?? _tag}] $message');
    }
  }

  /// Log error message with optional error and stack trace
  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    if (kDebugMode) {
      print('❌ [${tag ?? _tag}] $message');
      if (error != null) {
        print('   Error: $error');
      }
      if (stackTrace != null) {
        print('   StackTrace: $stackTrace');
      }
    }
  }

  /// Log debug message (only in debug mode)
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      print('🐛 [${tag ?? _tag}] $message');
    }
  }

  /// Log success message
  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      print('✅ [${tag ?? _tag}] $message');
    }
  }

  /// Log database operation
  static void database(String operation, {String? details}) {
    if (kDebugMode) {
      print('💾 [Database] $operation${details != null ? " - $details" : ""}');
    }
  }

  /// Log API/Repository operation
  static void repository(String operation, {String? details}) {
    if (kDebugMode) {
      print('🔄 [Repository] $operation${details != null ? " - $details" : ""}');
    }
  }

  /// Log payment operation
  static void payment(String operation, {double? amount}) {
    if (kDebugMode) {
      print('💰 [Payment] $operation${amount != null ? " - ${amount.toStringAsFixed(0)}₫" : ""}');
    }
  }

  /// Log navigation
  static void navigation(String screen, {String? from}) {
    if (kDebugMode) {
      print('🧭 [Navigation] ${from != null ? "$from → " : ""}$screen');
    }
  }
}
