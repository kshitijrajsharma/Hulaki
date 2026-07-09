import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Renders a map pin (a coloured tear-drop with an optional white icon glyph)
/// to PNG bytes for MapLibre's `addImage`. The tip sits at the bottom-centre,
/// so the symbol layer anchors it on the point's coordinate. The outline is one
/// closed path built from the tip's tangent lines to the head, so the head and
/// point join smoothly with no internal seam.
Future<Uint8List> buildPinImage({
  required Color color,
  IconData? icon,
  double logicalSize = 34,
  double pixelRatio = 3,
}) async {
  final size = logicalSize * pixelRatio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final radius = size * 0.30;
  final center = Offset(size / 2, radius + size * 0.09);
  final tip = Offset(size / 2, size - size * 0.05);

  // The two points where a line from the tip grazes the head. Between them the
  // outline follows the head; below them it runs straight to the tip.
  final distance = tip.dy - center.dy;
  final half = math.acos(radius / distance);
  final rightAngle = math.pi / 2 - half;
  final rightTangent =
      center + Offset(math.cos(rightAngle), math.sin(rightAngle)) * radius;

  final body = Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(rightTangent.dx, rightTangent.dy)
    ..arcTo(
      Rect.fromCircle(center: center, radius: radius),
      rightAngle,
      -(2 * math.pi - 2 * half),
      false,
    )
    ..close();

  canvas
    ..drawShadow(body, Colors.black.withValues(alpha: 0.35), size * 0.03, false)
    ..drawPath(body, Paint()..color = color)
    ..drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.035
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );

  if (icon != null) {
    final painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: radius * 1.15,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  } else {
    canvas.drawCircle(center, radius * 0.36, Paint()..color = Colors.white);
  }

  final image = await recorder.endRecording().toImage(
    size.ceil(),
    size.ceil(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Renders a heading cone: a soft wedge in [color] that fades out from the
/// point, drawn beneath the pin and rotated to the bearing by the symbol layer.
/// Its apex sits at the bottom-centre so it shares the pin's anchor, so the
/// beam fans from the point while the pin and its icon stay untouched.
Future<Uint8List> buildHeadingConeImage({
  required Color color,
  double logicalSize = 54,
  double pixelRatio = 3,
}) async {
  final size = logicalSize * pixelRatio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final apex = Offset(size / 2, size);
  final radius = size * 0.94;
  const halfSpread = 32 * math.pi / 180;
  const start = -math.pi / 2 - halfSpread;

  final wedge = Path()
    ..moveTo(apex.dx, apex.dy)
    ..arcTo(
      Rect.fromCircle(center: apex, radius: radius),
      start,
      2 * halfSpread,
      false,
    )
    ..close();

  final shader = ui.Gradient.radial(apex, radius, [
    color.withValues(alpha: 0.55),
    color.withValues(alpha: 0),
  ], [0, 1]);
  canvas.drawPath(wedge, Paint()..shader = shader);

  final image = await recorder.endRecording().toImage(
    size.ceil(),
    size.ceil(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
