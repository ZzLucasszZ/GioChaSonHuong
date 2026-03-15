import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wake_word_provider.dart';

/// AppBar action button that toggles the "Hi Tom" wake word listener.
/// Reads and writes [WakeWordProvider] from context — no props needed.
class WakeToggleButton extends StatelessWidget {
  const WakeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WakeWordProvider>();
    final enabled = provider.enabled;

    return IconButton(
      icon: Icon(
        enabled ? Icons.hearing : Icons.hearing_disabled,
        color: enabled ? null : Colors.grey.shade400,
      ),
      tooltip: enabled ? 'Tắt lắng nghe giọng nói nền' : 'Bật lắng nghe giọng nói nền (Hi Tom)',
      onPressed: () async {
        await provider.toggle();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              provider.enabled
                  ? 'Đã bật lắng nghe nền — nói "Hi Tom" để ra lệnh'
                  : 'Đã tắt lắng nghe nền',
            ),
            duration: const Duration(seconds: 2),
          ));
        }
      },
    );
  }
}
