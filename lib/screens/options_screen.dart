import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/feedback_settings.dart';
import '../services/feedback_controller.dart';

class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FeedbackSettings>();
  final controller = context.watch<FeedbackController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Options')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('booya!'),
            SwitchListTile(
              title: const Text('Sound'),
              value: settings.soundEnabled,
              onChanged: (v) {
                settings.setSoundEnabled(v);
                controller.onSettingsChanged();
              },
            ),
            const SizedBox(height: 24),
            SoundRow(controller: controller),
            const SizedBox(height: 12),
            _StatusText('Tick', controller.tickReady, controller.tickAssetName, controller.tickDurationMs, controller.tickError),
            _StatusText('Found', controller.foundReady, controller.foundAssetName, controller.foundDurationMs, controller.foundError),
            _StatusText('Invalid', controller.invalidReady, controller.invalidAssetName, controller.invalidDurationMs, controller.invalidError),
            _StatusText('Fireworks', controller.fireworksReady, controller.fireworksAssetName, controller.fireworksDurationMs, controller.fireworksError),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await controller.reinitAll();
              },
              child: const Text('Retry Init'),
            ),
          ],
        ),
      ),
    );
  }
}

// Debug button widget for sound testing
class DebugSoundButton extends StatefulWidget {
  final FeedbackController controller;
  const DebugSoundButton({super.key, required this.controller});

  @override
  State<DebugSoundButton> createState() => _DebugSoundButtonState();
}

class _DebugSoundButtonState extends State<DebugSoundButton> {
  final List<_SoundEvent> events = const [
    _SoundEvent('Tick (select.mp3)', 'playTick'),
    _SoundEvent('Word Found (word_found.mp3)', 'playWordFound'),
    _SoundEvent('Invalid (invalid.mp3)', 'playInvalid'),
    _SoundEvent('Fireworks (fireworks.mp3)', 'playFireworks'),
  ];
  int current = 0;
  bool playing = false;
  String status = '';

  Future<void> _playNext() async {
    setState(() {
      playing = true;
      status = 'Playing: ${events[current].label}';
    });
    final controller = widget.controller;
    switch (events[current].method) {
      case 'playTick':
        await controller.playTick();
        break;
      case 'playWordFound':
        await controller.playWordFound();
        break;
      case 'playInvalid':
        await controller.playInvalid();
        break;
      case 'playFireworks':
        await controller.playFireworks();
        break;
    }
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      current = (current + 1) % events.length;
      playing = false;
      status = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: playing ? null : _playNext,
          child: Text(playing ? 'Playing...' : 'Debug Sounds'),
        ),
        if (status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(status, style: const TextStyle(fontSize: 16)),
          ),
      ],
    );
  }
}

class _SoundEvent {
  final String label;
  final String method;
  const _SoundEvent(this.label, this.method);
}

class SoundRow extends StatelessWidget {
  final FeedbackController controller;
  const SoundRow({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SoundButton(
              label: 'Tick',
              filename: controller.tickAssetName,
              durationMs: controller.tickDurationMs,
              onPressed: () async {
                await controller.stopAll();
                await controller.playTick();
              },
            ),
            const SizedBox(width: 8),
            _SoundButton(
              label: 'Found',
              filename: controller.foundAssetName,
              durationMs: controller.foundDurationMs,
              onPressed: () async {
                await controller.stopAll();
                await controller.playWordFound();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SoundButton(
              label: 'Invalid',
              filename: controller.invalidAssetName,
              durationMs: controller.invalidDurationMs,
              onPressed: () async {
                await controller.stopAll();
                await controller.playInvalid();
              },
            ),
            const SizedBox(width: 8),
            _SoundButton(
              label: 'Fireworks',
              filename: controller.fireworksAssetName,
              durationMs: controller.fireworksDurationMs,
              onPressed: () async {
                await controller.stopAll();
                await controller.playFireworks();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Tap to play. Filename shown below each button.', style: textStyle),
      ],
    );
  }
}

class _SoundButton extends StatelessWidget {
  final String label;
  final String filename;
  final int? durationMs;
  final Future<void> Function() onPressed;
  const _SoundButton({
    required this.label,
    required this.filename,
    required this.durationMs,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          child: Text(label),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 140,
          child: Column(
            children: [
              Text(
                filename,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
              if (durationMs != null)
                Text(
                  '${durationMs}ms',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusText extends StatelessWidget {
  final String label;
  final bool ready;
  final String filename;
  final int? durationMs;
  final String? error;
  const _StatusText(this.label, this.ready, this.filename, this.durationMs, this.error);
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final status = ready ? 'ready' : 'not ready';
    final dur = durationMs != null ? ', ${durationMs}ms' : '';
    final err = error != null ? ' — $error' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('$label: $status ($filename$dur)$err', style: style),
    );
  }
}
