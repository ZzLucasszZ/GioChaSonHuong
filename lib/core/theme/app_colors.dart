import 'package:flutter/material.dart';

/// App color palette
class AppColors {
  AppColors._();

  // Primary colors
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color onPrimary = Colors.white;

  // Secondary colors
  static const Color secondary = Color(0xFF26A69A);
  static const Color secondaryLight = Color(0xFF4DB6AC);
  static const Color secondaryDark = Color(0xFF00897B);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF29B6F6);

  // Order status colors
  static const Color statusPending = Color(0xFFFFA726);    // Orange
  static const Color statusConfirmed = Color(0xFF42A5F5);  // Blue
  static const Color statusDelivering = Color(0xFF7E57C2); // Purple
  static const Color statusDelivered = Color(0xFF66BB6A);  // Green
  static const Color statusCancelled = Color(0xFF9E9E9E);  // Grey

  // Order status background colors
  static const Color statusPendingBg = Color(0xFFFFF3E0);    // Light Orange
  static const Color statusConfirmedBg = Color(0xFFE3F2FD);  // Light Blue
  static const Color statusDeliveringBg = Color(0xFFEDE7F6); // Light Purple
  static const Color statusDeliveredBg = Color(0xFFE8F5E9);  // Light Green
  static const Color statusCancelledBg = Color(0xFFF5F5F5);  // Light Grey

  // Payment status colors
  static const Color paymentUnpaid = Color(0xFFF44336);    // Red
  static const Color paymentPartial = Color(0xFFFFA726);   // Orange
  static const Color paymentPaid = Color(0xFF4CAF50);      // Green

  // Stock status colors
  static const Color stockNormal = Color(0xFF4CAF50);      // Green
  static const Color stockLow = Color(0xFFFFA726);         // Orange
  static const Color stockOut = Color(0xFFF44336);         // Red

  // Session colors
  static const Color sessionMorning = Color(0xFFFF9800);   // Orange - Sáng
  static const Color sessionAfternoon = Color(0xFF5C6BC0); // Indigo - Chiều

  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color card = Colors.white;

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Colors.white;

  // Border colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  // Misc
  static const Color shadow = Color(0x1A000000);
  static const Color overlay = Color(0x80000000);
}
