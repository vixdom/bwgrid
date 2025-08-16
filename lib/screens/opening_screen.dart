import 'dart:async';
import 'package:flutter/material.dart';

import '../widgets/header.dart';
import '../widgets/primary_button.dart';
import 'game_screen.dart';
import 'options_screen.dart';

class OpeningScreen extends StatelessWidget {
  const OpeningScreen({super.key});

  void _startGame(BuildContext context) {
    Navigator.of(
      context,
    ).push(_NoSwipePageRoute(builder: (_) => const GameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Header(title: 'Bolly Word Grid'),
                  const SizedBox(height: 48),
                  PrimaryButton(
                    text: 'Start Game',
                    onPressed: () => _startGame(context),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: 'Options',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OptionsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(bottom: 16, right: 16, child: _LastUpdatedLabel()),
        ],
      ),
    );
  }
}

class _LastUpdatedLabel extends StatefulWidget {
  @override
  State<_LastUpdatedLabel> createState() => _LastUpdatedLabelState();
}

class _LastUpdatedLabelState extends State<_LastUpdatedLabel> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  String get _formatted {
    final hh = _now.hour.toString().padLeft(2, '0');
    final min = _now.minute.toString().padLeft(2, '0');
    final dd = _now.day.toString().padLeft(2, '0');
    final mon = _now.month.toString().padLeft(2, '0');
    final yy = _now.year.toString().substring(2);
    return '$hh:$min $dd $mon $yy';
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Last updated: $_formatted',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NoSwipePageRoute<T> extends MaterialPageRoute<T> {
  _NoSwipePageRoute({required super.builder});

  @override
  bool get hasScopedWillPopCallback => true;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 0);
}
