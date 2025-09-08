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
      ..color = Colors.black.withOpacity(0.18)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    final shadow2 = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);

    // Base fill with vertical gradient (in local strip coordinates)
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          baseColor.withOpacity(isActive ? 0.90 : 0.80),
          baseColor.withOpacity(isActive ? 0.70 : 0.60),
        ],
      ).createShader(rect);

    // Inner highlight line
    final innerLine = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, stripHeight * 0.04);

    // Border
    final border = Paint()
      ..color = Colors.black.withOpacity(0.22)
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
      ..color = Colors.black.withOpacity(0.35)
      ..strokeWidth = math.max(2.0, stripHeight * 0.08)
      ..strokeCap = StrokeCap.butt;
    final dividerHighlight = Paint()
      ..color = Colors.white.withOpacity(0.16)
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
      ..color = Colors.black.withOpacity(0.40)
      ..style = PaintingStyle.fill;
    final perfShadow = Paint()
      ..color = Colors.black.withOpacity(0.18)
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
      ..color = Colors.white.withOpacity(0.05)
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
        ..color = baseColor.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stripHeight * 0.28
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawRect(rect, glow);
    }

    canvas.restore();
  }

  Path _createStripPath(List<Offset> points) {
    final path = Path();
    
    for (int i = 0; i < points.length; i++) {
      final center = _cellCenter(points[i]);
      
      if (i == 0) {
        path.moveTo(center.dx, center.dy);
      } else {
        // Create smooth curves for direction changes
        final prevCenter = _cellCenter(points[i - 1]);
        final dx = center.dx - prevCenter.dx;
        final dy = center.dy - prevCenter.dy;
        
        // If it's a diagonal or significant direction change, add a curve
        if (dx.abs() > 0 && dy.abs() > 0) {
          final controlPoint = Offset(
            prevCenter.dx + dx * 0.5,
            prevCenter.dy + dy * 0.5,
          );
          path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, center.dx, center.dy);
        } else {
          path.lineTo(center.dx, center.dy);
        }
      }
    }
    
    return path;
  }

  void _drawStripBackground(Canvas canvas, Path stripPath, double stripWidth, Color baseColor, bool isActive) {
    // Multi-layer shadow for depth
    final shadowLayers = [
      (offset: const Offset(0, 2), blur: 3.0, alpha: 0.2),
      (offset: const Offset(0, 4), blur: 6.0, alpha: 0.1),
    ];

    for (final layer in shadowLayers) {
      final shadowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stripWidth
        ..color = Colors.black.withOpacity(layer.alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, layer.blur);

      canvas.save();
      canvas.translate(layer.offset.dx, layer.offset.dy);
      canvas.drawPath(stripPath, shadowPaint);
      canvas.restore();
    }

    // Main film strip with gradient
    final stripPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stripWidth
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          baseColor.withOpacity(isActive ? 0.85 : 0.75),
          baseColor.withOpacity(isActive ? 0.7 : 0.6),
          baseColor.withOpacity(isActive ? 0.8 : 0.7),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, stripWidth, stripWidth));

    canvas.drawPath(stripPath, stripPaint);

    // Inner highlight for 3D effect
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stripWidth * 0.6
      ..color = Colors.white.withOpacity(0.15);

    canvas.drawPath(stripPath, highlightPaint);

    // Outer glow for active strips
    if (isActive) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stripWidth * 1.3
        ..color = baseColor.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      canvas.drawPath(stripPath, glowPaint);
    }
  }

  void _drawFrameDividers(Canvas canvas, List<Offset> points, double stripWidth, Color baseColor) {
    // Two-pass divider: dark core + subtle highlight to mimic bevel
    final dividerCore = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..strokeWidth = math.max(2.0, stripWidth * 0.08)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dividerHighlight = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = math.max(1.0, stripWidth * 0.035)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw dividers between each frame (letter)
    for (int i = 1; i < points.length; i++) {
      final prevCenter = _cellCenter(points[i - 1]);
      final currentCenter = _cellCenter(points[i]);
      
      // Calculate the midpoint between letters
      final midPoint = Offset(
        (prevCenter.dx + currentCenter.dx) / 2,
        (prevCenter.dy + currentCenter.dy) / 2,
      );

      // Calculate perpendicular direction for the divider
      final direction = currentCenter - prevCenter;
      final length = direction.distance;
      if (length > 0) {
        final normalized = direction / length;
        final perpendicular = Offset(-normalized.dy, normalized.dx);
        
        final dividerStart = midPoint + perpendicular * (stripWidth * 0.45);
        final dividerEnd = midPoint - perpendicular * (stripWidth * 0.45);

        // Dark core line
        canvas.drawLine(dividerStart, dividerEnd, dividerCore);

        // Subtle highlight nudged toward one side for a beveled look
        final nudge = perpendicular * (stripWidth * 0.02);
        canvas.drawLine(dividerStart + nudge, dividerEnd + nudge, dividerHighlight);
      }
    }
  }

  /// Draw per-letter “aperture” rectangles on the strip so frames are obvious
  void _drawFrameApertures(Canvas canvas, List<Offset> points, double stripWidth, Color baseColor) {
    // Aperture is a rounded-rect centered at each letter, rotated along the local direction
    final fill = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, stripWidth * 0.035);

    final innerHighlight = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, stripWidth * 0.02);

    for (int i = 0; i < points.length; i++) {
      final center = _cellCenter(points[i]);

      // Determine local direction vector using neighbors
      Offset dir;
      if (points.length == 1) {
        dir = const Offset(1, 0); // arbitrary
      } else if (i == 0) {
        dir = points[i + 1] - points[i];
      } else if (i == points.length - 1) {
        dir = points[i] - points[i - 1];
      } else {
        final d1 = points[i] - points[i - 1];
        final d2 = points[i + 1] - points[i];
        dir = Offset(d1.dx + d2.dx, d1.dy + d2.dy);
      }

      // Convert grid-space direction (row, col) to canvas direction (x=col, y=row)
      final canvasDir = Offset(dir.dy, dir.dx);
      final len = canvasDir.distance;
      final nd = len > 0 ? canvasDir / len : const Offset(1, 0);
      final angle = math.atan2(nd.dy, nd.dx);

      // Aperture size proportional to strip width
      final apertureW = stripWidth * 0.70;
      final apertureH = stripWidth * 0.60;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: apertureW, height: apertureH),
        Radius.circular(stripWidth * 0.10),
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      // Fill
      canvas.drawRRect(rrect, fill);
      // Border
      canvas.drawRRect(rrect, border);
      // Inner highlight inset a touch
      final inset = stripWidth * 0.05;
      final inner = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: apertureW - inset, height: apertureH - inset),
        Radius.circular(stripWidth * 0.08),
      );
      canvas.drawRRect(inner, innerHighlight);

      canvas.restore();
    }
  }

  void _drawContinuousPerforations(Canvas canvas, Path stripPath, double stripWidth) {
    final perfPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    final perfWidth = stripWidth * 0.08;
    final perfHeight = stripWidth * 0.15;
    final perfSpacing = cellSize * 0.25;

    // Draw perforations along both edges of the strip
    for (final pathMetric in stripPath.computeMetrics()) {
      for (double distance = 0; distance < pathMetric.length; distance += perfSpacing) {
        final tangent = pathMetric.getTangentForOffset(distance);
        if (tangent == null) continue;

        final position = tangent.position;
        final direction = tangent.vector;
        final length = direction.distance;
        final normalizedDirection = length > 0 ? direction / length : Offset.zero;
        final perpendicular = Offset(-normalizedDirection.dy, normalizedDirection.dx);

        // Draw perforations on both edges
        for (final side in [-1, 1]) {
          final perfCenter = position + perpendicular * (stripWidth * 0.35 * side);
          
          final perfRect = Rect.fromCenter(
            center: perfCenter,
            width: perfWidth,
            height: perfHeight,
          );

          // Shadow
          canvas.drawRRect(
            RRect.fromRectAndRadius(perfRect.translate(0.5, 0.5), const Radius.circular(1.0)),
            shadowPaint,
          );

          // Main perforation
          canvas.drawRRect(
            RRect.fromRectAndRadius(perfRect, const Radius.circular(1.0)),
            perfPaint,
          );
        }
      }
    }
  }

  void _drawStripTexture(Canvas canvas, Path stripPath, double stripWidth) {
    // Add subtle film grain
    final random = math.Random(42);
    final grainPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final bounds = stripPath.getBounds();
    final grainCount = (bounds.width * bounds.height / 2000).round().clamp(10, 50);

    for (int i = 0; i < grainCount; i++) {
      final x = bounds.left + random.nextDouble() * bounds.width;
      final y = bounds.top + random.nextDouble() * bounds.height;
      final grainSize = random.nextDouble() * 0.8 + 0.3;
      
      canvas.drawCircle(Offset(x, y), grainSize, grainPaint);
    }
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
      ..color = Colors.black.withOpacity(0.3)
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
          baseColor.withOpacity(isActive ? 0.8 : 0.7),
          baseColor.withOpacity(isActive ? 0.6 : 0.5),
          baseColor.withOpacity(isActive ? 0.7 : 0.6),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(frameRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(4)),
      framePaint,
    );

    // Add subtle inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
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
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
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
      ..color = baseColor.withOpacity(isActive ? 0.9 : 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(4)),
      borderPaint,
    );

    // Add subtle outer glow for active frames
    if (isActive) {
      final glowPaint = Paint()
        ..color = baseColor.withOpacity(0.3)
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