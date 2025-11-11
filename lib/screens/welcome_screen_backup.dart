import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Opening screen for BollyWord Grid.
/// Recreates the cinema background, responsive 9×9 poster grid,
/// vertical “BOLLYWORD”, horizontal “GRID” as 4 gold tiles,
/// and a golden film reel that visually “embraces” the vertical word.
// Quick-tweak config
const bool kShowReel = false; // disabled for clean design
const double kReelOpacity = 0.6;
const double kReelScale = 0.34; // relative to poster height
const bool kShowAmbientGlows = false;

// Screen overlay positioning (adjust these to align with cinema background)
const double kScreenInsetLeftPct = 0.08;  // 8% from left edge
const double kScreenInsetRightPct = 0.08; // 8% from right edge  
const double kScreenTopOffsetPct = 0.16;  // 16% from top to screen area
const double kScreenAspectRatio = 16 / 9;  // movie screen rectangle ratio

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background photo
          Positioned.fill(
            child: Image.asset(
              'assets/images/screen_cropped.png',
              fit: BoxFit.cover,
            ),
          ),
          // Contrast overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.black26, Colors.black87],
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        // Screen overlay (transparent, aligned to cinema screen)
                        const _ScreenOverlay(),
                        const SizedBox(height: 24),

                        // Tagline
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset('assets/images/sparkle.svg',
                                width: 16, height: 16, colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn)),
                            const SizedBox(width: 8),
                            Text(
                              'Lights, Letters, Action!',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 17,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SvgPicture.asset('assets/images/sparkle.svg',
                                width: 16, height: 16, colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn)),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              _PrimaryButton(
                                label: 'Play',
                                icon: Icons.play_arrow_rounded,
                                onTap: () {
                                  Navigator.of(context).pushNamed('/game');
                                },
                              ),
                              const SizedBox(height: 12),
                              _SecondaryButton(
                                label: 'Options',
                                icon: Icons.settings_rounded,
                                onTap: () {
                                  // TODO: navigate to options
                                },
                              ),
                              const SizedBox(height: 12),
                              _SecondaryButton(
                                label: 'Awards',
                                icon: Icons.emoji_events_outlined,
                                onTap: () {
                                  // TODO: navigate to awards
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Footer
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'v1.0 • Copyright 4spire',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Ambient glows (optional, subtle, outside poster)
          if (kShowAmbientGlows) ...[
            Positioned(
              top: MediaQuery.of(context).size.height * .22,
              left: 16,
              child: _Glow(Colors.blue.withValues(alpha: 0.06), 110),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * .30,
              right: 12,
              child: _Glow(Colors.purple.withValues(alpha: 0.06), 90),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * .30,
              left: 28,
              child: _Glow(Colors.orange.withValues(alpha: 0.06), 70),
            ),
          ],
        ],
      ),
    );
  }
}

/// Transparent screen overlay that aligns with cinema background screen area
class _ScreenOverlay extends StatelessWidget {
  const _ScreenOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate overlay dimensions to align with cinema screen
        final deviceWidth = MediaQuery.of(context).size.width;
        final horizontalInset = deviceWidth * (kScreenInsetLeftPct + kScreenInsetRightPct);
        final maxOverlayWidth = math.min(520.0, deviceWidth - horizontalInset);
        final overlayHeight = maxOverlayWidth / kScreenAspectRatio;
        
        return Container(
          width: maxOverlayWidth,
          height: overlayHeight,
          // Transparent - only shows grid and letters, no background image
          child: _ScreenContent(
            width: maxOverlayWidth,
            height: overlayHeight,
          ),
        );
      },
    );
  }
}

