import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../data/database/database_helper.dart';
import '../../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final BackupService _backupService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _backupService = BackupService(DatabaseHelper.instance);
  }

  Future<void> _exportBackup() async {
    setState(() => _isLoading = true);

    try {
      await _backupService.shareBackup();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tạo file backup thành công'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi backup: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _importBackup() async {
    // Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) {
      return;
    }

    final filePath = result.files.single.path!;

    setState(() => _isLoading = true);

    try {
      // Get backup info first
      final info = await _backupService.getBackupInfo(filePath);
      
      if (!mounted) return;

      // Show confirmation dialog with info
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận khôi phục dữ liệu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dữ liệu hiện tại sẽ bị xóa và thay thế bằng dữ liệu backup.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Thông tin backup:'),
              const SizedBox(height: 8),
              Text('Ngày backup: ${info['exportDate']}'),
              Text('Sản phẩm: ${info['productsCount']}'),
              Text('Nhà hàng: ${info['restaurantsCount']}'),
              Text('Đơn hàng: ${info['ordersCount']}'),
              const SizedBox(height: 16),
              const Text('Bạn có chắc chắn muốn tiếp tục?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text('Khôi phục'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _isLoading = false);
        return;
      }

      // Import data
      await _backupService.importFromFile(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Khôi phục dữ liệu thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Go back and recommend restart
        Navigator.pop(context);
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Thành công'),
            content: const Text('Dữ liệu đã được khôi phục. Vui lòng khởi động lại ứng dụng để cập nhật đầy đủ.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi khôi phục: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sao lưu & Khôi phục'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info card
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              'Thông tin',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sao lưu sẽ bao gồm tất cả dữ liệu: sản phẩm, nhà hàng, đơn hàng, và giao dịch kho.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Export section
                const Text(
                  'Sao lưu dữ liệu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.upload_file, color: AppColors.primary),
                    ),
                    title: const Text('Xuất file backup'),
                    subtitle: const Text('Tạo file JSON chứa toàn bộ dữ liệu'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _exportBackup,
                  ),
                ),
                const SizedBox(height: 24),

                // Import section
                const Text(
                  'Khôi phục dữ liệu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.download, color: AppColors.warning),
                    ),
                    title: const Text('Nhập file backup'),
                    subtitle: const Text('Khôi phục dữ liệu từ file JSON'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _importBackup,
                  ),
                ),
                const SizedBox(height: 16),

                // Warning
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Lưu ý: Khôi phục dữ liệu sẽ xóa toàn bộ dữ liệu hiện tại và thay thế bằng dữ liệu từ file backup.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
