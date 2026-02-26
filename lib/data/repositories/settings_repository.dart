import '../../core/constants/db_constants.dart';
import '../database/database_helper.dart';

/// Repository for app settings
class SettingsRepository {
  final DatabaseHelper _dbHelper;

  SettingsRepository(this._dbHelper);

  /// Get database instance
  Future<dynamic> get database => _dbHelper.database;

  /// Get a setting value by key
  Future<String?> get(String key) async {
    final db = await database;
    final result = await db.query(
      DbConstants.tableAppSettings,
      columns: [DbConstants.colValue],
      where: '${DbConstants.colKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first[DbConstants.colValue] as String?;
  }

  /// Set a setting value
  Future<int> set(String key, String value) async {
    final db = await database;
    final existing = await get(key);
    
    if (existing != null) {
      return await db.update(
        DbConstants.tableAppSettings,
        {DbConstants.colValue: value},
        where: '${DbConstants.colKey} = ?',
        whereArgs: [key],
      );
    } else {
      return await db.insert(
        DbConstants.tableAppSettings,
        {
          DbConstants.colKey: key,
          DbConstants.colValue: value,
        },
      );
    }
  }

  /// Get all settings
  Future<Map<String, String>> getAll() async {
    final db = await database;
    final result = await db.query(DbConstants.tableAppSettings);
    
    final settings = <String, String>{};
    for (final row in result) {
      final key = row[DbConstants.colKey] as String;
      final value = row[DbConstants.colValue] as String;
      settings[key] = value;
    }
    return settings;
  }

  /// Delete a setting
  Future<int> delete(String key) async {
    final db = await database;
    return await db.delete(
      DbConstants.tableAppSettings,
      where: '${DbConstants.colKey} = ?',
      whereArgs: [key],
    );
  }

  // Convenience methods for specific settings

  /// Get company name
  Future<String> getCompanyName() async {
    return await get('company_name') ?? '';
  }

  /// Set company name
  Future<int> setCompanyName(String name) async {
    return await set('company_name', name);
  }

  /// Get company phone
  Future<String> getCompanyPhone() async {
    return await get('company_phone') ?? '';
  }

  /// Set company phone
  Future<int> setCompanyPhone(String phone) async {
    return await set('company_phone', phone);
  }

  /// Get company address
  Future<String> getCompanyAddress() async {
    return await get('company_address') ?? '';
  }

  /// Set company address
  Future<int> setCompanyAddress(String address) async {
    return await set('company_address', address);
  }

  /// Get default delivery days
  Future<int> getDefaultDeliveryDays() async {
    final value = await get('default_delivery_days');
    return int.tryParse(value ?? '1') ?? 1;
  }

  /// Set default delivery days
  Future<int> setDefaultDeliveryDays(int days) async {
    return await set('default_delivery_days', days.toString());
  }

  /// Get company info as map
  Future<Map<String, String>> getCompanyInfo() async {
    return {
      'name': await getCompanyName(),
      'phone': await getCompanyPhone(),
      'address': await getCompanyAddress(),
    };
  }

  /// Set company info from map
  Future<void> setCompanyInfo(Map<String, String> info) async {
    if (info.containsKey('name')) {
      await setCompanyName(info['name']!);
    }
    if (info.containsKey('phone')) {
      await setCompanyPhone(info['phone']!);
    }
    if (info.containsKey('address')) {
      await setCompanyAddress(info['address']!);
    }
  }
}
