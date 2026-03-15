import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/logger.dart';
import '../../services/voice/voice_command.dart';
import '../../services/voice/voice_command_executor.dart';
import '../../services/voice/voice_service.dart';

/// Voice phases for the 2-phase greeting flow.
enum _VoicePhase {
  /// Initializing services.
  initializing,

  /// Phase 1 — Listening for wake word ("Hi Tom").
  waitingGreeting,

  /// Playing TTS greeting response.
  greeting,

  /// Phase 2 — Listening for actual voice command.
  waitingCommand,

  /// Command recognized & being executed.
  executing,

  /// Error state.
  error,
}

/// Full-screen overlay for voice input with 2-phase greeting flow.
///
/// Phase 1: User says a greeting (e.g. "Hi Tom")
/// → App responds via TTS ("Tom đây, muốn gì nào Bà Hương Giò!")
/// Phase 2: User says an actual command → parsed & executed.
///
/// Usage: `VoiceInputOverlay.show(context, switchTab: ...)`
class VoiceInputOverlay extends StatefulWidget {
  final TabSwitcher switchTab;
  final SearchSetter? setSearchQuery;

  /// If true, skip Phase 1 (wake word) and go directly to greeting + Phase 2.
  /// Used when the background wake word listener already detected the wake word.
  final bool skipPhase1;

  const VoiceInputOverlay({
    super.key,
    required this.switchTab,
    this.setSearchQuery,
    this.skipPhase1 = false,
  });

  /// Show the voice input overlay as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required TabSwitcher switchTab,
    SearchSetter? setSearchQuery,
    bool skipPhase1 = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceInputOverlay(
        switchTab: switchTab,
        setSearchQuery: setSearchQuery,
        skipPhase1: skipPhase1,
      ),
    );
  }

  @override
  State<VoiceInputOverlay> createState() => _VoiceInputOverlayState();
}

