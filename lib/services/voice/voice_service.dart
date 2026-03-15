import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/utils/logger.dart';
import '../../core/utils/vietnamese_utils.dart';
import 'voice_command.dart';
import 'voice_command_parser.dart';

/// Wake word configuration.
class WakeWordConfig {
  /// The assistant's name (used for greeting detection).
  final String assistantName;

  /// Response template. {name} is replaced with detected caller name.
  final String responseTemplate;

  /// Patterns that trigger wake (normalized, no diacritics).
  /// E.g. ["hi tom", "hey tom", "tom oi"]
  final List<String> wakePatterns;

  const WakeWordConfig({
    this.assistantName = 'Tom',
    this.responseTemplate = '{name} đây, muốn gì nào Bà Hương Giò!',
    this.wakePatterns = const [
      'hi tom', 'hey tom', 'hello tom', 'tom oi',
      'a tom', 'alo tom', 'chao tom',
      // Common Vietnamese STT misrecognitions
      'hai tom', 'hai tum', 'hi tum', 'high tom',
      'he tom', 'he lo tom', 'helo tom',
      'tom', // just saying "Tom" alone
    ],
  });

  /// Check if text contains a wake phrase. Returns true if matched.
  bool isWakePhrase(String rawText) {
    final normalized = normalizeForSearch(rawText.trim());
    // Check contains (handles extra words like "hi Tom đi")
    // Also check each word for just "tom" alone
    return wakePatterns.any((p) => normalized.contains(p));
  }

  /// Build the response string.
  String buildResponse() {
    return responseTemplate.replaceAll('{name}', assistantName);
  }
}

/// Wraps [SpeechToText] + [FlutterTts] to provide Vietnamese
/// speech recognition with wake word greeting flow.
///
/// 2-phase flow:
/// 1. Listen for wake word ("Hi Tom") → TTS responds
/// 2. Listen for actual command → parse & execute
class VoiceService {
  static const String _tag = 'VoiceService';
  static const String _localeId = 'vi_VN';

  /// Platform channel to mute/unmute Android media streams
  /// so the STT "ting" beep is silenced when listening starts.
  static const _audioChannel = MethodChannel(
    'com.example.order_inventory_app/audio',
  );

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final VoiceCommandParser _parser = VoiceCommandParser();
  final WakeWordConfig wakeConfig;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _ttsInitialized = false;

  /// Tracks whether a final result was delivered in the current session.
  /// Prevents onStatus('done') from triggering a false timeout after
  /// a result has already been delivered to the caller.
  bool _finalResultDelivered = false;

  /// Active callback for listening state changes, forwarded from
  /// onStatus/onError handlers set in [initialize].
  void Function(bool isListening)? _activeOnListeningChanged;

  /// Whether speech recognition is available on this device.
  bool get isAvailable => _isInitialized;

  /// Whether currently listening for speech.
  bool get isListening => _isListening;

  VoiceService({this.wakeConfig = const WakeWordConfig()});

