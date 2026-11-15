import 'dart:math' as math;

import 'package:field_core/field_core.dart';
import 'package:flutter/material.dart';

import 'workspace_widgets.dart';

/// A thumbnail of the saved boundary, using the same vertices as the map.
class FieldBoundaryPreview extends StatelessWidget {
  final FieldGeometry geometry;
  const FieldBoundaryPreview(this.geometry, {super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: CustomPaint(
        size: const Size(64, 62),
        painter: _FieldBoundaryPainter(geometry),
      ),
    ),
  );
}

class _FieldBoundaryPainter extends CustomPainter {
  final FieldGeometry geometry;
  const _FieldBoundaryPainter(this.geometry);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xffeef1e2),
    );
    final grid = Paint()..color = const Color(0xffd9e2cc);
    for (var x = 8.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 8.0; y < size.height; y += 9) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final bounds = geometry.bounds;
    final center = bounds.center;
    final longitudeScale = math.cos(center.latitude * math.pi / 180);
    final scale = math.min(
      (size.width - 18) / ((bounds.east - bounds.west) * longitudeScale),
      (size.height - 18) / (bounds.north - bounds.south),
    );
    final outline = Path()
      ..addPolygon([
        for (final point in geometry.vertices)
          Offset(
            size.width / 2 +
                (point.longitude - center.longitude) * longitudeScale * scale,
            size.height / 2 - (point.latitude - center.latitude) * scale,
          ),
      ], true);
    canvas.drawPath(outline, Paint()..color = const Color(0xffa7bc83));
    canvas.drawPath(
      outline,
      Paint()
        ..color = forest
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _FieldBoundaryPainter oldDelegate) =>
      oldDelegate.geometry != geometry;
}
