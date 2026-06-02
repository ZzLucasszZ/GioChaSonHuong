import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reusable share preview dialog that shows the message before sharing.
/// Provides options to share, send SMS, send via Zalo, or copy to clipboard.
class SharePreviewDialog extends StatelessWidget {
  final String message;
  final String? subject;

  const SharePreviewDialog({
    super.key,
    required this.message,
    this.subject,
  });

  /// Show the share preview dialog from any screen.
  static Future<void> show(
    BuildContext context, {
    required String message,
    String? subject,
  }) {
    return showDialog(
      context: context,
      builder: (_) => SharePreviewDialog(message: message, subject: subject),
    );
  }

  /// Show a share preview dialog with an explicit confirm button.
  /// Returns [true] when the user taps [confirmLabel], [false/null] otherwise.
  static Future<bool?> showWithConfirm(
    BuildContext context, {
    required String message,
    String? subject,
    String confirmLabel = 'Xác nhận',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => _SharePreviewConfirmDialog(
        message: message,
        subject: subject,
        confirmLabel: confirmLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.preview, size: 22),
          const SizedBox(width: 8),
          const Expanded(child: Text('Xem trước nội dung')),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'Sao chép',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép nội dung'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText(
              message,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            Share.share(message, subject: subject);
          },
          icon: const Icon(Icons.share, size: 18),
          label: const Text('Chia sẻ'),
        ),
      ],
    );
  }

  static Future<void> _sendSMS(BuildContext context, String message) async {
    final uri = Uri(
      scheme: 'sms',
      queryParameters: {'body': message},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Share.share(message);
    }
  }

  static Future<void> _sendZalo(BuildContext context, String message) async {
    final zaloUri = Uri.parse('https://zalo.me');
    if (await canLaunchUrl(zaloUri)) {
      await launchUrl(zaloUri, mode: LaunchMode.externalApplication);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã sao chép nội dung. Dán vào Zalo để gửi.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      Share.share(message);
    } else {
      Share.share(message);
    }
  }
}

/// Variant of SharePreviewDialog with an explicit confirm action.
/// Pops with [true] on confirm, [null/false] on cancel.
class _SharePreviewConfirmDialog extends StatelessWidget {
  final String message;
  final String? subject;
  final String confirmLabel;

  const _SharePreviewConfirmDialog({
    required this.message,
    required this.confirmLabel,
    this.subject,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 22, color: Colors.deepPurple),
          const SizedBox(width: 8),
          const Expanded(child: Text('Xem trước — Share thông minh')),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'Sao chép',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép nội dung')),
              );
            },
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.40,
                ),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      message,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
          onPressed: () {
            Navigator.pop(context, true);
            Share.share(message, subject: subject);
          },
          icon: const Icon(Icons.share, size: 18),
          label: Text(confirmLabel),
        ),
      ],
    );
  }
}
