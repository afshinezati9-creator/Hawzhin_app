import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/entities/sticker_entities.dart';

/// پس‌زمینه سطح استیکی‌نت — متنوع و تم‌آگاه
class SurfaceBackground extends StatelessWidget {
  final SurfaceType type;
  final Widget child;

  const SurfaceBackground({
    super.key,
    required this.type,
    required this.child,
  });

  static bool isLightSurface(SurfaceType t, Brightness brightness) {
    if (brightness == Brightness.dark) return false;
    switch (t) {
      case SurfaceType.board:
      case SurfaceType.cork:
      case SurfaceType.wall:
      case SurfaceType.desk:
        return true;
      case SurfaceType.dusk:
      case SurfaceType.ocean:
      case SurfaceType.forest:
      case SurfaceType.door:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(gradient: _gradient(type, light)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _Painter(type, light)),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: light
                      ? [
                          Colors.white.withOpacity(0.22),
                          Colors.transparent,
                          Colors.black.withOpacity(0.04),
                        ]
                      : [
                          Colors.white.withOpacity(0.05),
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  LinearGradient _gradient(SurfaceType t, bool light) {
    switch (t) {
      case SurfaceType.wall:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: light
              ? const [Color(0xFFF4F6FA), Color(0xFFE8ECF3), Color(0xFFDDE3EE)]
              : const [Color(0xFF1B2030), Color(0xFF151925), Color(0xFF10141C)],
        );
      case SurfaceType.desk:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: light
              ? const [Color(0xFFE9D2B8), Color(0xFFD4B08C), Color(0xFFC49A72)]
              : const [Color(0xFF3A2A1C), Color(0xFF2A1E14), Color(0xFF1C140E)],
        );
      case SurfaceType.board:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: light
              ? const [Color(0xFFFFFEFB), Color(0xFFF3F4F6), Color(0xFFE5E7EB)]
              : const [Color(0xFF2A2E36), Color(0xFF1F232A), Color(0xFF171A20)],
        );
      case SurfaceType.cork:
        return LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: light
              ? const [Color(0xFFE8C99A), Color(0xFFD4B07A), Color(0xFFC49A5E)]
              : const [Color(0xFF4A3A24), Color(0xFF3A2E1C), Color(0xFF2A2114)],
        );
      case SurfaceType.door:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: light
              ? const [Color(0xFFB8956F), Color(0xFF9A7550), Color(0xFF7D5E3E)]
              : const [Color(0xFF2E2118), Color(0xFF221811), Color(0xFF16100B)],
        );
      case SurfaceType.dusk:
        // گرادیان بنفش–نارنجی
        return LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: light
              ? const [Color(0xFFFFE0C2), Color(0xFFE8B4D4), Color(0xFFB8A4E8)]
              : const [Color(0xFF3D1F3A), Color(0xFF2A1840), Color(0xFF1A1230)],
        );
      case SurfaceType.ocean:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: light
              ? const [Color(0xFFC8E8F5), Color(0xFF8EC5E0), Color(0xFF5A9FBF)]
              : const [Color(0xFF0E2A3A), Color(0xFF0A1E2C), Color(0xFF06141E)],
        );
      case SurfaceType.forest:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: light
              ? const [Color(0xFFD4E8C8), Color(0xFFA8C99A), Color(0xFF7FA86A)]
              : const [Color(0xFF1A2E18), Color(0xFF122010), Color(0xFF0C160A)],
        );
    }
  }
}

class _Painter extends CustomPainter {
  final SurfaceType type;
  final bool light;
  _Painter(this.type, this.light);

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case SurfaceType.desk:
      case SurfaceType.door:
        _wood(canvas, size);
        break;
      case SurfaceType.cork:
        _cork(canvas, size);
        break;
      case SurfaceType.board:
        _paper(canvas, size);
        break;
      case SurfaceType.wall:
        _dots(canvas, size);
        break;
      case SurfaceType.dusk:
        _softBlobs(canvas, size);
        break;
      case SurfaceType.ocean:
        _waves(canvas, size);
        break;
      case SurfaceType.forest:
        _leaves(canvas, size);
        break;
    }
  }

  void _wood(Canvas canvas, Size size) {
    // رگه‌های چندلایه و نامنظم برای حس چوب واقعی‌تر، با الگوی ثابت و کم‌هزینه.
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < (size.height / 7).ceil(); row++) {
      final y = row * 7.0;
      grain
        ..color = (light ? const Color(0xFF68482E) : const Color(0xFFE0B98D))
            .withOpacity(row.isEven ? 0.055 : 0.025)
        ..strokeWidth = row % 5 == 0 ? 1.2 : 0.65;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x < size.width; x += 34) {
        final bend = math.sin((x / 43) + row * 0.8) * (row % 4 == 0 ? 3.2 : 1.4);
        path.quadraticBezierTo(x + 17, y + bend, x + 34, y + bend * 0.25);
      }
      canvas.drawPath(path, grain);
    }
    // گره‌های ظریف چوب
    for (final knot in [
      Offset(size.width * 0.22, size.height * 0.28),
      Offset(size.width * 0.76, size.height * 0.72),
    ]) {
      final knotPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = (light ? const Color(0xFF68482E) : const Color(0xFFE0B98D))
            .withOpacity(0.08);
      canvas.drawOval(Rect.fromCenter(center: knot, width: 30, height: 9), knotPaint);
      canvas.drawOval(Rect.fromCenter(center: knot, width: 18, height: 4), knotPaint);
    }
  }

  void _cork(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 90; i++) {
      paint.color = (light ? Colors.brown : Colors.white)
          .withOpacity(0.04 + rnd.nextDouble() * 0.06);
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 6 + rnd.nextDouble() * 10,
          height: 4 + rnd.nextDouble() * 8,
        ),
        paint,
      );
    }
  }

  void _paper(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (light ? Colors.black : Colors.white).withOpacity(0.03)
      ..strokeWidth = 1;
    for (var y = 28.0; y < size.height; y += 22) {
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), paint);
    }
  }

  void _dots(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (light ? Colors.black : Colors.white).withOpacity(0.04);
    for (var y = 12.0; y < size.height; y += 18) {
      for (var x = 12.0; x < size.width; x += 18) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  void _softBlobs(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFFFFB347).withOpacity(light ? 0.12 : 0.08);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.25), 80, paint);
    paint.color = const Color(0xFFC084FC).withOpacity(light ? 0.12 : 0.1);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.4), 100, paint);
    paint.color = const Color(0xFF60A5FA).withOpacity(light ? 0.1 : 0.08);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.85), 90, paint);
  }

  void _waves(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (light ? const Color(0xFF0369A1) : Colors.white).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < 8; i++) {
      final y = size.height * (0.15 + i * 0.1);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 20) {
        path.quadraticBezierTo(x + 10, y + math.sin(x / 30 + i) * 6, x + 20, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _leaves(Canvas canvas, Size size) {
    final rnd = math.Random(3);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 40; i++) {
      paint.color = (light ? const Color(0xFF166534) : const Color(0xFF86EFAC))
          .withOpacity(0.06 + rnd.nextDouble() * 0.05);
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + 8, y - 12, x + 4, y - 22)
        ..quadraticBezierTo(x - 6, y - 8, x, y);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) =>
      old.type != type || old.light != light;
}
