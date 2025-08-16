// lib/widgets/film_reel_pill.dart
import 'package:flutter/material.dart';

class FilmReelPill extends StatelessWidget {
  final String text;
  final Color color;          // base color (we apply opacity inside)
  final double fontSize;
  final double pillHeight;
  final double horizontalPadding;

  const FilmReelPill({
    super.key,
    required this.text,
    required this.color,
    required this.fontSize,
    required this.pillHeight,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: pillHeight,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4), // Smaller radius for square-ish look
        border: Border.all(
          color: color.computeLuminance() > 0.5 ? Colors.black26 : Colors.white24,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: const Offset(0, 1),
                blurRadius: 2,
                color: Colors.black.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}