import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';

import '../core/constants/db_constants.dart';
import '../core/utils/logger.dart';
import '../data/database/database_helper.dart';

/// Google-authenticated HTTP client
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

/// Backup metadata stored locally
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

  String get formattedDate => DateFormat('dd/MM/yyyy HH:mm').format(backupDate.toLocal());
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Service for backing up and restoring database to Google Drive
class GoogleDriveBackupService {
  static const String _backupFolderName = 'OrderInventoryBackups';
  static const String _backupFilePrefix = 'order_inventory_backup_';
  static const int _maxBackupCount = 5; // Keep last 5 backups

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  /// Whether user is signed in
  bool get isSignedIn => _currentUser != null;

  /// Current user's email
  String? get userEmail => _currentUser?.email;

  /// Current user's display name
  String? get userName => _currentUser?.displayName;

  /// Try silent sign-in (for auto-backup)
  Future<bool> trySilentSignIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        await _initDriveApi();
        AppLogger.success('Google Sign-In silent success: ${_currentUser!.email}', tag: 'GDriveBackup');
        return true;
      }
    } catch (e) {
      AppLogger.error('Silent sign-in failed', error: e, tag: 'GDriveBackup');
    }
    return false;
  }

  /// Interactive sign-in
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        await _initDriveApi();
        AppLogger.success('Google Sign-In success: ${_currentUser!.email}', tag: 'GDriveBackup');
        return true;
      }
    } catch (e) {
      AppLogger.error('Sign-in failed', error: e, tag: 'GDriveBackup');
    }
    return false;
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
    AppLogger.info('Google Sign-Out', tag: 'GDriveBackup');
  }

  /// Initialize Drive API client
  Future<void> _initDriveApi() async {
    final auth = await _currentUser!.authentication;
    final client = _GoogleAuthClient({
      'Authorization': 'Bearer ${auth.accessToken}',
    });
    _driveApi = drive.DriveApi(client);
  }

  /// Ensure Drive API is ready (re-auth if needed)
  Future<drive.DriveApi> _ensureDriveApi() async {
    if (_driveApi == null || _currentUser == null) {
      final ok = await trySilentSignIn();
      if (!ok) throw Exception('Chưa đăng nhập Google');
    }
    return _driveApi!;
  }

  /// Get or create the backup folder in Google Drive
  Future<String> _getOrCreateBackupFolder(drive.DriveApi api) async {
    // Search for existing folder
    final folderQuery = await api.files.list(
      q: "name = '$_backupFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    if (folderQuery.files != null && folderQuery.files!.isNotEmpty) {
      return folderQuery.files!.first.id!;
    }

    // Create folder
    final folder = drive.File()
      ..name = _backupFolderName
      ..mimeType = 'application/vnd.google-apps.folder';
    
    final created = await api.files.create(folder);
    AppLogger.success('Created backup folder: ${created.id}', tag: 'GDriveBackup');
    return created.id!;
  }

  /// Upload database backup to Google Drive
  /// Returns BackupInfo on success
  Future<BackupInfo> uploadBackup({String? note}) async {
    final api = await _ensureDriveApi();
    final folderId = await _getOrCreateBackupFolder(api);

    // Get the database file path
    final dbPath = await getDatabasesPath();
    final dbFilePath = p.join(dbPath, DbConstants.databaseName);
    final dbFile = File(dbFilePath);

    if (!await dbFile.exists()) {
      throw Exception('Database file không tồn tại');
    }

    // Close database connections temporarily for clean copy
    // We create a copy to avoid locking issues
    final tempDir = await Directory.systemTemp.createTemp('db_backup');
    final tempFile = File(p.join(tempDir.path, DbConstants.databaseName));
    await dbFile.copy(tempFile.path);

    // Also copy WAL/SHM if they exist (for write-ahead logging)
    final walFile = File('$dbFilePath-wal');
    final shmFile = File('$dbFilePath-shm');
    if (await walFile.exists()) {
      await walFile.copy('${tempFile.path}-wal');
    }
    if (await shmFile.exists()) {
      await shmFile.copy('${tempFile.path}-shm');
    }

    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '$_backupFilePrefix$timestamp.db';
      final fileSize = await tempFile.length();

      // Create file metadata
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId]
        ..description = note ?? 'Auto backup ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}';

      // Upload
      final result = await api.files.create(
        driveFile,
        uploadMedia: drive.Media(
          tempFile.openRead(),
          fileSize,
        ),
        $fields: 'id, name, size, createdTime',
      );

      AppLogger.success('Backup uploaded: ${result.name} (${result.id})', tag: 'GDriveBackup');

      // Clean up old backups
      await _cleanupOldBackups(api, folderId);

      // Save last backup info to app_settings
      final info = BackupInfo(
        fileId: result.id!,
        fileName: result.name!,
        backupDate: DateTime.now(),
        sizeBytes: fileSize,
      );
      await _saveLastBackupInfo(info);

      return info;
    } finally {
      // Clean up temp files
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// List all backups from Google Drive
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

    return result.files!.map((f) => BackupInfo(
      fileId: f.id!,
      fileName: f.name!,
      backupDate: (f.createdTime ?? DateTime.now()).toLocal(),
      sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
    )).toList();
  }

  /// Restore database from a Google Drive backup
  Future<void> restoreBackup(String fileId) async {
    final api = await _ensureDriveApi();

    // Download file
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    // Read all bytes from stream
    final List<int> bytes = [];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    // Close the current database
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.close();

    // Write to database file
    final dbPath = await getDatabasesPath();
    final dbFilePath = p.join(dbPath, DbConstants.databaseName);
    
    // Remove WAL/SHM files first
    final walFile = File('$dbFilePath-wal');
    final shmFile = File('$dbFilePath-shm');
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();

    // Write the backup file
    final dbFile = File(dbFilePath);
    await dbFile.writeAsBytes(bytes);

    AppLogger.success('Database restored from backup: $fileId', tag: 'GDriveBackup');

    // Re-open database (this will trigger migrations if needed)
    await dbHelper.database;
  }

  /// Delete a specific backup from Google Drive
  Future<void> deleteBackup(String fileId) async {
    final api = await _ensureDriveApi();
    await api.files.delete(fileId);
    AppLogger.info('Backup deleted: $fileId', tag: 'GDriveBackup');
  }

  /// Clean up old backups, keeping only the last N
  Future<void> _cleanupOldBackups(drive.DriveApi api, String folderId) async {
    final result = await api.files.list(
      q: "'$folderId' in parents and name contains '$_backupFilePrefix' and trashed = false",
      spaces: 'drive',
      orderBy: 'createdTime desc',
      $fields: 'files(id, name, createdTime)',
    );

    if (result.files == null || result.files!.length <= _maxBackupCount) return;

    // Delete oldest backups beyond max count
    final toDelete = result.files!.sublist(_maxBackupCount);
    for (final file in toDelete) {
      try {
        await api.files.delete(file.id!);
        AppLogger.info('Cleaned up old backup: ${file.name}', tag: 'GDriveBackup');
      } catch (e) {
        AppLogger.warning('Failed to delete old backup ${file.name}: $e', tag: 'GDriveBackup');
      }
    }
  }

  /// Save last backup info to app_settings table
  Future<void> _saveLastBackupInfo(BackupInfo info) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        DbConstants.tableAppSettings,
        {'key': 'last_gdrive_backup', 'value': jsonEncode(info.toJson())},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        DbConstants.tableAppSettings,
        {'key': 'auto_backup_enabled', 'value': 'true'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      AppLogger.warning('Failed to save backup info: $e', tag: 'GDriveBackup');
    }
  }

  /// Get last backup info from app_settings
  Future<BackupInfo?> getLastBackupInfo() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        DbConstants.tableAppSettings,
        where: '"key" = ?',
        whereArgs: ['last_gdrive_backup'],
      );
      if (result.isEmpty) return null;
      final json = jsonDecode(result.first['value'] as String) as Map<String, dynamic>;
      return BackupInfo.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Check if auto-backup is enabled
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

  /// Set auto-backup enabled/disabled
  Future<void> setAutoBackupEnabled(bool enabled) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      DbConstants.tableAppSettings,
      {'key': 'auto_backup_enabled', 'value': enabled ? 'true' : 'false'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Perform auto-backup (silent, only if signed in)
  /// Call this after important operations (create order, payment, etc.)
  /// Backs up immediately on every data change — old backups are auto-cleaned (max 5).
  /// Auto-backup is always on — no toggle needed, just requires Google sign-in.
  Future<void> autoBackup() async {
    try {
      final silentOk = await trySilentSignIn();
      if (!silentOk) return;

      await uploadBackup(note: 'Auto backup');
      AppLogger.success('Auto-backup completed', tag: 'GDriveBackup');
    } catch (e) {
      // Silent fail for auto-backup — don't disrupt user
      AppLogger.warning('Auto-backup failed (silent): $e', tag: 'GDriveBackup');
    }
  }
}
