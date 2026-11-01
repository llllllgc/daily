import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

Duration appMotion(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// Reveals the completed surface from left to right and retracts it on undo.
/// The child stays above the fill, so labels and controls remain readable.
class CompletionFillSurface extends StatelessWidget {
  const CompletionFillSurface({
    required this.completed,
    required this.baseColor,
    required this.completedColor,
    required this.borderRadius,
    required this.child,
    super.key,
  });

  final bool completed;
  final Color baseColor;
  final Color completedColor;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: completed ? 1.0 : 0.0, end: completed ? 1.0 : 0.0),
      duration: appMotion(context, completed ? 320 : 240),
      curve: Curves.easeInOutCubic,
      child: child,
      builder: (context, progress, child) => Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: baseColor)),
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                key: const Key('completion-fill'),
                widthFactor: progress,
                heightFactor: 1,
                child: ColoredBox(color: completedColor),
              ),
            ),
          ),
          ?child,
        ],
      ),
    ),
  );
}

/// Moves the current calendar with the finger and settles into the next period.
class SwipePeriod extends StatefulWidget {
  const SwipePeriod({
    required this.child,
    required this.adjacentBuilder,
    required this.onChanged,
    super.key,
  });

  final Widget child;
  final Widget Function(int delta) adjacentBuilder;
  final ValueChanged<int> onChanged;

  @override
  State<SwipePeriod> createState() => _SwipePeriodState();
}

