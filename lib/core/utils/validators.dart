/// Input validation utilities
class Validators {
  Validators._();

  /// Validate required field
  static String? required(String? value, [String fieldName = 'Trường này']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName không được để trống';
    }
    return null;
  }

  /// Validate phone number
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Số điện thoại không được để trống';
    }
    
    // Remove spaces and dashes
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    
    // Check if it's all digits
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Số điện thoại không hợp lệ';
    }
    
    // Check length (Vietnamese phone numbers are 10-11 digits)
    if (cleaned.length < 10 || cleaned.length > 11) {
      return 'Số điện thoại phải có 10-11 số';
    }
    
    return null;
  }

  /// Validate email (optional)
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Email is optional
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Email không hợp lệ';
    }
    
    return null;
  }

  /// Validate positive number
  static String? positiveNumber(String? value, [String fieldName = 'Giá trị']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName không được để trống';
    }
    
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null) {
      return '$fieldName phải là số';
    }
    
    if (number < 0) {
      return '$fieldName không được âm';
    }
    
    return null;
  }

  /// Validate number greater than zero
  static String? greaterThanZero(String? value, [String fieldName = 'Giá trị']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName không được để trống';
    }
    
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null) {
      return '$fieldName phải là số';
    }
    
    if (number <= 0) {
      return '$fieldName phải lớn hơn 0';
    }
    
    return null;
  }

  /// Validate non-negative number (allows 0)
  static String? nonNegativeNumber(String? value, [String fieldName = 'Giá trị']) {
    if (value == null || value.trim().isEmpty) {
      return null; // Allow empty for optional fields
    }
    
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null) {
      return '$fieldName phải là số';
    }
    
    if (number < 0) {
      return '$fieldName không được âm';
    }
    
    return null;
  }

  /// Validate SKU (optional, alphanumeric)
  static String? sku(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // SKU is optional
    }
    
    if (!RegExp(r'^[a-zA-Z0-9\-_]+$').hasMatch(value)) {
      return 'Mã SP chỉ được chứa chữ, số, - và _';
    }
    
    if (value.length > 50) {
      return 'Mã SP không được quá 50 ký tự';
    }
    
    return null;
  }

  /// Validate minimum length
  static String? minLength(String? value, int minLen, [String fieldName = 'Trường này']) {
    if (value == null || value.trim().length < minLen) {
      return '$fieldName phải có ít nhất $minLen ký tự';
    }
    return null;
  }

  /// Validate maximum length
  static String? maxLength(String? value, int maxLen, [String fieldName = 'Trường này']) {
    if (value != null && value.trim().length > maxLen) {
      return '$fieldName không được quá $maxLen ký tự';
    }
    return null;
  }

  /// Combine multiple validators
  static String? combine(String? value, List<String? Function(String?)> validators) {
    for (final validator in validators) {
      final result = validator(value);
      if (result != null) return result;
    }
    return null;
  }
}
