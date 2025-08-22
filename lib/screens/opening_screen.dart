import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../services/achievements_service.dart';
import '../models/feedback_settings.dart';

// ...existing code...
import 'package:flutter_svg/flutter_svg.dart';
import 'game_screen.dart';
import 'options_screen.dart';

// Helper functions for safe padding calculations
double clamp0(double v) => v < 0 ? 0 : v;

EdgeInsets safeInsets(double l, double t, double r, double b) =>
    EdgeInsets.fromLTRB(clamp0(l), clamp0(t), clamp0(r), clamp0(b));

class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _GoldPillButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _GoldPillButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black87,
        backgroundColor: const Color(0xFFFFD700),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 4,
  shadowColor: Colors.amber.withValues(alpha: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _GlassOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? leading;

  const _GlassOutlineButton({
    required this.text,
    this.onPressed,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1.0,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white30, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.black.withValues(alpha: 0.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpeningScreenState extends State<OpeningScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intro.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No-op for now; background is static on this screen.
  }

  void _startGame(BuildContext context) {
    Navigator.of(context).push(
      _NoSwipePageRoute(builder: (_) => const GameScreen()),
    );
  }

  // ...existing code...

  @override
  Widget build(BuildContext context) {
  final ach = context.watch<AchievementsService>();
  // Using AchievementsService; reduce-motion hooks removed for now.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Achievements',
            onPressed: ach.isSignedIn
                ? () => context.read<AchievementsService>().showAchievements()
                : null,
            icon: const Text('🏆', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background image + gradient overlay
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/screen_cropped.png',
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black54,
                        Colors.black87,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Foreground content per mock
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Poster card with custom grid and content
                    _PosterCard(intro: _intro),
                    const SizedBox(height: 16),
                    // Tagline with sparkles
                    Opacity(
                      opacity: 0.95,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset('assets/images/sparkle.svg', width: 16, height: 16, colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn)),
                          const SizedBox(width: 8),
                          const Text(
                            'Lights, Camera, Action!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SvgPicture.asset('assets/images/sparkle.svg', width: 16, height: 16, colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Buttons
                    _GoldPillButton(
                      text: 'Play',
                      onPressed: () => _startGame(context),
                    ),
                    const SizedBox(height: 10),
                    _GlassOutlineButton(
                      text: 'Options',
                      leading: SvgPicture.asset('assets/images/sparkle.svg', width: 16, height: 16, colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn)),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OptionsScreen()),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _GlassOutlineButton(
                      text: 'Awards',
                      onPressed: ach.isSignedIn
                          ? () => context.read<AchievementsService>().showAchievements()
                          : null,
                    ),
                    const SizedBox(height: 14),
                    const Opacity(
                      opacity: 0.85,
                      child: Text(
                        'v1.0 • Copyright 4spire.in',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
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

// Poster card with cached grid painter and overlay content
class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.intro});
  final AnimationController intro;

  @override
  Widget build(BuildContext context) {
  final surface = Colors.black.withValues(alpha: 0.2);
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 18, spreadRadius: 2, offset: const Offset(0, 8)),
        ],
  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dpr = MediaQuery.of(context).devicePixelRatio;
              final cardWidth = constraints.maxWidth;
              final cardHeight = constraints.maxHeight;
              // Always fit grid inside card, never overflow
              final gridCols = 9, gridRows = 9;
              // Allow a minimum margin for poster visuals
              const minMargin = 8.0;
              // Compute max cell size that fits both axes
              final maxCellW = (cardWidth - minMargin * 2) / gridCols;
              final maxCellH = (cardHeight - minMargin * 2) / gridRows;
              final cellSize = math.min(maxCellW, maxCellH).clamp(32.0, 56.0);
              final totalGridWidth = cellSize * gridCols;
              final totalGridHeight = cellSize * gridRows;
              // Compute safe horizontal/vertical padding
              final horizontalPadding = math.max(0.0, (cardWidth - totalGridWidth) / 2);
              final verticalPadding = math.max(0.0, (cardHeight - totalGridHeight) / 2);
              final gridPadding = safeInsets(horizontalPadding, verticalPadding, horizontalPadding, verticalPadding);
              // Dev-only logs/asserts
              assert(() {
                if (horizontalPadding < 0.1 || verticalPadding < 0.1) {
                  debugPrint('[PosterCard] Padding is low: h=$horizontalPadding, v=$verticalPadding, card=($cardWidth,$cardHeight), cellSize=$cellSize');
                }
                return true;
              }());
              // Center poster content, never overflow
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: totalGridWidth + horizontalPadding * 2,
                    maxHeight: totalGridHeight + verticalPadding * 2,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Grid painter
                      Padding(
                        padding: gridPadding,
                        child: CustomPaint(
                          painter: _PosterGridPainter(
                            rows: gridRows,
                            cols: gridCols,
                            cellSize: cellSize,
                            strokeWidth: 1.0,
                            boldAxisExtra: 0.5,
                            gridColor: const Color(0xFF7A6BFF),
                            baseOpacity: 0.15,
                            boldOpacity: 0.35,
                            devicePixelRatio: dpr,
                            innerGlow: true,
                          ),
                        ),
                      ),
                      // Film reel embracing vertical text
                      Positioned.fill(
                        child: Padding(
                          padding: gridPadding,
                          child: Stack(children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: SvgPicture.asset(
                                'assets/images/filmreel.svg',
                                width: cellSize * 4.2,
                                colorFilter: const ColorFilter.mode(Color(0xFFE6B85C), BlendMode.srcIn),
                              ),
                            ),
                          ]),
                        ),
                      ),
                      // Vertical BOLLYWORD centered column (col 4 of 0..8)
                      _VerticalWord(
                        word: 'BOLLYWORD',
                        column: 4,
                        cellSize: cellSize,
                        padding: gridPadding,
                      ),
                      // Bottom-left GRID tiles
                      _GridTiles(
                        word: 'GRID',
                        row: 8,
                        startCol: 0,
                        cellSize: cellSize,
                        padding: gridPadding,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PosterGridPainter extends CustomPainter {
  _PosterGridPainter({
    required this.rows,
    required this.cols,
    required this.cellSize,
    required this.strokeWidth,
    required this.boldAxisExtra,
    required this.gridColor,
    required this.baseOpacity,
    required this.boldOpacity,
    required this.devicePixelRatio,
    this.innerGlow = false,
  });

  final int rows, cols;
  final double cellSize;
  final double strokeWidth;
  final double boldAxisExtra;
  final Color gridColor;
  final double baseOpacity;
  final double boldOpacity;
  final double devicePixelRatio;
  final bool innerGlow;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw using pixel-snapped lines for crispness
    final rect = Offset.zero & size;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (strokeWidth * devicePixelRatio).round() / devicePixelRatio
  ..color = gridColor.withValues(alpha: baseOpacity);
    final bold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ((strokeWidth + boldAxisExtra) * devicePixelRatio).round() / devicePixelRatio
  ..color = gridColor.withValues(alpha: boldOpacity);

    // Optional inner glow / printed depth
    if (innerGlow) {
      final glow = Paint()
        ..shader = LinearGradient(
          colors: [gridColor.withValues(alpha: 0.06), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect);
      canvas.drawRect(rect.deflate(1), glow);
    }

    // Grid lines
    for (int r = 0; r <= rows; r++) {
      final y = (r * cellSize).roundToDouble() + 0.5 / devicePixelRatio;
      final p = r == rows ? bold : base;
      canvas.drawLine(Offset(0, y), Offset(cols * cellSize, y), p);
    }
    for (int c = 0; c <= cols; c++) {
      final x = (c * cellSize).roundToDouble() + 0.5 / devicePixelRatio;
      final p = c == (cols / 2).floor() ? bold : base;
      canvas.drawLine(Offset(x, 0), Offset(x, rows * cellSize), p);
    }
  }

  @override
  bool shouldRepaint(covariant _PosterGridPainter old) {
    return old.cellSize != cellSize ||
        old.strokeWidth != strokeWidth ||
        old.boldAxisExtra != boldAxisExtra ||
        old.gridColor != gridColor ||
        old.baseOpacity != baseOpacity ||
        old.boldOpacity != boldOpacity ||
        old.devicePixelRatio != devicePixelRatio ||
        old.rows != rows ||
        old.cols != cols ||
        old.innerGlow != innerGlow;
  }
}

class _VerticalWord extends StatelessWidget {
  const _VerticalWord({
    required this.word,
    required this.column,
    required this.cellSize,
    required this.padding,
  });
  
  final String word;
  final int column;
  final double cellSize;
  final EdgeInsets padding;
  
  @override
  Widget build(BuildContext context) {
    assert(padding.isNonNegative, 'VerticalWord padding must be non-negative');

    final textStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.0,
      fontSize: cellSize * 0.7,
      height: 1.0,
    );
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: cellSize * 9,
          height: cellSize * 9,
          child: Stack(children: [
            for (int i = 0; i < word.length; i++)
              Positioned(
                left: column * cellSize + cellSize / 2 - (textStyle.fontSize! / 2.6),
                top: i * cellSize + cellSize / 2 - (textStyle.fontSize! * 0.72 / 2),
                child: Text(word[i], style: textStyle),
              ),
          ]),
        ),
      ),
    );
  }
}

