import 'package:flutter/material.dart';

import 'motion.dart';

/// A determinate ring whose length and status color animate together.
class CompletionProgressRing extends StatelessWidget {
  const CompletionProgressRing({
    required this.completed,
    required this.total,
    this.semanticLabel = '完成进度',
    this.size = 25.6,
    super.key,
  });

  static const lowColor = Color(0xFFC94F45);
  static const partialColor = Color(0xFFC49A28);
  static const completeColor = Color(0xFF32805B);

  final int completed;
  final int total;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final color = progress >= 1
        ? completeColor
        : progress > 1 / 3
        ? partialColor
        : lowColor;
    final target = _RingFrame(progress, color, progress >= 1 ? 1 : 0);
    final valueLabel = '$completed / $total 已完成';

    return Tooltip(
      message: '$semanticLabel：$valueLabel',
      excludeFromSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<_RingFrame>(
          // A preference change also settles an already running transition.
          key: ValueKey(MediaQuery.disableAnimationsOf(context)),
          tween: _RingTween(begin: target, end: target),
          duration: appMotion(context, progress >= 1 ? 760 : 520),
          builder: (context, frame, _) => Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: frame.progress,
                color: frame.color,
                backgroundColor: frame.color.withValues(alpha: .16),
                strokeWidth: size * 3.5 / 32,
                strokeAlign: CircularProgressIndicator.strokeAlignInside,
                strokeCap: StrokeCap.round,
                trackGap: 0,
                padding: EdgeInsets.zero,
                semanticsLabel: '$semanticLabel，$valueLabel',
                semanticsValue: '${(progress * 100).round()}',
              ),
              ExcludeSemantics(
                child: CustomPaint(
                  painter: _RingCheckPainter(frame.check, frame.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class _RingFrame {
  const _RingFrame(this.progress, this.color, this.check);

  final double progress;
  final Color color;
  final double check;

  @override
  bool operator ==(Object other) =>
      other is _RingFrame &&
      progress == other.progress &&
      color == other.color &&
      check == other.check;

  @override
  int get hashCode => Object.hash(progress, color, check);
}

class _RingTween extends Tween<_RingFrame> {
  _RingTween({required _RingFrame super.begin, required _RingFrame super.end});

  @override
  _RingFrame lerp(double t) {
    final completing = end!.check > begin!.check;
    // Close the ring first, then trace the check in one continuous stroke.
    final arc = completing
        ? const Interval(0, .68, curve: Curves.easeInOutCubic).transform(t)
        : Curves.easeInOutCubic.transform(t);
    final check = completing
        ? const Interval(.68, 1, curve: Curves.easeInOutCubic).transform(t)
        : Curves.easeOutCubic.transform(t);
    return _RingFrame(
      begin!.progress + (end!.progress - begin!.progress) * arc,
      Color.lerp(begin!.color, end!.color, arc)!,
      begin!.check + (end!.check - begin!.check) * check,
    );
  }
}

class _RingCheckPainter extends CustomPainter {
  const _RingCheckPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * .30, size.height * .51)
      ..lineTo(size.width * .44, size.height * .65)
      ..lineTo(size.width * .72, size.height * .35);
    final metric = path.computeMetrics().single;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_RingCheckPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
