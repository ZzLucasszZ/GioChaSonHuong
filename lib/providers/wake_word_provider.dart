import 'package:flutter/foundation.dart';

import '../core/utils/logger.dart';
import '../data/database/database_helper.dart';
import '../data/repositories/settings_repository.dart';
import '../services/voice/wake_word_listener.dart';

/// Manages wake word listener state and persistence.
/// Provided via ChangeNotifierProvider.value inside MainScreen so all tabs can access it.
class WakeWordProvider extends ChangeNotifier {
  late final WakeWordListener _listener;
  final SettingsRepository _settingsRepo;
  bool _enabled = false;
  bool _overlayOpen = false;

  static const _keyEnabled = 'voice_wake_enabled';

  WakeWordProvider({
    required DatabaseHelper dbHelper,
    required VoidCallback onWakeWord,
  }) : _settingsRepo = SettingsRepository(dbHelper) {
    _listener = WakeWordListener(onWakeWord: onWakeWord);
  }

  bool get enabled => _enabled;

  /// Load saved preference and start listener. Call once after first frame.
  Future<void> init() async {
    final val = await _settingsRepo.get(_keyEnabled);
    _enabled = val == '1'; // default: disabled
    notifyListeners();
    if (_enabled) _listener.start();
  }

  /// Toggle on/off and persist.
  Future<void> toggle() async {
    _enabled = !_enabled;
    notifyListeners();
    await _settingsRepo.set(_keyEnabled, _enabled ? '1' : '0');
    if (_enabled) {
      if (!_overlayOpen) _listener.resume();
    } else {
      _listener.pause();
    }
    AppLogger.info('Wake word ${_enabled ? "bật" : "tắt"}', tag: 'WakeWord');
  }

  /// Call when voice overlay opens — pauses listener.
  void onOverlayOpened() {
    _overlayOpen = true;
    _listener.pause();
  }

  /// Call when voice overlay closes — resumes listener if enabled.
  void onOverlayClosed() {
    _overlayOpen = false;
    if (_enabled) _listener.resume();
  }

  /// Call when app goes to background.
  void onBackground() => _listener.pause();

  /// Call when app returns to foreground.
  void onForeground() {
    if (!_overlayOpen && _enabled) _listener.resume();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }
}