class _GridTiles extends StatelessWidget {
  const _GridTiles({
    required this.word,
    required this.row,
    required this.startCol,
    required this.cellSize,
    required this.padding,
  });
       
  final String word;
  final int row;
  final int startCol;
  final double cellSize;
  final EdgeInsets padding;
  
  @override
  Widget build(BuildContext context) {
    assert(padding.isNonNegative, 'GridTiles padding must be non-negative');
    assert(cellSize > 0, 'Cell size must be positive');

    final colors = const [
      Color(0xFFFBE7A1),
      Color(0xFFE6B85C),
      Color(0xFFC4822D),
      Color(0xFF8E5E1A),
    ];
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: cellSize * 9,
          height: cellSize * 9,
          child: Stack(children: [
            for (int i = 0; i < word.length; i++)
              Positioned(
                left: (startCol + i) * cellSize + 4,
                top: row * cellSize + 4,
                child: Container(
                  width: cellSize - 8,
                  height: cellSize - 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [colors[0], colors[1], colors[2]],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
                      BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      word[i],
                      style: TextStyle(
                        fontSize: cellSize * 0.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// Cinematic background: subtle film reels parallax, marquee twinkles, and a soft spotlight sweep.
// Lightweight: one ticker in painter; minimized allocations; respects pause/reduceMotion.
class _CinematicBackground extends StatefulWidget {
  const _CinematicBackground({
    required this.paused,
    this.density = 1.0,
    this.speedScale = 1.0,
  });
  final bool paused;
  final double density; // 0..1 affects number of elements
  final double speedScale; // 0..1 scales animation speed

  @override
  State<_CinematicBackground> createState() => _CinematicBackgroundState();
}

class _CinematicBackgroundState extends State<_CinematicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // Long-running bounded controller to avoid repeat() period error and keep smooth time.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 600), // 10 minutes loop
    )
      ..addListener(() => setState(() {}))
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant _CinematicBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused && _ctrl.isAnimating) {
      _ctrl.stop(canceled: false);
    } else if (!widget.paused && !_ctrl.isAnimating) {
  _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Touch fields so analyzer knows they're used via build.
    assert(() {
      // ignore: unnecessary_statements
      widget.density;
      // ignore: unnecessary_statements
      widget.speedScale;
      return true;
    }());
    return CustomPaint(
      painter: _CinemaPainter(
  time: (_ctrl.lastElapsedDuration?.inMilliseconds ?? 0) /
            (1000.0 / (widget.speedScale.clamp(0.1, 2.0))),
        density: widget.density.clamp(0.0, 1.0),
        colorScheme: Theme.of(context).colorScheme,
      ),
    );
  }
}

class _CinemaPainter extends CustomPainter {
  _CinemaPainter({
    required this.time,
    required this.density,
    required this.colorScheme,
  });

  final double time;
  final double density;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = colorScheme.surface;
    canvas.drawRect(Offset.zero & size, bg);

    // Soft spotlight sweep (very subtle gradient wedge)
    final sweepCenter = Offset(size.width * 0.5, size.height * 0.3);
    final sweepAngle = 0.6 + 0.1 * math.sin(time * 0.2);
    final startAngle = time * 0.05;
    final sweepRadius = size.width * 0.9;
    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          colorScheme.onSurface.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: sweepCenter, radius: sweepRadius));
    canvas.save();
    canvas.translate(sweepCenter.dx, sweepCenter.dy);
    canvas.rotate(startAngle);
    final path = Path()
      ..moveTo(0, 0)
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: sweepRadius),
        -sweepAngle / 2,
        sweepAngle,
        false,
      )
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, sweepPaint);
    canvas.restore();

    // Parallax film reels (two depths)
    final reelColor = colorScheme.primary.withValues(alpha: 0.08);
    final reelStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = reelColor;
    final reelFill = Paint()..color = reelColor;

    void drawReel(Offset c, double r) {
      canvas.drawCircle(c, r, reelStroke);
      // sprocket holes
      const holes = 12;
      for (var i = 0; i < holes; i++) {
        final ang = i * (2 * math.pi / holes) + time * 0.2;
        final p = c + Offset(math.cos(ang), math.sin(ang)) * (r * 0.7);
        canvas.drawCircle(p, r * 0.07, reelFill);
      }
    }

    final d = density;
    // back layer
    for (int i = 0; i < (3 * d).round(); i++) {
      final x = (i * size.width * 0.4 + (time * 10) % (size.width * 0.4)) %
          (size.width + 100) - 50;
      final y = size.height * (0.15 + 0.3 * i);
      drawReel(Offset(x, y), size.width * 0.12);
    }
    // front layer
    for (int i = 0; i < (2 * d).round(); i++) {
      final x = (i * size.width * 0.5 - (time * 16) % (size.width * 0.5)) %
          (size.width + 120) - 60;
      final y = size.height * (0.55 + 0.2 * i);
      drawReel(Offset(x, y), size.width * 0.16);
    }

    // Marquee twinkles along top and bottom edges
    final bulbColor = colorScheme.secondary.withValues(alpha: 0.10);
    final bulbOn = colorScheme.secondary;
    final gap = 18.0;
    for (double x = 12; x < size.width - 12; x += gap) {
      final phase = ((x / gap).floor() % 3);
      final on = ((time * 2).floor() + phase) % 3 == 0;
      final paint = Paint()
        ..color = (on ? bulbOn : bulbColor)
        ..maskFilter = on ? const MaskFilter.blur(BlurStyle.normal, 2) : null;
      canvas.drawCircle(Offset(x, 10), 2.2, paint);
      canvas.drawCircle(Offset(x, size.height - 10), 2.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CinemaPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.density != density ||
        oldDelegate.colorScheme != colorScheme;
  }
}
