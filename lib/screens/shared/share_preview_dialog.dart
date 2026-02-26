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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // SMS button
            IconButton(
              icon: const Icon(Icons.message, color: Colors.green),
              tooltip: 'Gửi SMS',
              onPressed: () {
                Navigator.pop(context);
                _sendSMS(context, message);
              },
            ),
            // Zalo button
            IconButton(
              icon: Icon(Icons.chat, color: Colors.blue.shade700),
              tooltip: 'Gửi qua Zalo',
              onPressed: () {
                Navigator.pop(context);
                _sendZalo(context, message);
              },
            ),
            const SizedBox(width: 4),
            // Share button
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Share.share(message, subject: subject);
              },
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Chia sẻ'),
            ),
          ],
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
