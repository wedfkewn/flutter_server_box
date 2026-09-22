import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum DotMatrixStyle { orbit, pulse, scan }

/// Compact loading feedback; only its paint layer changes on each tick.
class DotMatrixLoader extends StatefulWidget {
  const DotMatrixLoader({
    super.key,
    required this.label,
    this.size = 20,
    this.color,
    this.style = DotMatrixStyle.pulse,
  });

  final String label;
  final double size;
  final Color? color;
  final DotMatrixStyle style;

  @override
  State<DotMatrixLoader> createState() => _DotMatrixLoaderState();
}

class _DotMatrixLoaderState extends State<DotMatrixLoader>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  Timer? _delay;
  bool _ready = false;
  bool _reduceMotion = false;
  bool _visible = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _delay = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _ready = true);
      _sync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _visible = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (_ready && _visible && _foreground && !_reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: !_ready
        ? null
        : Semantics(
            label: widget.label,
            liveRegion: true,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DotPainter(
                  _controller,
                  color:
                      widget.color ??
                      IconTheme.of(context).color ??
                      Theme.of(context).colorScheme.primary,
                  style: widget.style,
                  reducedMotion: _reduceMotion,
                ),
              ),
            ),
          ),
  );
}

class _DotPainter extends CustomPainter {
  _DotPainter(
    this.animation, {
    required this.color,
    required this.style,
    required this.reducedMotion,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final DotMatrixStyle style;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final paint = Paint();
    final count = style == DotMatrixStyle.orbit ? 8 : 9;
    for (var i = 0; i < count; i++) {
      final col = i % 3;
      final row = i ~/ 3;
      final Offset point;
      final double offset;
      if (style == DotMatrixStyle.orbit) {
        final angle = i * math.pi / 4 - math.pi / 2;
        point = Offset(
          unit / 2 + math.cos(angle) * unit * .34,
          unit / 2 + math.sin(angle) * unit * .34,
        );
        offset = i / 8;
      } else {
        point = Offset(unit * (.2 + col * .3), unit * (.2 + row * .3));
        offset = style == DotMatrixStyle.scan ? col / 3 : (col + row) / 6;
      }
      final pulse = reducedMotion
          ? .65
          : (1 + math.cos((animation.value - offset) * math.pi * 2)) / 2;
      paint.color = color.withValues(alpha: color.a * (.25 + .75 * pulse));
      canvas.drawCircle(point, unit * .085 * (.8 + .2 * pulse), paint);
    }
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.style != style ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.animation != animation;
}
