import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppBackground {
  AppBackground._();

  static final ValueNotifier<String> theme = ValueNotifier<String>('blue');
  static const _key = 'hicall_background_theme';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null && const ['blue', 'flowers', 'snow'].contains(value)) {
      theme.value = value;
    }
  }

  static Future<void> setTheme(String value) async {
    if (!const ['blue', 'flowers', 'snow'].contains(value)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
    theme.value = value;
  }
}

class HiCallBackground extends StatelessWidget {
  const HiCallBackground({super.key, required this.theme});

  final String theme;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _HiCallBackgroundPainter(theme),
        child: const SizedBox.expand(),
      );
}

class _HiCallBackgroundPainter extends CustomPainter {
  const _HiCallBackgroundPainter(this.theme);
  final String theme;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = switch (theme) {
      'flowers' => const [Color(0xFF230D20), Color(0xFF6B173D), Color(0xFF170D24)],
      'snow' => const [Color(0xFF071A2D), Color(0xFF173B50), Color(0xFF07121E)],
      _ => const [Color(0xFF06152E), Color(0xFF0B2C50), Color(0xFF050B1B)],
    };
    canvas.drawRect(rect, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    ).createShader(rect));

    if (theme == 'flowers') {
      _drawFlowers(canvas, size);
    } else if (theme == 'snow') {
      _drawSnowJungle(canvas, size);
    } else {
      _drawBlueGold(canvas, size);
    }
  }

  void _glow(Canvas canvas, Offset center, double radius, Color color, double opacity) {
    canvas.drawCircle(center, radius, Paint()
      ..color = color.withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48));
  }

  void _drawBlueGold(Canvas canvas, Size size) {
    _glow(canvas, Offset(size.width * .15, size.height * .18), 95, const Color(0xFF168BFF), .5);
    _glow(canvas, Offset(size.width * .88, size.height * .78), 120, const Color(0xFFFFC857), .32);
    final line = Paint()..color = const Color(0x55D7B45C)..strokeWidth = 1.2;
    for (var i = 0; i < 7; i++) {
      canvas.drawArc(Rect.fromCircle(center: Offset(size.width * .85, size.height * .12), radius: 55.0 + i * 17),
          0.4, 2.2, false, line);
    }
    _drawTitle(canvas, size, const Color(0xFFFFD778));
  }

  void _drawTitle(Canvas canvas, Size size, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: 'HiCALL', style: TextStyle(
        fontSize: size.width * .115,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
        foreground: Paint()
          ..shader = const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFFD36C), Color(0xFF61C7FF)])
              .createShader(Rect.fromLTWH(0, 0, size.width, 90)),
        shadows: [Shadow(color: color.withValues(alpha: .75), blurRadius: 22)],
      )),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    painter.paint(canvas, Offset((size.width - painter.width) / 2, size.height * .77));
  }

  void _drawFlowers(Canvas canvas, Size size) {
    _glow(canvas, Offset(size.width * .5, size.height * .45), size.width * .5, const Color(0xFFFF3E75), .5);
    final stem = Paint()..color = const Color(0x8874A66A)..style = PaintingStyle.stroke..strokeWidth = 2.2;
    for (var i = 0; i < 5; i++) {
      final x = size.width * (i / 4);
      final path = Path()
        ..moveTo(x, size.height * 1.05)
        ..cubicTo(x - 28, size.height * .75, x + 32, size.height * .43, x + 5, size.height * .12);
      canvas.drawPath(path, stem);
      final center = Offset(x + (i.isEven ? 5 : -12), size.height * (.13 + (i % 3) * .08));
      for (var p = 0; p < 6; p++) {
        final angle = p * 3.14159 / 3;
        final petal = Offset(center.dx + 13 * ui.lerpDouble(0, 1, 1) * (p.isEven ? 1 : -1) * (p < 3 ? 1 : .55),
            center.dy + (p - 2.5) * 7);
        canvas.drawCircle(petal, 13, Paint()..color = const Color(0x99FF5D91));
      }
      canvas.drawCircle(center, 7, Paint()..color = const Color(0xCCFFD76E));
    }
    _drawTitle(canvas, size, const Color(0xFFFF6C9E));
  }

  void _drawSnowJungle(Canvas canvas, Size size) {
    final snow = Paint()..color = const Color(0xFFB9D7E7);
    final peaks = Path()
      ..moveTo(0, size.height * .42)
      ..lineTo(size.width * .23, size.height * .12)
      ..lineTo(size.width * .38, size.height * .37)
      ..lineTo(size.width * .61, size.height * .08)
      ..lineTo(size.width * .87, size.height * .40)
      ..lineTo(size.width, size.height * .27)
      ..lineTo(size.width, size.height * .62)
      ..lineTo(0, size.height * .62)
      ..close();
    canvas.drawPath(peaks, snow);
    final shade = Paint()..color = const Color(0xFF173A43);
    final ridge = Path()
      ..moveTo(0, size.height * .52)
      ..lineTo(size.width * .2, size.height * .34)
      ..lineTo(size.width * .36, size.height * .55)
      ..lineTo(size.width * .58, size.height * .3)
      ..lineTo(size.width * .8, size.height * .54)
      ..lineTo(size.width, size.height * .4)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(ridge, shade);
    final tree = Paint()..color = const Color(0xFF071B24);
    for (var i = 0; i < 8; i++) {
      final x = size.width * (i / 7);
      final h = size.height * (.24 + (i % 3) * .04);
      final path = Path()
        ..moveTo(x, size.height * .83)
        ..lineTo(x - 28, size.height * .83)
        ..lineTo(x - 7, size.height * .83 - h * .58)
        ..lineTo(x - 22, size.height * .83 - h * .58)
        ..lineTo(x, size.height * .83 - h)
        ..lineTo(x + 22, size.height * .83 - h * .58)
        ..lineTo(x + 7, size.height * .83 - h * .58)
        ..close();
      canvas.drawPath(path, tree);
    }
    // Stylized winter tactical soldierPaint and icy-blue rifle silhouette.
    final soldierPaint = Paint()..color = const Color(0xFF101C27);
    canvas.drawCircle(Offset(size.width * .52, size.height * .60), size.width * .055, soldierPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .45, size.height * .64, size.width * .14, size.height * .22),
      const Radius.circular(18)), soldierPaint);
    canvas.drawLine(Offset(size.width * .47, size.height * .68), Offset(size.width * .37, size.height * .79), soldierPaint..strokeWidth = 15);
    canvas.drawLine(Offset(size.width * .56, size.height * .68), Offset(size.width * .67, size.height * .76), soldierPaint..strokeWidth = 15);
    final rifle = Paint()..color = const Color(0xFF7FDFFF)..strokeWidth = 7..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * .38, size.height * .70), Offset(size.width * .70, size.height * .65), rifle);
    canvas.drawLine(Offset(size.width * .55, size.height * .67), Offset(size.width * .58, size.height * .75), rifle..strokeWidth = 5);
    _glow(canvas, Offset(size.width * .56, size.height * .67), 24, const Color(0xFF69D8FF), .42);
    _drawTitle(canvas, size, const Color(0xFF8BE6FF));
  }

  @override
  bool shouldRepaint(covariant _HiCallBackgroundPainter oldDelegate) =>
      oldDelegate.theme != theme;
}
