import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_persistence.dart';

/// Simple cheat handler: detects a rapid sequence of taps on the disabled Daily
/// Challenge button and prompts for a numeric code. If correct, unlocks all
/// screens using GamePersistence.
class CheatService {
  CheatService._();
  static final CheatService instance = CheatService._();

  static const int _requiredTaps = 5;
  static const Duration _resetAfter = Duration(seconds: 2);
  static const String _cheatCode = '005104';

  int _tapCount = 0;
  DateTime? _lastTap;

  void registerDailyTap(BuildContext context) {
    final now = DateTime.now();
    if (_lastTap == null || now.difference(_lastTap!) > _resetAfter) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;

    if (_tapCount >= _requiredTaps) {
      _tapCount = 0;
      _showCodeDialog(context);
    }
  }

  Future<void> _showCodeDialog(BuildContext context) async {
    final entered = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const _CheatCodeDialog(),
    );

    if (!context.mounted || entered == null) return;

    if (entered == _cheatCode) {
      await const GamePersistence().setAllScreensUnlocked(true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All screens unlocked!')),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect code')),
        );
      }
    }
  }
}

class _CheatCodeDialog extends StatefulWidget {
  const _CheatCodeDialog();

  @override
  State<_CheatCodeDialog> createState() => _CheatCodeDialogState();
}

class _CheatCodeDialogState extends State<_CheatCodeDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter cheat code'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(hintText: '6-digit code'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