class _VoiceInputOverlayState extends State<VoiceInputOverlay>
    with TickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();

  _VoicePhase _phase = _VoicePhase.initializing;
  String _recognizedText = '';
  String _greetingResponse = '';
  VoiceCommand? _resultCommand;
  String _feedbackText = '';

  /// How many times Phase 2 has auto-retried on unknown/timeout.
  int _retryCount = 0;
  static const int _maxRetries = 3;

  /// Safety timer — forces retry if STT silently fails to start
  /// (e.g. audio focus not released by TTS).
  Timer? _safetyTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.skipPhase1) {
      // Wake word already detected by background listener — skip to greeting
      _initAndGreet();
    } else {
      _startPhase1();
    }
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _pulseController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Skip Phase 1: Initialize + go straight to greeting → Phase 2
  // ---------------------------------------------------------------------------

  Future<void> _initAndGreet() async {
    setState(() {
      _phase = _VoicePhase.initializing;
      _recognizedText = '';
      _greetingResponse = '';
      _resultCommand = null;
      _feedbackText = '';
    });

    final ok = await _voiceService.initialize();
    if (!ok) {
      if (mounted) {
        setState(() => _phase = _VoicePhase.error);
      }
      return;
    }

    if (!mounted) return;
    _onWakeWordDetected();
  }

  // ---------------------------------------------------------------------------
  // Phase 1: Listen for wake word
  // ---------------------------------------------------------------------------

  Future<void> _startPhase1() async {
    setState(() {
      _phase = _VoicePhase.initializing;
      _recognizedText = '';
      _greetingResponse = '';
      _resultCommand = null;
      _feedbackText = '';
    });

    final ok = await _voiceService.initialize();
    if (!ok) {
      if (mounted) {
        setState(() => _phase = _VoicePhase.error);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _phase = _VoicePhase.waitingGreeting);
    _pulseController.repeat(reverse: true);

    await _voiceService.listenRaw(
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 3),
      onPartial: (text) {
        if (mounted) setState(() => _recognizedText = text);
      },
      onFinal: (text, confidence) {
        if (!mounted) return;
        setState(() => _recognizedText = text);

        if (_voiceService.wakeConfig.isWakePhrase(text)) {
          _onWakeWordDetected();
        } else {
          // Not a wake phrase — show hint and retry
          setState(() {
            _phase = _VoicePhase.error;
            _feedbackText = 'Hãy nói "Hi Tom" để bắt đầu';
          });
        }
      },
      onListeningChanged: (listening) {
        if (mounted && !listening && _phase == _VoicePhase.waitingGreeting) {
          _pulseController.stop();
          // Timeout/error without any final result — show hint
          setState(() {
            _phase = _VoicePhase.error;
            _feedbackText = 'Không nghe thấy, hãy nói "Hi Tom"';
          });
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Transition: TTS greeting response
  // ---------------------------------------------------------------------------

  Future<void> _onWakeWordDetected() async {
    _pulseController.stop();
    final response = _voiceService.wakeConfig.buildResponse();

    setState(() {
      _phase = _VoicePhase.greeting;
      _greetingResponse = response;
    });

    // Speak the greeting
    await _voiceService.speak(response);

    // Move to Phase 2
    if (mounted) _startPhase2();
  }

  // ---------------------------------------------------------------------------
  // Phase 2: Listen for actual command
  // ---------------------------------------------------------------------------

  Future<void> _startPhase2({bool isRetry = false}) async {
    if (!mounted) return;

    if (!isRetry) _retryCount = 0;

    setState(() {
      _phase = _VoicePhase.waitingCommand;
      _recognizedText = '';
      _resultCommand = null;
      if (!isRetry) _feedbackText = '';
    });
    _pulseController.repeat(reverse: true);

    // Safety timeout: if STT silently fails (no onResult, no onListeningChanged)
    // force a retry after listenFor + 3s. Cancelled on any valid callback.
    _safetyTimer?.cancel();
    _safetyTimer = Timer(const Duration(seconds: 13), () {
      if (mounted && _phase == _VoicePhase.waitingCommand) {
        AppLogger.warning('Safety timeout — STT may have failed silently', tag: 'VoiceOverlay');
        _handleListenTimeout();
      }
    });

    await _voiceService.startListening(
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 2),
      onResult: (partialText) {
        if (mounted) setState(() => _recognizedText = partialText);
      },
      onCommand: (command) async {
        if (!mounted) return;
        _safetyTimer?.cancel();
        _pulseController.stop();

        if (command.intent == VoiceIntent.unknown) {
          _retryCount++;

          if (_retryCount >= _maxRetries) {
            // Max retries — show error with manual buttons
            setState(() {
              _recognizedText = command.rawText;
              _resultCommand = command;
              _phase = _VoicePhase.error;
              _feedbackText = 'Chưa hiểu, hãy thử nói cách khác';
            });
            return;
          }

          // Auto-retry: TTS feedback → re-listen
          final msg = command.rawText.isEmpty
              ? 'Tôi không nghe thấy, nói lại đi'
              : 'Chưa hiểu bạn nói gì, nói lại đi';

          setState(() {
            _recognizedText = command.rawText;
            _phase = _VoicePhase.greeting;
            _feedbackText = msg;
          });

          await _voiceService.speak(msg);
          if (mounted) _startPhase2(isRetry: true);
          return;
        }

        setState(() {
          _recognizedText = command.rawText;
          _resultCommand = command;
          _phase = _VoicePhase.executing;
        });

        // Execute the command
        final executor = VoiceCommandExecutor(
          context: context,
          switchTab: widget.switchTab,
          setSearchQuery: widget.setSearchQuery,
        );

        final feedback = await executor.execute(command);

        if (mounted) {
          setState(() => _feedbackText = feedback);

          // Show feedback snackbar while overlay is still alive
          try {
            VoiceCommandExecutor.showFeedback(context, feedback,
                isError: command.intent == VoiceIntent.unknown);
          } catch (_) {}

          // Capture route & navigator before async gap
          final route = ModalRoute.of(context);
          final navigator = Navigator.of(context);

          await Future.delayed(const Duration(milliseconds: 800));

          // Close the overlay by removing its specific route.
          // Using removeRoute instead of pop() because pop() removes the
          // TOPMOST route — which could be a dialog opened by the command
          // (e.g. autoOpenOrder in RestaurantDetailScreen).
          // Wrapped in try-catch: user may have swiped the bottom sheet
          // down during the feedback delay, making the route already gone.
          if (route != null && mounted) {
            try {
              navigator.removeRoute(route);
            } catch (_) {}
          }
        }
      },
      onListeningChanged: (listening) {
        if (mounted) {
          if (listening) {
            _pulseController.repeat(reverse: true);
          } else {
            _safetyTimer?.cancel();
            _pulseController.stop();
            // Session ended without delivering a final result → timed out.
            // For successful commands, onCommand runs first (from onResult)
            // and sets _phase to 'executing' before onStatus fires this.
            if (_phase == _VoicePhase.waitingCommand) {
              _handleListenTimeout();
            }
          }
        }
      },
    );
  }

  /// Handle listen timeout — auto-retry with TTS feedback.
  Future<void> _handleListenTimeout() async {
    _retryCount++;

    if (_retryCount >= _maxRetries) {
      if (mounted) {
        setState(() {
          _phase = _VoicePhase.error;
          _feedbackText = 'Không nghe được, hãy thử lại';
        });
      }
      return;
    }

    const msg = 'Tôi không nghe thấy gì, nói lại đi';
    if (mounted) {
      setState(() {
        _phase = _VoicePhase.greeting;
        _feedbackText = msg;
      });
    }

    await _voiceService.speak(msg);
    if (mounted) _startPhase2(isRetry: true);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Status title
            Text(
              _titleText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _titleColor,
              ),
            ),
            const SizedBox(height: 24),

            // Mic animation
            _buildMicButton(),
            const SizedBox(height: 20),

            // Greeting response (shown after wake word detected)
            if (_phase == _VoicePhase.greeting ||
                _phase == _VoicePhase.waitingCommand ||
                _phase == _VoicePhase.executing)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _greetingResponse,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6A1B9A), // purple accent
                  ),
                ),
              ),

            // Recognized text box
            if (_recognizedText.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"$_recognizedText"',
                      style: const TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (_resultCommand != null &&
                        _resultCommand!.intent != VoiceIntent.unknown) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.success, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _resultCommand!.intent.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            // Placeholder text when nothing recognized yet
            if (_recognizedText.isEmpty && _phase != _VoicePhase.greeting)
              Text(
                _hintText,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),

            const SizedBox(height: 16),

            // Hint chips (only in Phase 2)
            if (_phase == _VoicePhase.waitingCommand) _buildHintChips(),

            // Wake word hint chips (in Phase 1)
            if (_phase == _VoicePhase.waitingGreeting) _buildWakeHintChips(),

            // Retry button
            if (_phase == _VoicePhase.error)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // If we had a greeting (Phase 2 failed), retry just Phase 2
                    if (_greetingResponse.isNotEmpty) ...[
                      OutlinedButton.icon(
                        onPressed: () => _startPhase2(isRetry: false),
                        icon: const Icon(Icons.mic),
                        label: const Text('Nói lại lệnh'),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _startPhase1,
                        child: const Text('Bắt đầu lại'),
                      ),
                    ] else
                      OutlinedButton.icon(
                        onPressed: _startPhase1,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Derived UI values
  // ---------------------------------------------------------------------------

  String get _titleText {
    switch (_phase) {
      case _VoicePhase.initializing:
        return 'Đang khởi tạo...';
      case _VoicePhase.waitingGreeting:
        return 'Chào Tom đi nào! 👋';
      case _VoicePhase.greeting:
        return '🎉';
      case _VoicePhase.waitingCommand:
        return _retryCount > 0
            ? 'Đang nghe lại... ($_retryCount/$_maxRetries)'
            : 'Đang nghe lệnh...';
      case _VoicePhase.executing:
        return _feedbackText.isNotEmpty ? _feedbackText : 'Đã nhận ✓';
      case _VoicePhase.error:
        return _feedbackText.isNotEmpty
            ? _feedbackText
            : 'Không hỗ trợ nhận diện giọng nói';
    }
  }

  Color get _titleColor {
    switch (_phase) {
      case _VoicePhase.error:
        return AppColors.error;
      case _VoicePhase.greeting:
        return const Color(0xFF6A1B9A);
      case _VoicePhase.executing:
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  String get _hintText {
    switch (_phase) {
      case _VoicePhase.waitingGreeting:
        return 'Nói "Hi Tom" để bắt đầu...';
      case _VoicePhase.waitingCommand:
        return 'Nói lệnh bằng tiếng Việt...';
      default:
        return '';
    }
  }

  Color get _micColor {
    switch (_phase) {
      case _VoicePhase.waitingGreeting:
        return const Color(0xFF6A1B9A); // purple for greeting phase
      case _VoicePhase.waitingCommand:
        return AppColors.error; // red pulsing while listening
      case _VoicePhase.greeting:
        return const Color(0xFF6A1B9A);
      case _VoicePhase.executing:
        return AppColors.success;
      case _VoicePhase.error:
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  IconData get _micIcon {
    switch (_phase) {
      case _VoicePhase.waitingGreeting:
      case _VoicePhase.waitingCommand:
        return Icons.mic;
      case _VoicePhase.greeting:
        return Icons.record_voice_over;
      case _VoicePhase.executing:
        return Icons.check;
      case _VoicePhase.error:
        return Icons.mic_off;
      default:
        return Icons.mic_none;
    }
  }

  bool get _isPulsing =>
      _phase == _VoicePhase.waitingGreeting ||
      _phase == _VoicePhase.waitingCommand;

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: () {
        if (_isPulsing) {
          _voiceService.stopListening();
        } else if (_phase == _VoicePhase.error) {
          _startPhase1();
        }
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = _isPulsing ? _pulseAnimation.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _micColor,
                boxShadow: _isPulsing
                    ? [
                        BoxShadow(
                          color: _micColor.withValues(alpha: 0.3),
                          blurRadius: 20 * scale,
                          spreadRadius: 5 * scale,
                        ),
                      ]
                    : null,
              ),
              child: Icon(_micIcon, color: Colors.white, size: 36),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWakeHintChips() {
    const hints = ['Hi Tom', 'Tom ơi', 'Hello Tom'];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: hints
          .map((h) => Chip(
                label: Text(h, style: const TextStyle(fontSize: 11)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                backgroundColor: const Color(0xFFE1BEE7), // light purple
              ))
          .toList(),
    );
  }

  Widget _buildHintChips() {
    const hints = [
      'tạo đơn cho...',
      'nhập kho',
      'thanh toán cho...',
      'giao tất cả',
      'tìm nhà hàng...',
      'xem tồn kho',
      'lịch sử kho',
      'thêm khách thuê',
      'hóa đơn phòng...',
      'sao lưu',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: hints
          .map((h) => Chip(
                label: Text(h, style: const TextStyle(fontSize: 11)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.grey[200],
              ))
          .toList(),
    );
  }
}
