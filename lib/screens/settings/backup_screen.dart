import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/database/database_helper.dart';
import '../../services/backup_service.dart';
import '../../services/google_drive_backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final BackupService _backupService;
  final GoogleDriveBackupService _gDriveService = GoogleDriveBackupService();
  
  bool _isLoading = false;
  bool _isSignedIn = false;
  BackupInfo? _lastBackupInfo;
  List<BackupInfo>? _cloudBackups;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _backupService = BackupService(DatabaseHelper.instance);
    _initGoogleDrive();
  }

  Future<void> _initGoogleDrive() async {
    final signedIn = await _gDriveService.trySilentSignIn();
    final lastInfo = await _gDriveService.getLastBackupInfo();
    
    if (mounted) {
      setState(() {
        _isSignedIn = signedIn;
        _lastBackupInfo = lastInfo;
      });
    }

    if (signedIn) {
      _refreshCloudBackups();
    }
  }

  Future<void> _refreshCloudBackups() async {
    try {
      final backups = await _gDriveService.listBackups();
      if (mounted) {
        setState(() => _cloudBackups = backups);
      }
    } catch (e) {
      debugPrint('Failed to list cloud backups: $e');
    }
  }

  // ─── Google Drive Methods ───

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang đăng nhập Google...';
    });

    try {
      final ok = await _gDriveService.signIn();
      if (ok) {
        setState(() {
          _isSignedIn = true;
          _statusMessage = null;
        });
        await _refreshCloudBackups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã đăng nhập: ${_gDriveService.userEmail}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        setState(() => _statusMessage = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng nhập thất bại: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _gDriveService.signOut();
    setState(() {
      _isSignedIn = false;
      _cloudBackups = null;
    });
  }

  Future<void> _uploadBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang tải lên Google Drive...';
    });

    try {
      final info = await _gDriveService.uploadBackup(note: 'Manual backup');
      setState(() {
        _lastBackupInfo = info;
        _statusMessage = null;
      });
      await _refreshCloudBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup thành công! (${info.formattedSize})'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup thất bại: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreFromCloud(BackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục dữ liệu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ Dữ liệu hiện tại sẽ bị thay thế hoàn toàn!',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
            ),
            const SizedBox(height: 12),
            Text('File: ${backup.fileName}'),
            Text('Ngày: ${backup.formattedDate}'),
            Text('Kích thước: ${backup.formattedSize}'),
            const SizedBox(height: 12),
            const Text('Bạn có chắc chắn?'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang tải xuống và khôi phục...';
    });

    try {
      await _gDriveService.restoreBackup(backup.fileId);
      if (mounted) {
        setState(() => _statusMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Khôi phục thành công!'), backgroundColor: AppColors.success),
        );
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Khôi phục thành công'),
            content: const Text('Vui lòng khởi động lại ứng dụng để dữ liệu được cập nhật đầy đủ.'),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Khôi phục thất bại: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCloudBackup(BackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa backup'),
        content: Text('Xóa backup "${backup.fileName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _gDriveService.deleteBackup(backup.fileId);
      await _refreshCloudBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa backup'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── Local Backup Methods ───

  Future<void> _exportLocalBackup() async {
    setState(() => _isLoading = true);
    try {
      await _backupService.shareBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo file backup'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importLocalBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    setState(() => _isLoading = true);

    try {
      final info = await _backupService.getBackupInfo(filePath);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận khôi phục'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⚠️ Dữ liệu hiện tại sẽ bị thay thế!',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
              const SizedBox(height: 12),
              Text('Ngày backup: ${info['exportDate']}'),
              Text('Sản phẩm: ${info['productsCount']}'),
              Text('Nhà hàng: ${info['restaurantsCount']}'),
              Text('Đơn hàng: ${info['ordersCount']}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Khôi phục'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _isLoading = false);
        return;
      }

      await _backupService.importFromFile(filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Khôi phục thành công!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Thành công'),
            content: const Text('Vui lòng khởi động lại ứng dụng.'),
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build UI ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sao lưu & Khôi phục'),
      ),
      body: _isLoading && _statusMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage!, style: const TextStyle(fontSize: 16)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGoogleDriveSection(),
                const SizedBox(height: 24),
                _buildCloudBackupsList(),
                const SizedBox(height: 24),
                _buildLocalBackupSection(),
              ],
            ),
    );
  }

  Widget _buildGoogleDriveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.cloud, color: Colors.blue),
            SizedBox(width: 8),
            Text('Google Drive', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),

        if (!_isSignedIn) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'Đăng nhập Google để tự động sao lưu dữ liệu lên Google Drive',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _signIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Đăng nhập Google'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.success,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _gDriveService.userName ?? 'Google Account',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _gDriveService.userEmail ?? '',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          Card(
            color: Colors.blue.shade50,
            child: const ListTile(
              leading: Icon(Icons.autorenew, color: AppColors.primary),
              title: Text('Tự động sao lưu'),
              subtitle: Text('Luôn bật — tự động backup khi có thay đổi dữ liệu'),
              trailing: Icon(Icons.check_circle, color: AppColors.success),
            ),
          ),
          const SizedBox(height: 8),

          if (_lastBackupInfo != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule, color: Colors.green),
                title: const Text('Lần backup cuối'),
                subtitle: Text(
                  '${_lastBackupInfo!.formattedDate} • ${_lastBackupInfo!.formattedSize}',
                ),
              ),
            ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _uploadBackup,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Sao lưu ngay'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCloudBackupsList() {
    if (!_isSignedIn) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Bản backup trên Drive', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_cloudBackups != null)
              Text('${_cloudBackups!.length}/5', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),

        if (_cloudBackups == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_cloudBackups!.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Chưa có backup nào', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          )
        else
          ...(_cloudBackups!.map((backup) => Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_done, color: Colors.green),
              title: Text(
                backup.formattedDate,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(backup.formattedSize),
              trailing: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'restore',
                    child: Row(
                      children: [
                        Icon(Icons.restore, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Khôi phục'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Xóa'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'restore') _restoreFromCloud(backup);
                  if (value == 'delete') _deleteCloudBackup(backup);
                },
              ),
            ),
          ))),
      ],
    );
  }

  Widget _buildLocalBackupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.phone_android, color: Colors.grey),
            SizedBox(width: 8),
            Text('Backup thủ công (File)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.upload_file, color: AppColors.primary, size: 20),
                ),
                title: const Text('Xuất file JSON'),
                subtitle: const Text('Chia sẻ qua Zalo, email...'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isLoading ? null : _exportLocalBackup,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.download, color: AppColors.warning, size: 20),
                ),
                title: const Text('Nhập file JSON'),
                subtitle: const Text('Khôi phục từ file backup'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isLoading ? null : _importLocalBackup,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Khôi phục sẽ xóa toàn bộ dữ liệu hiện tại và thay thế bằng dữ liệu backup.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
