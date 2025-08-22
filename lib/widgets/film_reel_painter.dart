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
  // Use a near-full-cell stroke so square caps reach the cell edges
  final stroke = cellSize * 0.98;

    // 1) Found paths first (so active selection sits on top)
    for (final fp in found) {
      if (fp.points.isEmpty) continue;

      // Special case: single-letter word -> draw a full tile pill
      if (fp.points.length == 1) {
        _drawSingleCellPill(canvas, fp.points.first, stroke, fp.color);
      } else {
        final gridPath = _polylineFromGrid(fp.points);
        final revealed = _extractPathByProgress(gridPath, fp.progress.value.clamp(0.0, 1.1));

        _drawFilmReelStrip(
          canvas: canvas,
          path: revealed,
          stroke: stroke,
          baseColor: fp.color,
          surfaceColor: surfaceColor,
          isActive: false,
        );
      }
    }

    // 2) Active (in‑progress) path
    if (activeColor != null && activePath.isNotEmpty) {
      if (activePath.length == 1) {
        _drawSingleCellPill(canvas, activePath.first, stroke, activeColor!);
      } else {
        final gridPath = _polylineFromGrid(activePath);
        _drawFilmReelStrip(
          canvas: canvas,
          path: gridPath,
          stroke: stroke,
          baseColor: activeColor!,
          surfaceColor: surfaceColor,
          isActive: true,
        );
      }
    }
  }

  /// Convert (row,col) grid Offsets into a canvas Path through cell centers.
  Path _polylineFromGrid(List<Offset> cells) {
    final p = Path();
    for (int i = 0; i < cells.length; i++) {
      final c = _cellCenter(cells[i]);
      if (i == 0) {
        p.moveTo(c.dx, c.dy);
      } else {
        p.lineTo(c.dx, c.dy);
      }
    }
    return p;
  }

  /// Grid (row,col) -> canvas center (x,y). x = col, y = row.
  Offset _cellCenter(Offset gridRC) {
    final row = gridRC.dx; // dx = row
    final col = gridRC.dy; // dy = col
    return Offset(col * cellSize + cellSize / 2, row * cellSize + cellSize / 2);
  }

  /// Draw a gradient “film‑reel” strip with inner band + perforations.
  void _drawFilmReelStrip({
    required Canvas canvas,
    required Path path,
    required double stroke,
    required Color baseColor,
    required Color surfaceColor,
    required bool isActive,
  }) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    // Soft shadow (ensure parent Stack has clipBehavior: Clip.none)
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      // Square caps extend to cover the first/last letter fully
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..strokeWidth = stroke
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.save();
    canvas.translate(0, 1);
    canvas.drawPath(path, shadow);
    canvas.restore();

    // Main strip paint - solid color, transparent
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      // Square ends to look like a cut film strip and cover edges
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..strokeWidth = stroke
      ..color = baseColor.withValues(alpha: isActive ? 0.85 : 0.80);

    // Draw strip
    canvas.drawPath(path, mainPaint);

    // Perforations (surface-colored dots to simulate cut-through)
    _drawPerforations(canvas, path, stroke, surfaceColor);
  }

  // Draw a pill covering the entire tile for single-cell paths
  void _drawSingleCellPill(Canvas canvas, Offset gridRC, double stroke, Color baseColor) {
    final center = _cellCenter(gridRC);
    final rect = Rect.fromCenter(center: center, width: cellSize * 0.98, height: cellSize * 0.98);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.24));
    final paint = Paint()..color = baseColor.withValues(alpha: 0.82);
    canvas.drawRRect(rrect, paint);
  }

  // --- helpers ---

  Path _extractPathByProgress(Path src, double progress) {
    final total = _totalLength(src);
    final target = (progress.clamp(0.0, 1.0)) * total;
    final out = Path();
    double left = target;
    for (final m in src.computeMetrics()) {
      if (left <= 0) break;
      final take = left.clamp(0.0, m.length);
      out.addPath(m.extractPath(0, take), Offset.zero);
      left -= take;
    }
    return out;
  }

  double _totalLength(Path p) {
    double sum = 0;
    for (final m in p.computeMetrics()) {
      sum += m.length;
    }
    return sum;
  }

  void _drawPerforations(Canvas canvas, Path path, double stroke, Color surfaceColor) {
    // Denser sprocket holes along both edges to resemble a film reel
    final spacing = cellSize * 0.35; // more dots per cell length
    final radius = stroke * 0.10; // slightly smaller holes for density
    final hole = Paint()..color = Colors.black.withValues(alpha: 0.25);

    for (final m in path.computeMetrics()) {
      // Staggered start for a more natural pattern
      for (double d = spacing / 3; d < m.length; d += spacing) {
        final t = m.getTangentForOffset(d);
        if (t == null) continue;
        final v = t.vector;
        final len = v.distance == 0 ? 1.0 : v.distance;
        final n = Offset(-v.dy / len, v.dx / len); // normal
        // Place holes near the edge of the stroke
        final p1 = t.position + n * (stroke * 0.42);
        final p2 = t.position - n * (stroke * 0.42);
        canvas.drawCircle(p1, radius, hole);
        canvas.drawCircle(p2, radius, hole);
      }
    }
  }

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