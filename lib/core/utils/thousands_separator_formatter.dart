import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// TextInputFormatter that automatically adds thousands separators (dots)
/// as the user types. For example: 35673000 → 35.673.000
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###', 'vi_VN');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.tryParse(digitsOnly);
    if (number == null) return oldValue;

    final formatted = _formatter.format(number);

    // Calculate correct cursor position:
    // Count how many digits are before the cursor in the new (unformatted) value,
    // then find the same position in the formatted string.
    final cursorPos = newValue.selection.baseOffset;
    int digitsBeforeCursor = 0;
    for (int i = 0; i < cursorPos && i < newValue.text.length; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    // Walk through formatted string to find where the Nth digit lands
    int newCursorPos = 0;
    int digitCount = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        digitCount++;
      }
      if (digitCount == digitsBeforeCursor) {
        newCursorPos = i + 1;
        break;
      }
    }
    // If we didn't find enough digits, put cursor at end
    if (digitCount < digitsBeforeCursor) {
      newCursorPos = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }
}
