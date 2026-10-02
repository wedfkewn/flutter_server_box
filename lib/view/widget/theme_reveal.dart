import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Wait for a picker to leave before capturing the page beneath it.
class ThemeRevealObserver extends NavigatorObserver {
  Future<dynamic>? dismissal;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute<dynamic>) dismissal = route.completed;
  }
}

/// One live app tree and one temporary texture. Animation only repaints the
/// clip; it never rebuilds the navigator, terminal or monitoring page per frame.
class ThemeReveal extends StatefulWidget {
  const ThemeReveal({super.key, required this.child, required this.theme,
    this.observer});
  final Widget child;
  final ThemeData theme;
  final ThemeRevealObserver? observer;
  static const duration = Duration(milliseconds: 420);

  static Future<void> change(BuildContext context, VoidCallback update) async {
    final state = context.findAncestorStateOfType<_ThemeRevealState>();
    if (state == null) { update(); return; }
    await state.change(update);
  }

  @override
  State<ThemeReveal> createState() => _ThemeRevealState();
}

class _ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin {
  final _boundaryKey = GlobalKey();
  late final _animation = AnimationController(vsync: this, duration: ThemeReveal.duration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _clear();
    });
  ui.Image? _image;
  Size? _size;
  int _request = 0;
  bool _scheduled = false;

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.disableAnimations == true;

  Future<void> change(VoidCallback update) async {
    final request = ++_request;
    await widget.observer?.dismissal;
    if (!mounted || request != _request) return;
    // Flush the dismissing dialog and any pending layout before snapshotting.
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted || request != _request) return;
    if (!_reduceMotion) _capture();
    update();
    // An unchanged selection must not leave an opaque snapshot on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && request == _request && !_scheduled && !_animation.isAnimating) _clear();
    });
  }

  void _capture() {
    _animation.stop();
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize ||
        boundary.size.isEmpty || boundary.debugNeedsPaint) { return; }
    ui.Image? next;
    try {
      // Bound texture memory on high-density phones and large desktop windows.
      final ratio = math.min(MediaQuery.devicePixelRatioOf(context),
        math.min(2.0, math.sqrt(2000000 / (boundary.size.width * boundary.size.height))));
      next = boundary.toImageSync(pixelRatio: ratio);
    } catch (_) {
      // Capturing is optional; changing the actual theme must always work.
      return;
    }
    final previous = _image;
    _image = next;
    _size = boundary.size;
    _animation.value = 0;
    setState(() {});
    _release(previous);
  }

  @override
  void didUpdateWidget(ThemeReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme == widget.theme) return;
    if (_reduceMotion) { _clear(); return; }
    // Also covers automatic light/dark changes from the operating system.
    if (_image == null) _capture();
    if (_image != null) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted && _image != null && !_reduceMotion) _animation.forward(from: 0);
      });
    }
  }

  void _clear() {
    _scheduled = false;
    _animation.stop();
    final image = _image;
    if (image == null) return;
    _image = null;
    if (mounted) setState(() {});
    _release(image);
  }

  void _release(ui.Image? image) {
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  @override
  void dispose() {
    _request++;
    _animation.dispose();
    _release(_image);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, constraints) {
    final image = _image;
    final fits = _size == constraints.biggest && !_reduceMotion;
    if (image != null && !fits) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _clear(); });
    }
    return Stack(fit: StackFit.expand, children: [
      RepaintBoundary(key: _boundaryKey, child: widget.child),
      if (image != null && fits) Positioned.fill(child: IgnorePointer(
        child: ExcludeSemantics(child: ClipPath(
          clipper: ThemeRevealClipper(_animation),
          child: RawImage(image: image, fit: BoxFit.fill, filterQuality: FilterQuality.low),
        )),
      )),
    ]);
  });
}

/// Keep the old texture outside an expanding circle at the top-right corner.
class ThemeRevealClipper extends CustomClipper<Path> {
  ThemeRevealClipper(this.progress) : super(reclip: progress);
  final Animation<double> progress;

  @override
  Path getClip(Size size) {
    final origin = Offset(size.width, 0);
    final radius = math.sqrt(size.width * size.width + size.height * size.height)
      * Curves.easeInOutCubic.transform(progress.value);
    return Path()..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: origin, radius: radius));
  }

  @override
  bool shouldReclip(ThemeRevealClipper oldClipper) => oldClipper.progress != progress;
}
