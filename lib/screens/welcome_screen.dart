import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Opening screen for BollyWord Grid.
/// Recreates the cinema background, responsive 9×9 poster grid,
/// vertical “BOLLYWORD”, horizontal “GRID” as 4 gold tiles,
/// and a golden film reel that visually “embraces” the vertical word.
// Quick-tweak config
const bool kShowReel = true;
const double kReelOpacity = 0.8;
const double kReelScale = 0.38; // relative to gridH
const bool kShowAmbientGlows = false; // keep page-level only
const bool kShowTaglineChip = false; // historically used; keep flag, render plain now

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // If you already use your own AppBar elsewhere, you can remove this.
  appBar: AppBar(
  backgroundColor: Colors.black.withOpacity(0.25),
        elevation: 0,
        title: const Text('BollyWord Grid'),
        actions: [
          IconButton(
            tooltip: 'Awards',
            onPressed: () {},
            icon: const Icon(Icons.emoji_events_outlined),
          ),
        ],
      ),
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
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Poster (grid + letters + reel)
                  const _PosterCard(),
                  const SizedBox(height: 16),

      // Tagline plain (no chip)
      Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset('assets/images/sparkle.svg',
                          width: 18, height: 18, colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn)),
                      const SizedBox(width: 8),
                      Text(
                        'Lights, Camera, Action!',
                        style: GoogleFonts.poppins(
  color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SvgPicture.asset('assets/images/sparkle.svg',
                          width: 18, height: 18, colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn)),
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

                  const Spacer(),
                  // Footer
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'v1.0 • Copyright Appzaro',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                ],
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

/// Poster card (responsive)
class _PosterCard extends StatelessWidget {
  const _PosterCard();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        // Poster max width for phones, stays centered
        final maxW = math.min(constraints.maxWidth, 520.0);
        return Center(
          child: Container(
            width: maxW,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0B0D).withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 18)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _PosterInner(width: maxW - 24), // minus padding
          ),
        );
      },
    );
  }
}

class _PosterInner extends StatelessWidget {
  const _PosterInner({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    // Grid config
    const rows = 9;
    const cols = 9;
    // Desired visual padding (in cells)
    const innerPadCells = 1.0;

    // Compute cell size to fit inside width with padding L/R
    final cell = _snapToDevicePixels(width / (cols + innerPadCells * 2));
    final gridW = cell * cols;
    final gridH = cell * rows;
    final pad = _snapToDevicePixels(cell * innerPadCells);

    // Words
    const verticalWord = ['B', 'O', 'L', 'L', 'Y', 'W', 'O', 'R', 'D'];
    const horizontalWord = ['G', 'R', 'I', 'D'];

  final centerCol = cols ~/ 2; // 4
  final horizRow = rows - 1; // bottom row -> 8
  final horizStartCol = centerCol - (horizontalWord.length - 1); // 1

    return SizedBox(
      width: gridW + pad * 2,
      height: gridH + pad * 2,
      child: Stack(
        children: [
          // Grid (thin) via CustomPainter
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(
                rows: rows,
                cols: cols,
                cell: cell,
                color: const Color(0xFF7A6BFF).withValues(alpha: 0.15),
              ),
            ),
          ),
          // Film reel overlay (between grid and letters, optional)
          if (kShowReel)
            Positioned(
              left: pad + centerCol * cell - (gridH * kReelScale) * .55,
              top: pad + gridH * .22,
              child: IgnorePointer(
                ignoring: true,
                child: Opacity(
                  opacity: kReelOpacity,
                  child: SvgPicture.asset(
                    'assets/images/filmreel.svg',
                    width: gridH * kReelScale,
                    height: gridH * kReelScale,
          // Use currentColor via SvgTheme; fallback to amber
          colorFilter: null,
          theme: const SvgTheme(currentColor: Colors.amber),
                  ),
                ),
              ),
            ),
          // Bold axes on top: center column + bottom row
          // Center column
          Positioned(
            left: pad + centerCol * cell - .5,
            top: pad,
            width: 1,
            height: gridH,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF7A6BFF).withValues(alpha: 0.35),
              ),
            ),
          ),
          // Bottom row
          Positioned(
            left: pad,
            top: pad + (rows - 1) * cell - .5,
            width: gridW,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF7A6BFF).withValues(alpha: 0.35),
              ),
            ),
          ),

          // Letters & gold tiles
          // Vertical BOLLYWORD
          for (var r = 0; r < verticalWord.length; r++)
            Positioned(
              left: pad + centerCol * cell,
              top: pad + r * cell,
              width: cell,
              height: cell,
              child: Center(
                child: Text(
                  verticalWord[r],
                  style: GoogleFonts.bungee(
                    color: Colors.white,
                    fontSize: cell * .56,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

          // Horizontal GRID as 4 gold tiles, ending at center column (D at cross)
          for (var i = 0; i < horizontalWord.length; i++)
            Positioned(
              left: pad + (horizStartCol + i) * cell,
              top: pad + horizRow * cell,
              width: cell,
              height: cell,
              child: _GoldTile(letter: horizontalWord[i], fontSize: cell * .48),
            ),
        ],
      ),
    );
  }
}

class _GoldTile extends StatelessWidget {
  const _GoldTile({required this.letter, required this.fontSize});
  final String letter;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
        borderRadius: BorderRadius.all(Radius.circular(10)),
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
  _GridPainter({
    required this.rows,
    required this.cols,
    required this.cell,
    required this.color,
  });

  final int rows;
  final int cols;
  final double cell;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
  // In this painter, we cover the entire area; start lines at 0.
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    // Vertical lines
    for (var c = 0; c <= cols; c++) {
      final x = _snapToDevicePixels(c * cell);
      canvas.drawLine(Offset(x, 0), Offset(x, rows * cell), paint);
    }

    // Horizontal lines
    for (var r = 0; r <= rows; r++) {
      final y = _snapToDevicePixels(r * cell);
      canvas.drawLine(Offset(0, y), Offset(cols * cell, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.cols != cols ||
        oldDelegate.cell != cell ||
        oldDelegate.color != color;
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
          backgroundColor: Colors.black.withOpacity(.30),
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