class _ScreenContent extends StatelessWidget {
  const _ScreenContent({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Grid config
    const rows = 9;
    const cols = 9;
    
    // Calculate cell size with padding to fit inside screen overlay
    final gridPadding = width * 0.06; // 6% padding on each side
    final availableWidth = width - (gridPadding * 2);
    final cellSize = math.max(availableWidth / cols, 8.0); // Minimum 8dp cell size
    final gridWidth = cellSize * cols;
    final gridHeight = cellSize * rows;
    
    // Center the grid in the overlay
    final leftOffset = (width - gridWidth) / 2;
    final topOffset = (height - gridHeight) / 2;

    // Words positioning
    const verticalWord = ['B', 'O', 'L', 'L', 'Y', 'W', 'O', 'R', 'D'];
    const horizontalWord = ['G', 'R', 'I', 'D'];
    
    final centerCol = cols ~/ 2; // column 4 (0-indexed)
    final bottomRow = rows - 1; // row 8 (0-indexed)
    final horizStartCol = centerCol - (horizontalWord.length - 1); // starts at column 1

    return Stack(
      children: [
        // Grid lines (positioned within overlay)
        Positioned(
          left: leftOffset,
          top: topOffset,
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

        // Film reel (disabled)
        if (kShowReel)
          Positioned(
            left: leftOffset + centerCol * cellSize - (height * kReelScale) * 0.5,
            top: topOffset + height * 0.2,
            child: IgnorePointer(
              child: Opacity(
                opacity: kReelOpacity,
                child: SvgPicture.asset(
                  'assets/images/filmreel.svg',
                  width: height * kReelScale,
                  height: height * kReelScale,
                  colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn),
                ),
              ),
            ),
          ),

        // Vertical BOLLYWORD letters
        for (var r = 0; r < verticalWord.length; r++)
          Positioned(
            left: leftOffset + centerCol * cellSize,
            top: topOffset + r * cellSize,
            width: cellSize,
            height: cellSize,
            child: Center(
              child: Text(
                verticalWord[r],
                style: GoogleFonts.bungee(
                  color: Colors.white,
                  fontSize: math.max(cellSize * 0.5, 8.0), // Minimum 8dp font
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(1, 1)),
                  ],
                ),
              ),
            ),
          ),

        // Horizontal GRID as gold tiles
        for (var i = 0; i < horizontalWord.length; i++)
          Positioned(
            left: leftOffset + (horizStartCol + i) * cellSize,
            top: topOffset + bottomRow * cellSize,
            width: cellSize,
            height: cellSize,
            child: _GoldTile(
              letter: horizontalWord[i], 
              fontSize: math.max(cellSize * 0.44, 8.0), // Minimum 8dp font
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
    // Ensure safe font size bounds
    final safeFontSize = fontSize.clamp(8.0, 36.0);
    
    return Container(
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
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, -1)),
        ],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.bungee(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w900,
            fontSize: safeFontSize,
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
    final basePaint = Paint()
      ..color = baseColor
      ..strokeWidth = 1;
    
    final emphasisPaint = Paint()
      ..color = emphasisColor
      ..strokeWidth = 1;

    // Draw all vertical lines
    for (var c = 0; c <= cols; c++) {
      final x = _snapToDevicePixels(c * cellSize);
      final paint = (c == centerCol) ? emphasisPaint : basePaint;
      canvas.drawLine(Offset(x, 0), Offset(x, rows * cellSize), paint);
    }

    // Draw all horizontal lines
    for (var r = 0; r <= rows; r++) {
      final y = _snapToDevicePixels(r * cellSize);
      final paint = (r == bottomRow) ? emphasisPaint : basePaint;
      canvas.drawLine(Offset(0, y), Offset(cols * cellSize, y), paint);
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
  // Snap to nearest device pixel to keep 1px lines crisp.
  // We assume a typical DPR; Flutter paints in logical pixels, but snapping reduces blur.
  const dpr = 1.0; // Flutter logical px are already device‑independent; we just round halves.
  return (value * dpr).floorToDouble() / dpr;
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
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const StadiumBorder(),
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
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: const StadiumBorder(),
          side: const BorderSide(color: Color(0xFFF39C12), width: 2),
          foregroundColor: const Color(0xFFF39C12),
          backgroundColor: Colors.black.withOpacity(.25),
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

class _Glow extends StatelessWidget {
  const _Glow(this.color, this.size, {super.key});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size)),
    );
  }
}

// Intentionally left empty. Former backup file removed from build to fix analysis errors.