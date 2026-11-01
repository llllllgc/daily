import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

@immutable
class ButtonOrigin {
  const ButtonOrigin({required this.bounds, required this.viewport});

  final Rect bounds;
  final Size viewport;

  Rect boundsFor(Size size) => Rect.fromLTWH(
    bounds.left * size.width / viewport.width,
    bounds.top * size.height / viewport.height,
    bounds.width * size.width / viewport.width,
    bounds.height * size.height / viewport.height,
  );
}

class ButtonOriginController {
  ButtonOrigin? _origin;

  ButtonOrigin? take() {
    final origin = _origin;
    _origin = null;
    return origin;
  }
}

/// Captures the actual control bounds, including keyboard and safe-area offsets.
class ButtonOriginScope extends InheritedWidget {
  const ButtonOriginScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final ButtonOriginController controller;

  static void capture(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ButtonOriginScope>();
    final box = context.findRenderObject();
    final overlay = Navigator.of(context).overlay?.context.findRenderObject();
    if (scope == null ||
        box is! RenderBox ||
        overlay is! RenderBox ||
        !box.hasSize ||
        !overlay.hasSize ||
        overlay.size.isEmpty) {
      return;
    }
    scope.controller._origin = ButtonOrigin(
      bounds: box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
      viewport: overlay.size,
    );
  }

  @override
  bool updateShouldNotify(ButtonOriginScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Expands from a launch button and contracts back to it when dismissed.
class ButtonOriginPageRoute<T> extends MaterialPageRoute<T> {
  ButtonOriginPageRoute({
    required super.builder,
    required this.origin,
    this.reduceMotion = false,
  }) : super(allowSnapshotting: false);

  final ButtonOrigin origin;
  final bool reduceMotion;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 280);

  // Keep the launch button stationary while the new page expands over it.
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final transition = reduceMotion || MediaQuery.disableAnimationsOf(context)
        ? child
        : ButtonExpansionTransition(
            animation: animation,
            origin: origin,
            linear: popGestureInProgress,
            child: child,
          );
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // Retain Flutter's native edge-swipe controller without its slide effect.
      return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
        this,
        context,
        kAlwaysCompleteAnimation,
        kAlwaysDismissedAnimation,
        transition,
      );
    }
    return transition;
  }
}

class ButtonExpansionTransition extends StatelessWidget {
  const ButtonExpansionTransition({
    required this.animation,
    required this.origin,
    required this.child,
    this.linear = false,
    super.key,
  });

  final Animation<double> animation;
  final ButtonOrigin origin;
  final Widget child;
  final bool linear;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final size = constraints.biggest;
        final source = origin.boundsFor(size);
        final value = animation.value.clamp(0.0, 1.0);
        final progress = linear ? value : Curves.easeOutCubic.transform(value);
        final distances = EdgeInsets.fromLTRB(
          (source.left / size.width).clamp(0, 1),
          (source.top / size.height).clamp(0, 1),
          ((size.width - source.right) / size.width).clamp(0, 1),
          ((size.height - source.bottom) / size.height).clamp(0, 1),
        );
        double edgeProgress(double distance) {
          if (linear) return value;
          final delay = .09 * distance;
          return Curves.easeOutCubic.transform(
            ((value - delay) / (1 - delay)).clamp(0, 1),
          );
        }

        final bounds = Rect.fromLTRB(
          source.left * (1 - edgeProgress(distances.left)),
          source.top * (1 - edgeProgress(distances.top)),
          source.right +
              (size.width - source.right) * edgeProgress(distances.right),
          source.bottom +
              (size.height - source.bottom) * edgeProgress(distances.bottom),
        );
        final stretch = linear
            ? 0.0
            : .04 *
                  math.sin(math.pi * value) *
                  (1 - const Interval(.55, .78).transform(value));
        final bend = size.shortestSide * stretch;
        final radius =
            source.shortestSide /
            2 *
            (1 - Curves.easeInCubic.transform(progress));
        final clipper = _ButtonPageClipper(bounds, radius, distances, bend);
        final path = clipper.getClip(size);
        final surfaceOpacity = const Interval(0, .10).transform(value);
        final contentOpacity = const Interval(
          .14,
          .72,
          curve: Curves.easeOutCubic,
        ).transform(value);
        final direction = source.center - size.center(Offset.zero);
        final distance = direction.distance;
        final offset = distance > 0
            ? direction / distance * (8 * (1 - contentOpacity))
            : Offset.zero;
        final scale = .985 + .015 * contentOpacity;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.black.withValues(alpha: .06 * progress)),
            CustomPaint(
              painter: _ButtonSurfacePainter(
                path: path,
                color: Theme.of(context).scaffoldBackgroundColor,
                opacity: surfaceOpacity,
                shadow: value > 0 && value < 1,
              ),
            ),
            IgnorePointer(
              ignoring:
                  value < .35 || animation.status == AnimationStatus.reverse,
              child: ClipPath(
                key: const Key('button-origin-page-clip'),
                clipper: clipper,
                child: Opacity(
                  key: const Key('button-origin-content-opacity'),
                  opacity: contentOpacity,
                  child: Transform.translate(
                    offset: offset,
                    child: Transform.scale(
                      key: const Key('button-origin-content-scale'),
                      scale: scale,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ButtonPageClipper extends CustomClipper<Path> {
  const _ButtonPageClipper(this.bounds, this.radius, this.distances, this.bend);

  final Rect bounds;
  final double radius;
  final EdgeInsets distances;
  final double bend;

  @override
  Path getClip(Size size) {
    final corner = radius.clamp(0.0, bounds.shortestSide / 2);
    final arc = Radius.circular(corner);
    final left = bounds.left, top = bounds.top;
    final right = bounds.right, bottom = bounds.bottom;
    return Path()
      ..moveTo(left + corner, top)
      ..quadraticBezierTo(
        bounds.center.dx,
        top - bend * distances.top,
        right - corner,
        top,
      )
      ..arcToPoint(Offset(right, top + corner), radius: arc)
      ..quadraticBezierTo(
        right + bend * distances.right,
        bounds.center.dy,
        right,
        bottom - corner,
      )
      ..arcToPoint(Offset(right - corner, bottom), radius: arc)
      ..quadraticBezierTo(
        bounds.center.dx,
        bottom + bend * distances.bottom,
        left + corner,
        bottom,
      )
      ..arcToPoint(Offset(left, bottom - corner), radius: arc)
      ..quadraticBezierTo(
        left - bend * distances.left,
        bounds.center.dy,
        left,
        top + corner,
      )
      ..arcToPoint(Offset(left + corner, top), radius: arc)
      ..close();
  }

  @override
  bool shouldReclip(_ButtonPageClipper oldClipper) =>
      bounds != oldClipper.bounds ||
      radius != oldClipper.radius ||
      bend != oldClipper.bend ||
      distances != oldClipper.distances;
}

class _ButtonSurfacePainter extends CustomPainter {
  const _ButtonSurfacePainter({
    required this.path,
    required this.color,
    required this.opacity,
    required this.shadow,
  });

  final Path path;
  final Color color;
  final double opacity;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadow) {
      canvas.drawShadow(
        path,
        Colors.black.withValues(alpha: .13 * opacity),
        8,
        false,
      );
    }
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: opacity));
  }

  @override
  bool shouldRepaint(_ButtonSurfacePainter oldDelegate) =>
      path != oldDelegate.path ||
      color != oldDelegate.color ||
      opacity != oldDelegate.opacity ||
      shadow != oldDelegate.shadow;
}
