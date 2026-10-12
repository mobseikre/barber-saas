import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const _tileRadiusRatio = 0.22;
const _stripes = [AppColors.poleRed, AppColors.surface, AppColors.poleBlue, AppColors.surface];

/// Barber pole on a dark blue tile; mirrors `tool/generate_app_icons.py`.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.blue900,
        borderRadius: BorderRadius.circular(size * _tileRadiusRatio),
        border: Border.all(color: AppColors.bluePressed),
      ),
      child: CustomPaint(painter: _BarberPolePainter()),
    );
  }
}

class _BarberPolePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Rect r(double l, double t, double rr, double b) => Rect.fromLTRB(l * s, t * s, rr * s, b * s);
    RRect rr(Rect rect, double radius) => RRect.fromRectAndRadius(rect, Radius.circular(radius * s));
    final fill = Paint();

    canvas.drawCircle(Offset(0.5 * s, 0.215 * s), 0.085 * s, fill..color = AppColors.surface);
    canvas.drawRect(r(0.46, 0.295, 0.54, 0.33), fill..color = AppColors.poleChromeShade);

    final tail = Path()
      ..moveTo(0.44 * s, 0.725 * s)
      ..lineTo(0.56 * s, 0.725 * s)
      ..lineTo(0.535 * s, 0.78 * s)
      ..lineTo(0.465 * s, 0.78 * s)
      ..close();
    canvas.drawPath(tail, fill..color = AppColors.poleChromeShade);

    const bodyLeft = 0.39, bodyRight = 0.61, bodyTop = 0.385, bodyBottom = 0.665, band = 0.0525;
    canvas.save();
    canvas.clipRect(r(bodyLeft, bodyTop, bodyRight, bodyBottom));
    const width = bodyRight - bodyLeft;
    var i = 0;
    for (var c = bodyTop - width; c < bodyBottom + width; c += band, i++) {
      final path = Path()
        ..moveTo(bodyLeft * s, c * s)
        ..lineTo(bodyRight * s, (c - width) * s)
        ..lineTo(bodyRight * s, (c - width + band) * s)
        ..lineTo(bodyLeft * s, (c + band) * s)
        ..close();
      canvas.drawPath(path, fill..color = _stripes[i % _stripes.length]);
    }
    canvas.restore();

    canvas.drawRRect(rr(r(0.33, 0.325, 0.67, 0.385), 0.03), fill..color = AppColors.poleChrome);
    canvas.drawRRect(rr(r(0.33, 0.665, 0.67, 0.725), 0.03), fill..color = AppColors.poleChrome);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