  /// Initialize speech recognition + TTS. Must be called before listening.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          // Log only — do NOT forward to _activeOnListeningChanged here.
          // Transient errors (error_no_match, error_speech_timeout) fire
          // onError but don't necessarily end the session (especially with
          // cancelOnError: false). Session end is reliably signaled by
          // onStatus('done'/'notListening') which we handle below.
          AppLogger.warning('Speech error: ${error.errorMsg}', tag: _tag);
        },
        onStatus: (status) {
          AppLogger.info('Speech status: $status', tag: _tag);
          if ((status == 'done' || status == 'notListening') &&
              _isListening &&
              !_finalResultDelivered) {
            _isListening = false;
            _activeOnListeningChanged?.call(false);
          }
        },
      );

      if (_isInitialized) {
        final locales = await _speech.locales();
        final hasVietnamese = locales.any((l) => l.localeId.startsWith('vi'));
        if (!hasVietnamese) {
          AppLogger.warning(
            'Vietnamese locale not found. Available: '
            '${locales.map((l) => l.localeId).take(10).join(", ")}',
            tag: _tag,
          );
        } else {
          AppLogger.success('Vietnamese speech recognition available', tag: _tag);
        }
      } else {
        AppLogger.warning('Speech recognition not available on this device', tag: _tag);
      }

      // Initialize TTS
      if (!_ttsInitialized) {
        // Check available languages
        final languages = await _tts.getLanguages as List;
        final hasViTts = languages.any(
          (l) => l.toString().toLowerCase().startsWith('vi'),
        );
        if (!hasViTts) {
          AppLogger.warning(
            'Vietnamese TTS not available. Languages: '
            '${languages.take(10).join(", ")}',
            tag: _tag,
          );
        }

        await _tts.setLanguage('vi-VN');
        await _tts.setSpeechRate(0.5);
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
        await _tts.awaitSpeakCompletion(true);
        _ttsInitialized = true;
        AppLogger.success('TTS initialized (vi available: $hasViTts)', tag: _tag);
      }

      return _isInitialized;
    } catch (e, stack) {
      AppLogger.error('Failed to initialize', error: e, stackTrace: stack, tag: _tag);
      return false;
    }
  }

  /// Speak text using TTS. Returns a Future that completes when done speaking.
  Future<void> speak(String text) async {
    if (!_ttsInitialized) {
      AppLogger.warning('TTS not initialized, cannot speak', tag: _tag);
      return;
    }

    try {
      AppLogger.info('TTS speaking: "$text"', tag: _tag);

      // Ensure audio is unmuted — the wake word listener or a previous
      // STT session may have muted streams and haven't restored yet.
      await _unmuteBeep();

      // Small delay to let audio session release from STT
      await Future.delayed(const Duration(milliseconds: 150));

      // awaitSpeakCompletion(true) was set in initialize(),
      // so this await will wait until speech finishes.
      final result = await _tts.speak(text);
      AppLogger.info('TTS speak result: $result', tag: _tag);

      // Extra safety buffer after TTS finishes
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e, stack) {
      AppLogger.error('TTS speak failed', error: e, stackTrace: stack, tag: _tag);
    }
  }

  /// Stop TTS immediately.
  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  /// Listen for raw speech (no command parsing).
  /// Used for wake word detection phase.
  Future<void> listenRaw({
    required void Function(String finalText, double confidence) onFinal,
    void Function(String partialText)? onPartial,
    void Function(bool isListening)? onListeningChanged,
    Duration listenFor = const Duration(seconds: 6),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        AppLogger.warning('Cannot listenRaw: not initialized', tag: _tag);
        onListeningChanged?.call(false);
        return;
      }
    }

    if (_isListening) await stopListening();

    // Release audio resources from TTS and previous STT sessions
    // to ensure the mic is available for the new listen session.
    await _tts.stop();
    await _speech.cancel();

    _finalResultDelivered = false;
    _activeOnListeningChanged = onListeningChanged;
    _isListening = true;
    onListeningChanged?.call(true);

    // Mute beep before starting STT
    await _muteBeep();

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (!result.finalResult) {
          onPartial?.call(result.recognizedWords);
        } else {
          _finalResultDelivered = true;
          _isListening = false;
          // Don't call onListeningChanged here — onStatus('done') would
          // double-fire. Setting _isListening=false prevents that handler
          // from triggering, and the caller handles state in onFinal.
          onFinal(result.recognizedWords, result.confidence);
        }
      },
      localeId: _localeId,
      listenFor: listenFor,
      pauseFor: pauseFor,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );

    // Cancel any vibration triggered by STT start
    _cancelVibration();

    // Restore volume after beep window
    Future.delayed(const Duration(milliseconds: 1500), _unmuteBeep);
  }

  /// Listen for a voice command (with parsing).
  /// Used for the command phase after wake word is detected.
  Future<void> startListening({
    required void Function(VoiceCommand command) onCommand,
    void Function(String partialText)? onResult,
    void Function(bool isListening)? onListeningChanged,
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        AppLogger.warning('Cannot start listening: not initialized', tag: _tag);
        onListeningChanged?.call(false);
        return;
      }
    }

    if (_isListening) await stopListening();

    // Stop TTS and cancel stale speech recognition to release
    // Android audio focus. Without this, the recognizer may "start"
    // but the mic captures nothing because TTS still owns the session.
    await _tts.stop();
    await _speech.cancel();
    // Wait for Android AudioManager to fully release audio focus.
    // 250ms is not enough after a TTS utterance — 600ms is reliable.
    await Future.delayed(const Duration(milliseconds: 600));

    _finalResultDelivered = false;
    _activeOnListeningChanged = onListeningChanged;
    _isListening = true;
    onListeningChanged?.call(true);
    AppLogger.info('Start listening for command...', tag: _tag);

    // Mute beep before starting STT
    await _muteBeep();

    try {
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final text = result.recognizedWords;

        if (!result.finalResult) {
          onResult?.call(text);
        } else {
          AppLogger.info('Final speech: "$text" (confidence: ${result.confidence})', tag: _tag);
          _finalResultDelivered = true;
          _isListening = false;
          // Don't call onListeningChanged here — onStatus('done') would
          // double-fire. Setting _isListening=false prevents that handler.
          final command = _parser.parse(text, confidence: result.confidence);
          AppLogger.info('Parsed: $command', tag: _tag);
          onCommand(command);
        }
      },
      localeId: _localeId,
      listenFor: listenFor,
      pauseFor: pauseFor,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        // Use cancelOnError: false so transient errors (error_no_match)
        // don't kill the session. The engine keeps listening and the
        // user has the full listenFor window to speak their command.
        cancelOnError: false,
      ),
    );
    } catch (e) {
      AppLogger.error('_speech.listen() failed: $e', tag: _tag);
      _isListening = false;
      _activeOnListeningChanged?.call(false);
      return;
    }

    // Cancel any vibration triggered by STT start
    _cancelVibration();

    // Restore volume after beep window
    Future.delayed(const Duration(milliseconds: 1500), _unmuteBeep);
  }

  // ─── AUDIO MUTING ─────────────────────────────────────────

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

  /// Stop listening.
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      _activeOnListeningChanged = null;
      AppLogger.info('Stopped listening', tag: _tag);
    }
  }

  /// Cancel current listening session.
  Future<void> cancel() async {
    await _speech.cancel();
    _isListening = false;
    _activeOnListeningChanged = null;
  }

  /// Dispose resources.
  void dispose() {
    _speech.cancel();
    _tts.stop();
    _isListening = false;
    _isInitialized = false;
    _activeOnListeningChanged = null;
  }
}
