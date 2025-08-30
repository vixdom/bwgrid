import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Quick-tweak config
const bool kShowReel = false; // disabled for clean design
const double kGridLineThickness = 2.5; // Increased grid line thickness

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Stack(
        children: [
          // Background photo - full screen
          Positioned.fill(
            child: Image.asset(
              'assets/images/screen_cropped.png',
              fit: BoxFit.cover,
              width: screenSize.width,
              height: screenSize.height,
            ),
          ),
          
          // Content
          Column(
            children: [
              // Grid area (top 60% of screen)
              SizedBox(
                height: screenSize.height * 0.6,
                child: const _PosterCard(),
              ),
              
              // Buttons area (bottom 40% of screen)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PrimaryButton(
                        label: 'Play',
                        icon: Icons.play_arrow,
                        onTap: () {
                          Navigator.of(context).pushNamed('/game');
                        },
                      ),
                      const SizedBox(height: 16),
                      _SecondaryButton(
                        label: 'Options',
                        icon: Icons.settings,
                        onTap: () {
                          Navigator.of(context).pushNamed('/options');
                        },
                      ),
                      const SizedBox(height: 16),
                      const _AwardsButton(),
                      const SizedBox(height: 24),
                      
                      // Tagline
                      Text(
                        '✨ Lights, Letters, Action! ✨',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 17,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const Spacer(),
                      
                      // Copyright footer
                      Text(
                        'v1.0 • Copyright 4spire',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Poster card with cinema screen aspect ratio, anchored to background
class _PosterCard extends StatelessWidget {
  const _PosterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.transparent, // Transparent background
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 18)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        // Match the cinema screen image ratio for consistent anchoring
        aspectRatio: 16 / 9,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _PosterContent(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            );
          },
        ),
      ),
    );
  }
}

class _PosterContent extends StatelessWidget {
  const _PosterContent({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Grid config
    const rows = 9;
    const cols = 9;
    const double gridPadding = 6.0; // Small padding to avoid clipping

    // Fit full 9x9 grid inside the poster with 15% size reduction
    final maxCellByWidth = (width - (gridPadding * 2)) / cols;
    final maxCellByHeight = (height - (gridPadding * 2)) / rows;
  final cellSize = math.min(maxCellByWidth, maxCellByHeight) * 0.8; // 20% smaller grid
    final gridWidth = cellSize * cols;
    final gridHeight = cellSize * rows;

    // Center horizontally, add 15% offset from top plus 80 pixels total
    final gridLeft = (width - gridWidth) / 2;
  final gridTop = gridPadding + 150.0 + 15.0 + 20.0 + 20.0; // moved down by 211px total

    // Words positioning
    const verticalWord = ['B', 'O', 'L', 'L', 'Y', 'W', 'O', 'R', 'D'];
    const horizontalWord = ['G', 'R', 'I', 'D'];

    final centerCol = cols ~/ 2; // column 4 (0-indexed)
    final bottomRow = rows - 1; // row 8 (0-indexed)
    final horizStartCol = centerCol - (horizontalWord.length - 1); // starts at column 1

    return Stack(
      children: [
        // Grid lines
        Positioned(
          left: gridLeft,
          top: gridTop,
          width: gridWidth,
          height: gridHeight,
          child: CustomPaint(
            painter: _GridPainter(
              rows: rows,
              cols: cols,
              cellSize: cellSize,
              baseColor: const Color(0xFF7A6BFF).withValues(alpha: 0.18),
              emphasisColor: const Color(0xFF7A6BFF).withValues(alpha: 0.35),
              centerCol: centerCol,
              bottomRow: bottomRow,
            ),
          ),
        ),

        // Vertical BOLLYWORD letters
        for (var r = 0; r < verticalWord.length; r++)
          Positioned(
            left: gridLeft + centerCol * cellSize,
            top: gridTop + r * cellSize,
            width: cellSize,
            height: cellSize,
            child: Center(
              child: Text(
                verticalWord[r],
                style: GoogleFonts.bungee(
                  color: Colors.white,
                  fontSize: (cellSize * 0.5).clamp(10.0, 32.0),
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1)),
                  ],
                ),
              ),
            ),
          ),

        // Horizontal GRID as gold tiles
        for (var i = 0; i < horizontalWord.length; i++)
          Positioned(
            left: gridLeft + (horizStartCol + i) * cellSize,
            top: gridTop + bottomRow * cellSize,
            width: cellSize,
            height: cellSize,
            child: _GoldTile(
              letter: horizontalWord[i],
              fontSize: (cellSize * 0.45).clamp(10.0, 28.0),
            ),
          ),
      ],
    );
  }
}

class _GoldTile extends StatelessWidget {
  const _GoldTile({required this.letter, required this.fontSize});
  final String letter;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2.0), // Inset to avoid clipping
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFBE7A1),
            Color(0xFFE6B85C),
            Color(0xFFC4822D),
            Color(0xFF8E5E1A),
          ],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
        ],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.bungee(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.rows,
    required this.cols,
    required this.cellSize,
    required this.baseColor,
    required this.emphasisColor,
    required this.centerCol,
    required this.bottomRow,
  });

  final int rows;
  final int cols;
  final double cellSize;
  final Color baseColor;
  final Color emphasisColor;
  final int centerCol;
  final int bottomRow;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5; // Thicker lines

    // Draw vertical lines with increased thickness
    paint.strokeWidth = kGridLineThickness;
    for (int c = 0; c <= cols; c++) {
      paint.color = (c == centerCol || c == centerCol + 1) ? emphasisColor : baseColor;
      final x = _snapToDevicePixels(c * cellSize);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines with increased thickness
    paint.strokeWidth = kGridLineThickness;
    for (int r = 0; r <= rows; r++) {
      paint.color = (r == bottomRow || r == bottomRow + 1) ? emphasisColor : baseColor;
      final y = _snapToDevicePixels(r * cellSize);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.cols != cols ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.emphasisColor != emphasisColor ||
        oldDelegate.centerCol != centerCol ||
        oldDelegate.bottomRow != bottomRow;
  }
}

double _snapToDevicePixels(double value) {
  return (value * 1.0).roundToDouble() / 1.0;
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
          backgroundColor: const Color(0xFFF39C12),
          foregroundColor: Colors.black,
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: Color(0xFFF39C12), width: 2),
          foregroundColor: const Color(0xFFF39C12),
          backgroundColor: Colors.black.withValues(alpha: .25),
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}

class _AwardsButton extends StatelessWidget {
  const _AwardsButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          OutlinedButton(
            onPressed: null, // Disabled button
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.5),
              side: BorderSide(color: Colors.white24, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_outlined, size: 20, color: Colors.white54),
                const SizedBox(width: 10),
                Text(
                  'Awards',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 16,
            child: Text(
              'coming soon',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.amber,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}