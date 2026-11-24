import 'package:material_ui/material_ui.dart';

class SlideAction extends StatefulWidget {
  const SlideAction({
    super.key,
    required this.label,
    required this.icon,
    required this.glowColor,
    required this.onCompleted,
  });

  final String label;
  final IconData icon;
  final Color glowColor;
  final VoidCallback onCompleted;

  @override
  State<SlideAction> createState() => _SlideActionState();
}

class _SlideActionState extends State<SlideAction> {
  double _offset = 0;
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxOffset = (constraints.maxWidth - 58).clamp(0.0, double.infinity).toDouble();
        return GestureDetector(
          onHorizontalDragUpdate: _completed
              ? null
              : (details) => setState(() {
                    _offset = (_offset + details.delta.dx).clamp(0.0, maxOffset).toDouble();
                  }),
          onHorizontalDragEnd: _completed
              ? null
              : (_) {
                  if (_offset >= maxOffset * 0.78) {
                    setState(() {
                      _offset = maxOffset;
                      _completed = true;
                    });
                    widget.onCompleted();
                  } else {
                    setState(() => _offset = 0);
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 58,
            decoration: BoxDecoration(
              color: widget.glowColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.glowColor.withValues(alpha: 0.72)),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: 0.28),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  _completed ? 'Connecting…' : widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                Positioned(
                  left: 4 + _offset,
                  top: 4,
                  bottom: 4,
                  child: Container(
                    width: 50,
                    decoration: BoxDecoration(
                      color: widget.glowColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: widget.glowColor.withValues(alpha: 0.65),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: const Color(0xFF06101D), size: 25),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// A direct tap alternative with a short water-drop ripple before the action.
class WaterRippleButton extends StatefulWidget {
  const WaterRippleButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  State<WaterRippleButton> createState() => _WaterRippleButtonState();
}

class _WaterRippleButtonState extends State<WaterRippleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _running = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_running || widget.onPressed == null) return;
    setState(() => _running = true);
    await _controller.forward(from: 0);
    if (!mounted) return;
    widget.onPressed?.call();
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || _running;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          foregroundPainter: _WaterRipplePainter(
            progress: _controller.value,
            color: widget.color,
          ),
          child: child,
        ),
        child: Material(
          color: widget.color.withValues(alpha: disabled ? 0.45 : 0.96),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: disabled ? null : _activate,
            splashFactory: InkRipple.splashFactory,
            splashColor: Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white),
                const SizedBox(width: 9),
                Text(
                  _running ? 'Please wait…' : widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaterRipplePainter extends CustomPainter {
  const _WaterRipplePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    // A falling water drop lands first; expanding rings follow the impact.
    final dropY = size.height * (.10 + progress * .40);
    final drop = Path()
      ..moveTo(center.dx, dropY - 9)
      ..cubicTo(center.dx + 10, dropY + 3, center.dx + 8, dropY + 12, center.dx, dropY + 14)
      ..cubicTo(center.dx - 8, dropY + 12, center.dx - 10, dropY + 3, center.dx, dropY - 9)
      ..close();
    canvas.drawPath(drop, Paint()..color = color.withValues(alpha: (1 - progress) * .85));
    for (var i = 0; i < 2; i++) {
      final phase = (progress + i * 0.22) % 1;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * (1 - phase)
        ..color = color.withValues(alpha: (1 - phase) * 0.7);
      canvas.drawCircle(center, 12 + phase * size.width * 0.42, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterRipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
