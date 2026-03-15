import 'dart:async';

import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/utils/logger.dart';
import 'voice_service.dart';

/// Always-on background listener for wake word detection.
///
/// Continuously listens in short sessions. When the wake word
/// ("Hi Tom", "Tom ơi", etc.) is detected, fires [onWakeWord].
/// Automatically restarts after timeout/silence.
///
/// Usage:
/// ```dart
/// final listener = WakeWordListener(onWakeWord: () { ... });
/// await listener.start();
/// listener.pause(); // overlay is open
/// listener.resume(); // overlay closed
/// listener.stop();
/// ```
class WakeWordListener {
  static const String _tag = 'WakeWord';
  static const String _localeId = 'vi_VN';

  /// Duration of each listen session before auto-restart.
  /// Longer sessions = fewer restarts = less beep/vibration.
  static const Duration _listenDuration = Duration(seconds: 20);

  /// How long to wait for silence before ending a session.
  static const Duration _pauseFor = Duration(seconds: 5);

  /// Delay before restarting after a session ends (lets recognizer release).
  static const Duration _restartDelay = Duration(seconds: 2);

  /// Errors that are normal (silence / no speech) — just restart quietly.
  static const _silenceErrors = {
    'error_no_match',
    'error_speech_timeout',
  };

  /// Platform channel to mute/unmute the Android media stream
  /// so the STT "ting" beep is silenced during background listening.
  static const _audioChannel = MethodChannel(
    'com.example.order_inventory_app/audio',
  );

  SpeechToText _speech = SpeechToText();
  final WakeWordConfig _config;
  final VoidCallback onWakeWord;

  bool _isInitialized = false;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isListening = false;
  Timer? _restartTimer;

  WakeWordListener({
    required this.onWakeWord,
    WakeWordConfig config = const WakeWordConfig(),
  }) : _config = config;

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;

  /// Initialize speech recognition. Returns true if available.
  Future<bool> _init() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          _isListening = false;
          final msg = error.errorMsg;

          if (_silenceErrors.contains(msg)) {
            // Normal silence — restart quietly
            _scheduleRestart();
            return;
          }

          if (msg == 'error_busy') {
            // Recognizer still busy — wait longer before retry
            _scheduleRestart(extra: const Duration(seconds: 2));
            return;
          }

          // Genuine error
          AppLogger.warning('Wake word error: $msg', tag: _tag);
          _scheduleRestart(extra: const Duration(seconds: 3));
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            // Session ended — restart if still running.
            // Use a small delay to avoid overlapping with onError.
            _scheduleRestart();
          }
        },
      );

      if (_isInitialized) {
        AppLogger.success('Wake word listener initialized', tag: _tag);
      }
      return _isInitialized;
    } catch (e) {
      AppLogger.error('Wake word init failed: $e', tag: _tag);
      return false;
    }
  }

  /// Start continuous wake word listening.
  Future<void> start() async {
    if (_isRunning) return;

    final ok = await _init();
    if (!ok) return;

    _isRunning = true;
    _isPaused = false;
    AppLogger.info('Wake word listener started', tag: _tag);
    _listen();
  }

  /// Pause listening (e.g. when voice overlay is open).
  void pause() {
    if (!_isRunning) return;
    _isPaused = true;
    _restartTimer?.cancel();
    if (_isListening) {
      _speech.cancel();
      _isListening = false;
    }
    AppLogger.info('Wake word listener paused', tag: _tag);
  }

  /// Resume listening after pause.
  void resume() {
    if (!_isRunning || !_isPaused) return;
    _isPaused = false;

    // CRITICAL: Create a fresh SpeechToText instance.
    // The overlay's VoiceService.initialize() overwrites the static
    // MethodChannel handler, so the old instance is "disconnected".
    _speech = SpeechToText();
    _isInitialized = false;

    AppLogger.info('Wake word listener resumed (re-init)', tag: _tag);
    _scheduleRestart();
  }

  /// Stop listening completely.
  void stop() {
    _isRunning = false;
    _isPaused = false;
    _restartTimer?.cancel();
    if (_isListening) {
      _speech.cancel();
      _isListening = false;
    }
    AppLogger.info('Wake word listener stopped', tag: _tag);
  }

  /// Dispose resources.
  void dispose() {
    stop();
    _isInitialized = false;
  }

  // ─── INTERNAL ─────────────────────────────────────────────

  Future<void> _muteBeep() async {
    try {
      await _audioChannel.invokeMethod('muteBeep');
    } catch (_) {}
  }

  Future<void> _unmuteBeep() async {
    try {
      await _audioChannel.invokeMethod('unmuteBeep');
    } catch (_) {}
  }

  Future<void> _cancelVibration() async {
    try {
      await _audioChannel.invokeMethod('cancelVibration');
    } catch (_) {}
  }

  void _listen() async {
    if (!_isRunning || _isPaused || _isListening) return;

    // Ensure initialized (may need re-init after resume recreates instance)
    if (!_isInitialized) {
      final ok = await _init();
      if (!ok || !_isRunning || _isPaused) return;
    }

    // Clear any stale state, then mute beep & vibration
    await _speech.cancel();
    await _muteBeep();
    // Small delay to ensure mute takes full effect
    await Future.delayed(const Duration(milliseconds: 100));

    _isListening = true;
    _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final text = result.recognizedWords;

        // Guard: _isPaused prevents double-fire when two partial results
        // match the wake phrase in quick succession before cancel takes effect.
        if (text.isNotEmpty && !_isPaused && _config.isWakePhrase(text)) {
          AppLogger.success('Wake word detected: "$text"', tag: _tag);
          // Stop listening before triggering callback
          _speech.cancel();
          _isListening = false;
          _restartTimer?.cancel();
          // Don't auto-restart — the overlay will call resume() when done
          _isPaused = true;
          // Unmute immediately — the 1500ms delayed _unmuteBeep may not
          // have fired yet, and the overlay needs audio for TTS greeting.
          _unmuteBeep();
          onWakeWord();
        }
        // If not wake word, keep listening until session ends naturally.
      },
      localeId: _localeId,
      listenFor: _listenDuration,
      pauseFor: _pauseFor,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        // Don't cancel on "no match" errors — let the session finish
        cancelOnError: false,
      ),
    );

    // Cancel any vibration triggered by STT start
    _cancelVibration();
    Future.delayed(const Duration(milliseconds: 300), _cancelVibration);

    // Restore volume after a longer delay (ensures beep window is over)
    Future.delayed(const Duration(milliseconds: 1500), _unmuteBeep);
  }

  void _scheduleRestart({Duration extra = Duration.zero}) {
    if (!_isRunning || _isPaused) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(_restartDelay + extra, _listen);
  }
}
