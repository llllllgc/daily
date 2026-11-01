import 'package:flutter/material.dart';

import 'motion.dart';

/// A determinate ring whose length and status color animate together.
class CompletionProgressRing extends StatelessWidget {
  const CompletionProgressRing({
    required this.completed,
    required this.total,
    this.semanticLabel = '完成进度',
    this.size = 32,
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
        : progress >= 1 / 3
        ? partialColor
        : lowColor;
    final target = _RingFrame(progress, color);
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
          duration: appMotion(context, 520),
          curve: Curves.easeInOutCubic,
          builder: (context, frame, _) => CircularProgressIndicator(
            value: frame.progress,
            color: frame.color,
            backgroundColor: frame.color.withValues(alpha: .16),
            strokeWidth: 3.5,
            strokeAlign: CircularProgressIndicator.strokeAlignInside,
            strokeCap: StrokeCap.round,
            trackGap: 0,
            padding: EdgeInsets.zero,
            semanticsLabel: '$semanticLabel，$valueLabel',
            semanticsValue: '${(progress * 100).round()}',
          ),
        ),
      ),
    );
  }
}

@immutable
class _RingFrame {
  const _RingFrame(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is _RingFrame && progress == other.progress && color == other.color;

  @override
  int get hashCode => Object.hash(progress, color);
}

class _RingTween extends Tween<_RingFrame> {
  _RingTween({required _RingFrame super.begin, required _RingFrame super.end});

  @override
  _RingFrame lerp(double t) => _RingFrame(
    begin!.progress + (end!.progress - begin!.progress) * t,
    Color.lerp(begin!.color, end!.color, t)!,
  );
}
