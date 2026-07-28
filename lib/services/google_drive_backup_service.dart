import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_secrets.dart';
import '../core/constants/db_constants.dart';
import '../core/utils/logger.dart';
import '../data/database/database_helper.dart';

// Credentials được load từ app_secrets.dart (gitignored)

final _kScopes = [
  drive.DriveApi.driveFileScope,
  'email',
  'profile',
];

/// True khi chạy trên Windows/Linux/macOS
bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

// ─── Mobile HTTP client wrapper ────────────────────────────────────────────────
class _BearerClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();
  _BearerClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

// ─── BackupInfo ────────────────────────────────────────────────────────────────
class BackupInfo {
  final String fileId;
  final String fileName;
  final DateTime backupDate;
  final int sizeBytes;

  BackupInfo({
    required this.fileId,
    required this.fileName,
    required this.backupDate,
    required this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'fileName': fileName,
        'backupDate': backupDate.toIso8601String(),
        'sizeBytes': sizeBytes,
      };

  factory BackupInfo.fromJson(Map<String, dynamic> json) => BackupInfo(
        fileId: json['fileId'] as String,
        fileName: json['fileName'] as String,
        backupDate: DateTime.parse(json['backupDate'] as String),
        sizeBytes: json['sizeBytes'] as int,
      );

  String get formattedDate =>
      DateFormat('dd/MM/yyyy HH:mm').format(backupDate.toLocal());
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── GoogleDriveBackupService ──────────────────────────────────────────────────
class GoogleDriveBackupService {
  static const String _tag = 'GDriveBackup';
  static const String _backupFolderName = 'OrderInventoryBackups';
  static const String _backupFilePrefix = 'order_inventory_backup_';
  static const int _maxBackupCount = 5;

  // Mobile (Android/iOS)
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _kScopes);
  GoogleSignInAccount? _mobileUser;

  // Desktop (Windows/Linux/macOS)
  auth.AutoRefreshingAuthClient? _desktopClient;
  String? _desktopEmail;
  String? _desktopDisplayName;

  // Shared
  drive.DriveApi? _driveApi;

  bool get isSignedIn => _isDesktop ? _desktopClient != null : _mobileUser != null;
  String? get userEmail => _isDesktop ? _desktopEmail : _mobileUser?.email;
  String? get userName => _isDesktop ? _desktopDisplayName : _mobileUser?.displayName;

  // ─── Public API ──────────────────────────────────────────────────────────────

  Future<bool> trySilentSignIn() async {
    try {
      if (_isDesktop) return await _desktopSilentSignIn();
      return await _mobileSilentSignIn();
    } catch (e) {
      AppLogger.error('Silent sign-in failed', error: e, tag: _tag);
      return false;
    }
  }

  Future<bool> signIn() async {
    try {
      if (_isDesktop) return await _desktopSignIn();
      return await _mobileSignIn();
    } catch (e) {
      AppLogger.error('Sign-in failed', error: e, tag: _tag);
      return false;
    }
  }

  Future<void> signOut() async {
    if (_isDesktop) {
      _desktopClient?.close();
      _desktopClient = null;
      _desktopEmail = null;
      _desktopDisplayName = null;
      await _clearDesktopCredentials();
    } else {
      await _googleSignIn.signOut();
      _mobileUser = null;
    }
    _driveApi = null;
    AppLogger.info('Google Sign-Out', tag: _tag);
  }

  // ─── Mobile impl ─────────────────────────────────────────────────────────────

  Future<bool> _mobileSilentSignIn() async {
    _mobileUser = await _googleSignIn.signInSilently();
    if (_mobileUser != null) {
      await _initMobileDriveApi();
      AppLogger.success('Mobile silent sign-in: ${_mobileUser!.email}', tag: _tag);
      return true;
    }
    return false;
  }

  Future<bool> _mobileSignIn() async {
    _mobileUser = await _googleSignIn.signIn();
    if (_mobileUser != null) {
      await _initMobileDriveApi();
      AppLogger.success('Mobile sign-in: ${_mobileUser!.email}', tag: _tag);
      return true;
    }
    return false;
  }

  Future<void> _initMobileDriveApi() async {
    final authData = await _mobileUser!.authentication;
    _driveApi = drive.DriveApi(_BearerClient(authData.accessToken!));
  }

  // ─── Desktop impl ────────────────────────────────────────────────────────────

  Future<bool> _desktopSilentSignIn() async {
    final stored = await _loadDesktopCredentials();
    if (stored == null) return false;

    final clientId = auth.ClientId(kDesktopGoogleClientId, kDesktopGoogleClientSecret);
    _desktopClient = auth.autoRefreshingClient(
      clientId,
      stored['credentials'] as auth.AccessCredentials,
      http.Client(),
    );
    _desktopEmail = stored['email'] as String?;
    _desktopDisplayName = stored['displayName'] as String?;
    _driveApi = drive.DriveApi(_desktopClient!);
    AppLogger.success('Desktop silent sign-in: $_desktopEmail', tag: _tag);
    return true;
  }

  Future<bool> _desktopSignIn() async {
    final clientId = auth.ClientId(kDesktopGoogleClientId, kDesktopGoogleClientSecret);
    final baseClient = http.Client();

    // Mở trình duyệt, sau đó redirect về localhost để nhận token
    final credentials = await auth.obtainAccessCredentialsViaUserConsent(
      clientId,
      _kScopes,
      baseClient,
      (url) async {
        AppLogger.info('Mở trình duyệt đăng nhập Google...', tag: _tag);
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
    );

    _desktopClient = auth.autoRefreshingClient(clientId, credentials, baseClient);
    _driveApi = drive.DriveApi(_desktopClient!);

    await _fetchDesktopUserInfo();
    await _saveDesktopCredentials(credentials);

    AppLogger.success('Desktop sign-in: $_desktopEmail', tag: _tag);
    return true;
  }

  Future<void> _fetchDesktopUserInfo() async {
    try {
      final res = await _desktopClient!
          .get(Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _desktopEmail = data['email'] as String?;
        _desktopDisplayName = data['name'] as String?;
      }
    } catch (e) {
      AppLogger.warning('Không lấy được user info: $e', tag: _tag);
    }
  }

  Future<void> _saveDesktopCredentials(auth.AccessCredentials creds) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final value = jsonEncode({
        'tokenType': creds.accessToken.type,
        'accessToken': creds.accessToken.data,
        'expiry': creds.accessToken.expiry?.toIso8601String(),
        'refreshToken': creds.refreshToken,
        'scopes': creds.scopes,
        'email': _desktopEmail,
        'displayName': _desktopDisplayName,
      });
      await db.insert(
        DbConstants.tableAppSettings,
        {'key': 'desktop_gdrive_credentials', 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      AppLogger.warning('Lưu credentials thất bại: $e', tag: _tag);
    }
  }

  Future<Map<String, dynamic>?> _loadDesktopCredentials() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        DbConstants.tableAppSettings,
        where: '"key" = ?',
        whereArgs: ['desktop_gdrive_credentials'],
      );
      if (rows.isEmpty) return null;

      final data =
          jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
      final refreshToken = data['refreshToken'] as String?;
      if (refreshToken == null) return null;

      final expiry = data['expiry'] != null
          ? DateTime.parse(data['expiry'] as String)
          : DateTime.now().add(const Duration(hours: 1));

      final credentials = auth.AccessCredentials(
        auth.AccessToken(
          data['tokenType'] as String? ?? 'Bearer',
          data['accessToken'] as String,
          expiry,
        ),
        refreshToken,
        List<String>.from((data['scopes'] as List?) ?? _kScopes),
      );

      return {
        'credentials': credentials,
        'email': data['email'],
        'displayName': data['displayName'],
      };
    } catch (e) {
      AppLogger.warning('Load credentials thất bại: $e', tag: _tag);
      return null;
    }
  }

  Future<void> _clearDesktopCredentials() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        DbConstants.tableAppSettings,
        where: '"key" = ?',
        whereArgs: ['desktop_gdrive_credentials'],
      );
    } catch (e) {
      AppLogger.warning('Xoá credentials thất bại: $e', tag: _tag);
    }
  }

  // ─── Shared Drive helpers ─────────────────────────────────────────────────────

  Future<drive.DriveApi> _ensureDriveApi() async {
    if (_driveApi == null) {
      final ok = await trySilentSignIn();
      if (!ok) throw Exception('Chưa đăng nhập Google');
    }
    return _driveApi!;
  }

  Future<String> _getOrCreateBackupFolder(drive.DriveApi api) async {
    final result = await api.files.list(
      q: "name = '$_backupFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name)',
    );
    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id!;
    }
    final folder = drive.File()
      ..name = _backupFolderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    AppLogger.success('Created backup folder: ${created.id}', tag: _tag);
    return created.id!;
  }

  // ─── Public Drive operations ──────────────────────────────────────────────────

  Future<BackupInfo> uploadBackup({String? note}) async {
    final api = await _ensureDriveApi();
    final folderId = await _getOrCreateBackupFolder(api);

    final dbPath = await getDatabasesPath();
    final dbFilePath = p.join(dbPath, DbConstants.databaseName);
    final dbFile = File(dbFilePath);
    if (!await dbFile.exists()) throw Exception('Database file không tồn tại');

    final tempDir = await Directory.systemTemp.createTemp('db_backup');
    final tempFile = File(p.join(tempDir.path, DbConstants.databaseName));
    await dbFile.copy(tempFile.path);

    final walFile = File('$dbFilePath-wal');
    final shmFile = File('$dbFilePath-shm');
    if (await walFile.exists()) await walFile.copy('${tempFile.path}-wal');
    if (await shmFile.exists()) await shmFile.copy('${tempFile.path}-shm');

    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '$_backupFilePrefix$timestamp.db';
      final fileSize = await tempFile.length();

      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId]
        ..description = note ??
            'Auto backup ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}';

      final result = await api.files.create(
        driveFile,
        uploadMedia: drive.Media(tempFile.openRead(), fileSize),
        $fields: 'id, name, size, createdTime',
      );

      AppLogger.success('Backup uploaded: ${result.name}', tag: _tag);
      await _cleanupOldBackups(api, folderId);

      final info = BackupInfo(
        fileId: result.id!,
        fileName: result.name!,
        backupDate: DateTime.now(),
        sizeBytes: fileSize,
      );
      await _saveLastBackupInfo(info);
      return info;
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<List<BackupInfo>> listBackups() async {
    final api = await _ensureDriveApi();
    final folderId = await _getOrCreateBackupFolder(api);

    final result = await api.files.list(
      q: "'$folderId' in parents and name contains '$_backupFilePrefix' and trashed = false",
      spaces: 'drive',
      orderBy: 'createdTime desc',
      $fields: 'files(id, name, size, createdTime)',
    );

    if (result.files == null) return [];
    return result.files!
        .map((f) => BackupInfo(
              fileId: f.id!,
              fileName: f.name!,
              backupDate: (f.createdTime ?? DateTime.now()).toLocal(),
              sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
            ))
        .toList();
  }

  Future<void> restoreBackup(String fileId) async {
    final api = await _ensureDriveApi();

    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    final dbHelper = DatabaseHelper.instance;
    await dbHelper.close();

    final dbPath = await getDatabasesPath();
    final dbFilePath = p.join(dbPath, DbConstants.databaseName);

    final walFile = File('$dbFilePath-wal');
    final shmFile = File('$dbFilePath-shm');
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();

    await File(dbFilePath).writeAsBytes(bytes);
    AppLogger.success('Database restored from: $fileId', tag: _tag);
    await dbHelper.database;
  }

  Future<void> deleteBackup(String fileId) async {
    final api = await _ensureDriveApi();
    await api.files.delete(fileId);
    AppLogger.info('Backup deleted: $fileId', tag: _tag);
  }

  Future<void> _cleanupOldBackups(drive.DriveApi api, String folderId) async {
    final result = await api.files.list(
      q: "'$folderId' in parents and name contains '$_backupFilePrefix' and trashed = false",
      spaces: 'drive',
      orderBy: 'createdTime desc',
      $fields: 'files(id, name)',
    );
    if (result.files == null || result.files!.length <= _maxBackupCount) return;

    for (final file in result.files!.sublist(_maxBackupCount)) {
      try {
        await api.files.delete(file.id!);
        AppLogger.info('Cleaned up: ${file.name}', tag: _tag);
      } catch (e) {
        AppLogger.warning('Delete old backup failed: $e', tag: _tag);
      }
    }
  }

  // ─── App settings helpers ─────────────────────────────────────────────────────

  Future<void> _saveLastBackupInfo(BackupInfo info) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        DbConstants.tableAppSettings,
        {'key': 'last_gdrive_backup', 'value': jsonEncode(info.toJson())},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      AppLogger.warning('Failed to save backup info: $e', tag: _tag);
    }
  }

  Future<BackupInfo?> getLastBackupInfo() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        DbConstants.tableAppSettings,
        where: '"key" = ?',
        whereArgs: ['last_gdrive_backup'],
      );
      if (result.isEmpty) return null;
      return BackupInfo.fromJson(
        jsonDecode(result.first['value'] as String) as Map<String, dynamic>,
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> isAutoBackupEnabled() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        DbConstants.tableAppSettings,
        where: '"key" = ?',
        whereArgs: ['auto_backup_enabled'],
      );
      if (result.isEmpty) return false;
      return result.first['value'] == 'true';
    } catch (e) {
      return false;
    }
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      DbConstants.tableAppSettings,
      {'key': 'auto_backup_enabled', 'value': enabled ? 'true' : 'false'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Auto-backup sau mỗi thay đổi dữ liệu (silent, không báo lỗi)
  Future<void> autoBackup() async {
    try {
      final ok = await trySilentSignIn();
      if (!ok) return;
      await uploadBackup(note: 'Auto backup');
      AppLogger.success('Auto-backup completed', tag: _tag);
    } catch (e) {
      AppLogger.warning('Auto-backup failed: $e', tag: _tag);
    }
  }
}