class _SwipePeriodState extends State<SwipePeriod>
    with SingleTickerProviderStateMixin {
  late final _slide = AnimationController.unbounded(vsync: this);
  double _width = 1;
  int _gestureVersion = 0;

  Future<void> _settle(int delta) async {
    final version = ++_gestureVersion;
    final target = -delta * _width;
    if (MediaQuery.disableAnimationsOf(context)) {
      if (delta != 0) widget.onChanged(delta);
      _slide.value = 0;
      return;
    }
    try {
      await _slide
          .animateTo(
            target,
            duration: const Duration(milliseconds: 210),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
      if (!mounted || version != _gestureVersion) return;
      if (delta != 0) widget.onChanged(delta);
      _slide.value = 0;
    } on TickerCanceled {
      // A new gesture continues from the current position.
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _width = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (_) {
          _gestureVersion++;
          _slide.stop();
        },
        onHorizontalDragUpdate: (details) {
          _slide.value = (_slide.value + (details.primaryDelta ?? 0)).clamp(
            -_width,
            _width,
          );
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          final commit =
              _slide.value.abs() >= _width * .18 || velocity.abs() >= 280;
          final direction = velocity.abs() >= 280 ? velocity : _slide.value;
          unawaited(_settle(commit ? (direction < 0 ? 1 : -1) : 0));
        },
        onHorizontalDragCancel: () => unawaited(_settle(0)),
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _slide,
            child: widget.child,
            builder: (context, child) {
              final offset = _slide.value;
              return Stack(
                children: [
                  Transform.translate(offset: Offset(offset, 0), child: child),
                  if (offset != 0)
                    Positioned(
                      top: 0,
                      left: offset + (offset < 0 ? _width : -_width),
                      width: _width,
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: widget.adjacentBuilder(offset < 0 ? 1 : -1),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

/// Replaces content without leaving outgoing controls interactive or focusable.
class MotionSwitcher extends StatelessWidget {
  const MotionSwitcher({
    required this.child,
    this.offset = Offset.zero,
    this.milliseconds = 180,
    this.alignment = Alignment.topCenter,
    this.animateSize = false,
    super.key,
  });

  final Widget child;
  final Offset offset;
  final int milliseconds;
  final Alignment alignment;
  final bool animateSize;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final content = AnimatedSwitcher(
      duration: appMotion(context, milliseconds),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [
          for (final outgoing in previous)
            Positioned(top: 0, left: 0, right: 0, child: outgoing),
          ?current,
        ],
      ),
      transitionBuilder: (entry, animation) {
        final outgoing = entry.key != child.key;
        return IgnorePointer(
          ignoring: outgoing,
          child: ExcludeFocus(
            excluding: outgoing,
            child: ExcludeSemantics(
              excluding: outgoing,
              child: FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: outgoing ? -offset : offset,
                    end: Offset.zero,
                  ).animate(animation),
                  child: entry,
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
    return animateSize
        ? AnimatedSize(
            duration: appMotion(context, milliseconds),
            curve: Curves.easeOutCubic,
            alignment: alignment,
            child: content,
          )
        : content;
  }
}

class MotionReveal extends StatefulWidget {
  const MotionReveal({
    required this.visible,
    required this.child,
    this.offset = Offset.zero,
    super.key,
  });

  final bool visible;
  final Widget child;
  final Offset offset;

  @override
  State<MotionReveal> createState() => _MotionRevealState();
}

class _MotionRevealState extends State<MotionReveal>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, value: widget.visible ? 1 : 0)
        ..addStatusListener((_) {
          if (mounted) setState(() {});
        });
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = appMotion(context, 220);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.visible ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(MotionReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.visible ? 1 : 0;
    } else if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible && _controller.isDismissed) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      ignoring: !widget.visible,
      child: ExcludeFocus(
        excluding: !widget.visible,
        child: ExcludeSemantics(
          excluding: !widget.visible,
          child: SizeTransition(
            alignment: Alignment.topLeft,
            sizeFactor: _curve,
            child: FadeTransition(
              opacity: _curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: widget.offset,
                  end: Offset.zero,
                ).animate(_curve),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cross-fades mounted tabs, preserving scroll and expansion state.
class MotionPageEntrance extends StatefulWidget {
  const MotionPageEntrance({
    required this.active,
    required this.child,
    super.key,
  });

  final bool active;
  final Widget child;

  @override
  State<MotionPageEntrance> createState() => _MotionPageEntranceState();
}

class _MotionPageEntranceState extends State<MotionPageEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: widget.active ? 1 : 0,
  );
  late final _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = appMotion(context, 320);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.active ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(MotionPageEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.active ? 1 : 0;
    } else if (widget.active) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: FadeTransition(opacity: _opacity, child: widget.child),
    builder: (context, child) => Offstage(
      offstage: !widget.active && _controller.isDismissed,
      child: IgnorePointer(
        ignoring: !widget.active,
        child: ExcludeFocus(
          excluding: !widget.active,
          child: ExcludeSemantics(
            excluding: !widget.active,
            child: TickerMode(
              enabled: widget.active || _controller.isAnimating,
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Shows the state change before moving keyed, equally sized rows.
class MotionReorderColumn extends StatefulWidget {
  const MotionReorderColumn({
    required this.children,
    required this.extent,
    this.spacing = 6,
    super.key,
  });

  final List<Widget> children;
  final double extent;
  final double spacing;

  @override
  State<MotionReorderColumn> createState() => _MotionReorderColumnState();
}

class _MotionReorderColumnState extends State<MotionReorderColumn> {
  late List<Key> _order = widget.children.map((child) => child.key!).toList();
  Timer? _pendingMove;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pendingMove?.cancel();
      _order = widget.children.map((child) => child.key!).toList();
    }
  }

  @override
  void didUpdateWidget(MotionReorderColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.children.map((child) => child.key!).toList();
    if (listEquals(
      next,
      oldWidget.children.map((child) => child.key!).toList(),
    )) {
      return;
    }
    _pendingMove?.cancel();
    if (MediaQuery.disableAnimationsOf(context) ||
        !setEquals(_order.toSet(), next.toSet())) {
      _order = next;
    } else {
      _pendingMove = Timer(appMotion(context, 160), () {
        if (mounted) setState(() => _order = next);
      });
    }
  }

  @override
  void dispose() {
    _pendingMove?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.children.isEmpty
        ? 0
        : widget.children.length * (widget.extent + widget.spacing) -
              widget.spacing,
    child: Stack(
      children: [
        for (final child in widget.children)
          AnimatedPositioned(
            key: ValueKey<Key>(child.key!),
            duration: appMotion(context, 240),
            curve: Curves.easeInOutCubic,
            top: _order.indexOf(child.key!) * (widget.extent + widget.spacing),
            left: 0,
            right: 0,
            height: widget.extent,
            child: Semantics(
              sortKey: OrdinalSortKey(_order.indexOf(child.key!).toDouble()),
              child: child,
            ),
          ),
      ],
    ),
  );
}

/// Animates form rows by identity, keeping outgoing controls disabled.
class MotionEntryList extends StatefulWidget {
  const MotionEntryList({required this.children, super.key});

  final List<Widget> children;

  @override
  State<MotionEntryList> createState() => _MotionEntryListState();
}

class _MotionEntryListState extends State<MotionEntryList> {
  final _listKey = GlobalKey<AnimatedListState>();
  late final List<Widget> _entries = List.of(widget.children);

  Widget _transition(Widget child, Animation<double> animation) =>
      SizeTransition(
        sizeFactor: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
        alignment: Alignment.topLeft,
        child: FadeTransition(opacity: animation, child: child),
      );

  void _remove(int index) {
    final removed = _entries.removeAt(index);
    _listKey.currentState!.removeItem(
      index,
      (context, animation) => IgnorePointer(
        child: ExcludeFocus(
          child: ExcludeSemantics(child: _transition(removed, animation)),
        ),
      ),
      duration: appMotion(context, 180),
    );
  }

  @override
  void didUpdateWidget(MotionEntryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKeys = widget.children.map((child) => child.key).toSet();
    for (var index = _entries.length - 1; index >= 0; index--) {
      if (!nextKeys.contains(_entries[index].key)) _remove(index);
    }
    for (var index = 0; index < widget.children.length; index++) {
      final next = widget.children[index];
      if (index < _entries.length && _entries[index].key == next.key) {
        _entries[index] = next;
        continue;
      }
      final existing = _entries.indexWhere((entry) => entry.key == next.key);
      if (existing >= 0) _remove(existing);
      _entries.insert(index, next);
      _listKey.currentState!.insertItem(
        index,
        duration: appMotion(context, 220),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedList(
    key: _listKey,
    initialItemCount: _entries.length,
    shrinkWrap: true,
    primary: false,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    itemBuilder: (context, index, animation) =>
        _transition(_entries[index], animation),
  );
}
