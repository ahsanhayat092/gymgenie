import 'package:flutter/material.dart';

/// Renders the official Google "G" logo using CustomPainter.
/// No external packages required — paths are the exact brand-spec shapes
/// per Google's Sign-In button guidelines.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;

    // Scale factor — paths are defined on a 24×24 grid
    final double scale = s / 24.0;
    canvas.scale(scale, scale);

    // ── Blue — main body of the G ─────────────────────────────────────────
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(23.04, 12.27)
      ..lineTo(23.04, 11.91)
      ..cubicTo(23.04, 10.96, 22.96, 10.29, 22.8, 9.6)
      ..lineTo(12.0, 9.6)
      ..lineTo(12.0, 14.4)
      ..lineTo(18.56, 14.4)
      ..cubicTo(18.22, 16.21, 17.14, 17.72, 15.52, 18.71)
      ..lineTo(15.52, 21.73)
      ..lineTo(19.43, 21.73)
      ..cubicTo(21.73, 19.6, 23.04, 16.24, 23.04, 12.27)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // ── Green — bottom right ──────────────────────────────────────────────
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.95, 22.92, 19.43, 21.73)
      ..lineTo(15.52, 18.71)
      ..cubicTo(14.46, 19.42, 13.34, 19.84, 12.0, 19.84)
      ..cubicTo(8.87, 19.84, 6.23, 17.69, 5.34, 14.82)
      ..lineTo(1.3, 14.82)
      ..lineTo(1.3, 17.94)
      ..cubicTo(3.42, 22.15, 7.41, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // ── Yellow — bottom left ──────────────────────────────────────────────
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(5.34, 14.82)
      ..cubicTo(5.1, 14.11, 4.96, 13.34, 4.96, 12.0)
      ..cubicTo(4.96, 10.66, 5.1, 9.89, 5.34, 9.18)
      ..lineTo(5.34, 6.06)
      ..lineTo(1.3, 6.06)
      ..cubicTo(0.47, 7.72, 0.0, 9.8, 0.0, 12.0)
      ..cubicTo(0.0, 14.2, 0.47, 16.28, 1.3, 17.94)
      ..lineTo(5.34, 14.82)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // ── Red — top left ────────────────────────────────────────────────────
    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(12.0, 4.16)
      ..cubicTo(13.69, 4.16, 15.2, 4.76, 16.39, 5.91)
      ..lineTo(19.52, 2.78)
      ..cubicTo(17.95, 1.24, 15.24, 0.0, 12.0, 0.0)
      ..cubicTo(7.41, 0.0, 3.42, 1.85, 1.3, 6.06)
      ..lineTo(5.34, 9.18)
      ..cubicTo(6.23, 6.31, 8.87, 4.16, 12.0, 4.16)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
