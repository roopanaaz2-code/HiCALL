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
