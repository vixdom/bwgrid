import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/selection_controller.dart';

/// Draws rounded “film‑reel” strokes for found words and the active selection.
/// Assumes grid coordinates are stored as Offset(dx=row, dy=col).
class FilmReelPainter extends CustomPainter {
  FilmReelPainter({
    required this.cellSize,
    required this.found,           // List<FoundPath> with: points(List<Offset> grid rc), color(Color), progress(Animation<double>)
    required this.activePath,      // List<Offset> grid rc
    required this.activeColor,     // base color for in-progress gradient (nullable when not dragging)
    required this.surfaceColor,    // EXACT surface behind this painter (for perforation “cut-through”)
    this.debug = false,
    super.repaint,           // pass a merged listenable (controller + all fp.progress)
  });

  final double cellSize;
  final List<FoundPath> found;
  final List<Offset> activePath;
  final Color? activeColor;
  final Color surfaceColor;
  final bool debug;

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Found paths first (so active selection sits on top)
    for (final fp in found) {
      if (fp.points.isEmpty) continue;

      if (fp.points.length == 1) {
        _drawSingleFrame(canvas, fp.points.first, fp.color, false);
      } else {
        _drawConnectedFilmStrip(canvas, fp.points, fp.color, false);
      }
    }

    // 2) Active (in-progress) path
    if (activeColor != null && activePath.isNotEmpty) {
      if (activePath.length == 1) {
        _drawSingleFrame(canvas, activePath.first, activeColor!, true);
      } else {
        _drawConnectedFilmStrip(canvas, activePath, activeColor!, true);
      }
    }
  }

  /// Draw a connected film strip that spans multiple letters
  void _drawConnectedFilmStrip(Canvas canvas, List<Offset> points, Color baseColor, bool isActive) {
    if (points.isEmpty) return;
    _drawRectangularStrip(canvas, points, baseColor, isActive);
  }

  /// Draw a straight-edged rectangular strip aligned to the word direction.
  void _drawRectangularStrip(Canvas canvas, List<Offset> points, Color baseColor, bool isActive) {
    // Geometry in canvas space
    final start = _cellCenter(points.first);
    final end = _cellCenter(points.last);
    final dir = end - start;
    final len = dir.distance;
    final nd = len > 0 ? dir / len : const Offset(1, 0);
    final angle = math.atan2(nd.dy, nd.dx);
    final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

    // Determine step length along the strip between consecutive letter centers.
    // Horizontal/vertical: cellSize; diagonal: cellSize * sqrt(2).
    double stepLength;
    if (points.length >= 2) {
      final c0 = _cellCenter(points[0]);
      final c1 = _cellCenter(points[1]);
      stepLength = (c1 - c0).distance;
    } else {
      stepLength = cellSize;
    }

    // Each frame occupies one step along the strip; total length covers N steps.
    final frameCount = points.length;
    final stripLength = frameCount * stepLength;
    final stripHeight = cellSize; // visual thickness stays one cell

    // Prepare paints
    final rect = Rect.fromCenter(center: Offset.zero, width: stripLength, height: stripHeight);

    // Shadow layers (straight ends)
    final shadow1 = Paint()
      ..color = Colors.black.withValues(alpha: 0.09)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    final shadow2 = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);

    // Base fill with vertical gradient (in local strip coordinates)
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          baseColor.withValues(alpha: isActive ? 0.45 : 0.40),
          baseColor.withValues(alpha: isActive ? 0.35 : 0.30),
        ],
      ).createShader(rect);

    // Inner highlight line
    final innerLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, stripHeight * 0.04);

    // Border
    final border = Paint()
      ..color = Colors.black.withValues(alpha: 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, stripHeight * 0.03);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Shadows
    canvas.save();
    canvas.translate(1.5, 3.0);
    canvas.drawRect(rect, shadow2);
    canvas.restore();
    canvas.save();
    canvas.translate(0.8, 1.6);
    canvas.drawRect(rect, shadow1);
    canvas.restore();

    // Main body
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect.deflate(stripHeight * 0.08), innerLine);
    canvas.drawRect(rect, border);

    // Frame dividers at exact cell boundaries
    final dividerCore = Paint()
      ..color = Colors.black.withValues(alpha: 0.175)
      ..strokeWidth = math.max(2.0, stripHeight * 0.08)
      ..strokeCap = StrokeCap.butt;
    final dividerHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = math.max(1.0, stripHeight * 0.035)
      ..strokeCap = StrokeCap.butt;
    for (int i = 1; i < frameCount; i++) {
      final x = -stripLength / 2 + i * stepLength;
      final p1 = Offset(x, -stripHeight / 2);
      final p2 = Offset(x, stripHeight / 2);
      canvas.drawLine(p1, p2, dividerCore);
      canvas.drawLine(p1.translate(0.6, 0), p2.translate(0.6, 0), dividerHighlight);
    }

    // Perforations along both long edges
    final perfPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    final perfShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.09)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    final perfW = stripHeight * 0.10;
    final perfH = stripHeight * 0.18;
    final margin = stripHeight * 0.12;
    final spacing = cellSize * 0.25;
    final startX = -stripLength / 2 + spacing * 0.5;
    for (double x = startX; x < stripLength / 2; x += spacing) {
      for (final sy in [-1.0, 1.0]) {
        final centerY = sy * (stripHeight / 2 - margin);
        final r = Rect.fromCenter(center: Offset(x, centerY), width: perfW, height: perfH);
        final rr = RRect.fromRectAndRadius(r, const Radius.circular(1.0));
        canvas.drawRRect(rr.shift(const Offset(0.6, 0.6)), perfShadow);
        canvas.drawRRect(rr, perfPaint);
      }
    }

    // Subtle grain within strip bounds
    final random = math.Random(42);
    final grain = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;
    final grains = (stripLength * stripHeight / 2200).round().clamp(10, 60);
    for (int i = 0; i < grains; i++) {
      final gx = -stripLength / 2 + random.nextDouble() * stripLength;
      final gy = -stripHeight / 2 + random.nextDouble() * stripHeight;
      final gr = random.nextDouble() * 0.9 + 0.3;
      canvas.drawCircle(Offset(gx, gy), gr, grain);
    }

    // Active glow
    if (isActive) {
      final glow = Paint()
        ..color = baseColor.withValues(alpha: 0.09)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stripHeight * 0.28
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawRect(rect, glow);
    }

    canvas.restore();
  }

  /// Draw a single film frame over one letter
  void _drawSingleFrame(Canvas canvas, Offset gridRC, Color baseColor, bool isActive) {
    final center = _cellCenter(gridRC);
    final frameSize = cellSize - 5; // Slightly smaller than cell for margin

    // Draw frame background (semi-transparent film base)
    final frameRect = Rect.fromCenter(
      center: center,
      width: frameSize,
      height: frameSize,
    );

    // Multi-layer shadow for depth
    _drawFrameShadow(canvas, frameRect);

    // Main frame with film-like appearance
    _drawFrameBody(canvas, frameRect, baseColor, isActive);

    // Add perforations to the frame
    _drawFramePerforations(canvas, frameRect, baseColor);

    // Add subtle frame border
    _drawFrameBorder(canvas, frameRect, baseColor, isActive);
  }

  void _drawFrameShadow(Canvas canvas, Rect frameRect) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final shadowRect = Rect.fromCenter(
      center: frameRect.center + const Offset(1, 2),
      width: frameRect.width,
      height: frameRect.height,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, const Radius.circular(4)),
      shadowPaint,
    );
  }

  void _drawFrameBody(Canvas canvas, Rect frameRect, Color baseColor, bool isActive) {
    // Film frame body with gradient
    final framePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          baseColor.withValues(alpha: isActive ? 0.40 : 0.35),
          baseColor.withValues(alpha: isActive ? 0.30 : 0.25),
          baseColor.withValues(alpha: isActive ? 0.35 : 0.30),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(frameRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(4)),
      framePaint,
    );

    // Add subtle inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final highlightRect = Rect.fromCenter(
      center: frameRect.center + const Offset(-2, -2),
      width: frameRect.width * 0.6,
      height: frameRect.height * 0.6,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(2)),
      highlightPaint,
    );
  }

  void _drawFramePerforations(Canvas canvas, Rect frameRect, Color baseColor) {
    final perfSize = frameRect.width * 0.08;
    final perfPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    // Top perforations
    final topY = frameRect.top - perfSize * 0.5;
    for (int i = 0; i < 4; i++) {
      final x = frameRect.left + (frameRect.width / 5) * (i + 1);
      final perfRect = Rect.fromCenter(
        center: Offset(x, topY),
        width: perfSize,
        height: perfSize * 1.5,
      );

      // Shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(perfRect.translate(0.5, 0.5), const Radius.circular(0.5)),
        shadowPaint,
      );

      // Main perforation
      canvas.drawRRect(
        RRect.fromRectAndRadius(perfRect, const Radius.circular(0.5)),
        perfPaint,
      );
    }

    // Bottom perforations
    final bottomY = frameRect.bottom + perfSize * 0.5;
    for (int i = 0; i < 4; i++) {
      final x = frameRect.left + (frameRect.width / 5) * (i + 1);
      final perfRect = Rect.fromCenter(
        center: Offset(x, bottomY),
        width: perfSize,
        height: perfSize * 1.5,
      );

      // Shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(perfRect.translate(0.5, 0.5), const Radius.circular(0.5)),
        shadowPaint,
      );

      // Main perforation
      canvas.drawRRect(
        RRect.fromRectAndRadius(perfRect, const Radius.circular(0.5)),
        perfPaint,
      );
    }
  }

  void _drawFrameBorder(Canvas canvas, Rect frameRect, Color baseColor, bool isActive) {
    final borderPaint = Paint()
      ..color = baseColor.withValues(alpha: isActive ? 0.45 : 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(4)),
      borderPaint,
    );

    // Add subtle outer glow for active frames
    if (isActive) {
      final glowPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      canvas.drawRRect(
        RRect.fromRectAndRadius(frameRect, const Radius.circular(4)),
        glowPaint,
      );
    }
  }

  /// Grid (row,col) -> canvas center (x,y). x = col, y = row.
  Offset _cellCenter(Offset gridRC) {
    final row = gridRC.dx; // dx = row
    final col = gridRC.dy; // dy = col
    return Offset(col * cellSize + cellSize / 2, row * cellSize + cellSize / 2);
  }

  // --- helpers ---

  @override
  bool shouldRepaint(covariant FilmReelPainter old) {
    // Reliable, cheap checks; fine-grain is driven by `repaint:`
    final activeChanged = old.activePath.length != activePath.length ||
        (activePath.isNotEmpty && old.activePath.isNotEmpty && old.activePath.last != activePath.last);
    final foundCountChanged = old.found.length != found.length;
    final sizeOrColorChanged = old.cellSize != cellSize ||
        old.activeColor != activeColor ||
        old.surfaceColor != surfaceColor;
    return activeChanged || foundCountChanged || sizeOrColorChanged;
  }
}