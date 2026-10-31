import 'package:flutter/material.dart';

import '../item_icons.dart';
import '../theme.dart';
import 'item_icon_data.dart';

/// Rounded strokes with restrained fills, matching the selected icon preview.
class DailyItemIcon extends StatelessWidget {
  const DailyItemIcon(this.iconKey, {this.size = 24, this.color, super.key});
  final String iconKey;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _ItemIconPainter(
            ItemIcons.glyphFor(iconKey),
            color ?? context.palette.pine,
            Color.lerp(
              context.palette.canvasRaised,
              color ?? context.palette.pine,
              .18,
            )!,
          ),
        ),
      ),
    ),
  );
}

class _IconShape {
  const _IconShape(this.path, this.fill);
  final Path path;
  final bool fill;
}

final _iconShapeCache = <String, List<_IconShape>>{};

List<_IconShape> _shapesFor(String glyph) =>
    _iconShapeCache.putIfAbsent(glyph, () {
      final nodes = itemIconNodes[glyph] ?? itemIconNodes['pill']!;
      return nodes
          .map((node) {
            final (tag, attributes) = node;
            double number(String key, [double fallback = 0]) =>
                double.tryParse(attributes[key] ?? '') ?? fallback;
            switch (tag) {
              case 'path':
                final data = attributes['d']!;
                return _IconShape(
                  _parsePath(data),
                  data.trim().toLowerCase().endsWith('z'),
                );
              case 'circle':
                final radius = number('r');
                return _IconShape(
                  Path()..addOval(
                    Rect.fromCircle(
                      center: Offset(number('cx'), number('cy')),
                      radius: radius,
                    ),
                  ),
                  true,
                );
              case 'rect':
                final rect = Rect.fromLTWH(
                  number('x'),
                  number('y'),
                  number('width'),
                  number('height'),
                );
                return _IconShape(
                  Path()..addRRect(
                    RRect.fromRectAndCorners(
                      rect,
                      topLeft: Radius.elliptical(
                        number('rx'),
                        number('ry', number('rx')),
                      ),
                      topRight: Radius.elliptical(
                        number('rx'),
                        number('ry', number('rx')),
                      ),
                      bottomLeft: Radius.elliptical(
                        number('rx'),
                        number('ry', number('rx')),
                      ),
                      bottomRight: Radius.elliptical(
                        number('rx'),
                        number('ry', number('rx')),
                      ),
                    ),
                  ),
                  true,
                );
              case 'line':
                return _IconShape(
                  Path()
                    ..moveTo(number('x1'), number('y1'))
                    ..lineTo(number('x2'), number('y2')),
                  false,
                );
              default:
                throw StateError('Unsupported bundled icon shape: $tag');
            }
          })
          .toList(growable: false);
    });

// Parses only the SVG commands used by the bundled, fixed Lucide icon set.
// Geometry is cached once; painting never reparses paths or loads resources.
Path _parsePath(String data) {
  final tokens = RegExp(
    r'[AaCcHhLlMmSsVvZz]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?',
  ).allMatches(data).map((match) => match.group(0)!).toList();
  final path = Path();
  var position = Offset.zero;
  var start = Offset.zero;
  Offset? lastControl;
  var command = '';
  var previousCommand = '';
  var index = 0;
  double next() => double.parse(tokens[index++]);
  while (index < tokens.length) {
    if (RegExp(r'^[A-Za-z]$').hasMatch(tokens[index])) {
      command = tokens[index++];
    }
    final relative = command == command.toLowerCase();
    Offset point() {
      final value = Offset(next(), next());
      return relative ? position + value : value;
    }

    Offset? control;
    switch (command.toUpperCase()) {
      case 'M':
        position = point();
        start = position;
        path.moveTo(position.dx, position.dy);
        command = relative ? 'l' : 'L';
      case 'L':
        position = point();
        path.lineTo(position.dx, position.dy);
      case 'H':
        position = Offset(
          relative ? position.dx + next() : next(),
          position.dy,
        );
        path.lineTo(position.dx, position.dy);
      case 'V':
        position = Offset(
          position.dx,
          relative ? position.dy + next() : next(),
        );
        path.lineTo(position.dx, position.dy);
      case 'C':
        final first = point();
        final second = point();
        final end = point();
        path.cubicTo(first.dx, first.dy, second.dx, second.dy, end.dx, end.dy);
        position = end;
        control = second;
      case 'S':
        final first =
            const {'C', 'S'}.contains(previousCommand) && lastControl != null
            ? position * 2 - lastControl
            : position;
        final second = point();
        final end = point();
        path.cubicTo(first.dx, first.dy, second.dx, second.dy, end.dx, end.dy);
        position = end;
        control = second;
      case 'A':
        final radius = Radius.elliptical(next(), next());
        final rotation = next();
        final largeArc = next() != 0;
        final clockwise = next() != 0;
        position = point();
        path.arcToPoint(
          position,
          radius: radius,
          rotation: rotation,
          largeArc: largeArc,
          clockwise: clockwise,
        );
      case 'Z':
        path.close();
        position = start;
        command = '';
      default:
        throw StateError('Unsupported bundled icon command: $command');
    }
    previousCommand = command.toUpperCase();
    lastControl = control;
  }
  return path;
}

class _ItemIconPainter extends CustomPainter {
  const _ItemIconPainter(this.glyph, this.color, this.fillColor);
  final String glyph;
  final Color color;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(
      (size.width - size.shortestSide) / 2,
      (size.height - size.shortestSide) / 2,
    );
    canvas.scale(size.shortestSide / 24);
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = fillColor;
    for (final shape in _shapesFor(glyph)) {
      if (shape.fill) canvas.drawPath(shape.path, fill);
      canvas.drawPath(shape.path, outline);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ItemIconPainter oldDelegate) =>
      glyph != oldDelegate.glyph ||
      color != oldDelegate.color ||
      fillColor != oldDelegate.fillColor;
}
