import 'package:flutter/material.dart';

class MiniGameScreen extends StatelessWidget {
  const MiniGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini Game'),
      ),
      body: const Center(
        child: Text('Mini Game Coming Soon!'),
      ),
    );
  }
}
