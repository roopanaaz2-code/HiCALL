import 'package:material_ui/material_ui.dart';
import '../services/call_history_service.dart';
import '../services/call_service.dart';
import 'call_screen.dart';
import 'contacts_screen.dart';
import '../widgets/profile_avatar.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<Map<String, dynamic>> _calls = [];
  bool _loading = true;
  bool _clearing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final calls = await CallHistoryService.instance.load();
      if (mounted) { setState(() => _calls = calls); }
    } catch (_) {
      if (mounted) { setState(() => _error = 'Call history is temporarily unavailable.'); }
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _clearHistory() async {
    if (_calls.isEmpty || _clearing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permanently clear call history?'),
        content: const Text(
          'All call entries will be removed from your HiCALL history and will stay cleared after reopening the app. Other participants keep their own call history.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB83245), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _clearing = true; _error = null; });
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ClearCallHistoryAnimation(),
    );

    try {
      await CallHistoryService.instance.clear();
      if (!mounted) return;
      setState(() => _calls = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call history permanently cleared for your account.')),
      );
    } catch (e) {
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear call history: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  String _name(Map<String, dynamic> profile) {
    final display = profile['display_name'] as String? ?? '';
    return display.trim().isNotEmpty ? display : profile['username'] as String? ?? 'HiCALL user';
  }

  String _time(dynamic value) {
    if (value is! String) { return ''; }
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) { return ''; }
    final today = DateTime.now();
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  String _status(Map<String, dynamic> call) {
    final status = call['status'] as String? ?? '';
    if (status == 'declined') { return 'Declined'; }
    if (status == 'missed') { return 'Missed'; }
    if (status == 'cancelled') { return 'Cancelled'; }
    if (status == 'active') { return 'In progress'; }
    if (status == 'ended') { return 'Completed'; }
    return status.isEmpty ? 'Call' : status;
  }

  Future<void> _redial(Map<String, dynamic> call, String type) async {
    final profile = Map<String, dynamic>.from(call['other_profile'] as Map);
    try {
      final credentials = await CallService.instance.startCall(recipientId: profile['id'] as String, callType: type);
      if (!mounted) { return; }
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallScreen(credentials: credentials, remoteName: _name(profile), remoteAvatarPath: profile['avatar_path'] as String?)));
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to start call: ${e.toString().replaceFirst('Exception: ', '')}'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading && _calls.isEmpty
          ? ListView(children: const [SizedBox(height: 180), Center(child: CircularProgressIndicator())])
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Recent calls', style: TextStyle(color: colors.onSurfaceVariant))),
                    if (_calls.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear call history permanently',
                        onPressed: _clearing ? null : _clearHistory,
                        icon: const CustomPaint(size: Size(24, 24), painter: _BinPainter(color: Color(0xFFFFC247))),
                      ),
                  ],
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: colors.error))),
                if (_calls.isEmpty && !_loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 18),
                    child: Column(children: [
                      Icon(Icons.call_outlined, size: 38, color: colors.primary),
                      const SizedBox(height: 12),
                      const Text('Your calls will appear here', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('Add a contact to start an audio or video call.', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactsScreen())), icon: const Icon(Icons.people_outline), label: const Text('Find contacts')),
                    ]),
                  ),
                ..._calls.map((call) {
                  final profile = Map<String, dynamic>.from(call['other_profile'] as Map);
                  final isVideo = call['call_type'] == 'video';
                  final outgoing = call['direction'] == 'outgoing';
                  return Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      leading: ProfileAvatar(path: profile['avatar_path'] as String?, initials: _name(profile), radius: 20),
                      title: Text(_name(profile), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${outgoing ? 'Outgoing' : 'Incoming'} ${isVideo ? 'video' : 'audio'} · ${_status(call)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_time(call['created_at']), style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                          const SizedBox(height: 5),
                          Icon(outgoing ? Icons.call_made_rounded : Icons.call_received_rounded, size: 16, color: colors.onSurfaceVariant),
                        ],
                      ),
                      onTap: () => _redial(call, isVideo ? 'video' : 'audio'),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _ClearCallHistoryAnimation extends StatefulWidget {
  const _ClearCallHistoryAnimation();

  @override
  State<_ClearCallHistoryAnimation> createState() => _ClearCallHistoryAnimationState();
}

class _ClearCallHistoryAnimationState extends State<_ClearCallHistoryAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
      ..forward();
    Future<void>.delayed(const Duration(milliseconds: 2850), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _page(double start, double end, double rotation, double size) {
    final flight = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeInCubic),
    );
    return AnimatedBuilder(
      animation: flight,
      builder: (context, child) {
        final t = flight.value;
        return Transform.translate(
          offset: Offset((t - 0.5) * rotation * 32, -t * 190),
          child: Transform.rotate(
            angle: rotation * t,
            child: Opacity(
              opacity: (1 - t).clamp(0.0, 1.0).toDouble(),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: size,
        height: size * 1.24,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FC),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFB7C6D8)),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 5))],
        ),
        child: Column(
          children: [
            const Icon(Icons.call_outlined, color: Color(0xFF1678E8), size: 19),
            const SizedBox(height: 8),
            Container(height: 4, decoration: BoxDecoration(color: const Color(0xFF9EADBF), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 5),
            Container(height: 4, width: size * .58, decoration: BoxDecoration(color: const Color(0xFFD0D9E4), borderRadius: BorderRadius.circular(4))),
            const Spacer(),
            const Align(alignment: Alignment.bottomRight, child: Icon(Icons.call_outlined, size: 13, color: Color(0xFF8796A8))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0B172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF28517B))),
      child: SizedBox(
        height: 330,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final broken = _controller.value > .78;
            final crackProgress = ((_controller.value - .78) / .22).clamp(0.0, 1.0).toDouble();
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Clearing call history', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 174,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(top: 8, left: 58, child: _page(.02, .55, -1.0, 58)),
                      Positioned(top: 18, left: 104, child: _page(.12, .68, 1.0, 58)),
                      Positioned(top: 4, right: 104, child: _page(.22, .78, -0.8, 58)),
                      Positioned(top: 20, right: 58, child: _page(.30, .86, 0.9, 58)),
                      Positioned(
                        bottom: 0,
                        child: Transform.rotate(
                          angle: broken ? (crackProgress - .5) * .22 : 0,
                          child: Transform.scale(
                            scale: broken ? 1 - crackProgress * .16 : 1,
                            child: CustomPaint(
                              size: const Size(76, 76),
                              painter: _BinPainter(
                                color: broken
                                    ? Color.lerp(const Color(0xFFFFC247), const Color(0xFFFF5266), crackProgress)!
                                    : const Color(0xFF45B7FF),
                                broken: broken,
                                progress: crackProgress,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (broken)
                        Positioned(
                          bottom: 10,
                          left: 82,
                          child: Transform.rotate(angle: -.45 * crackProgress, child: const _Shard()),
                        ),
                      if (broken)
                        Positioned(
                          bottom: 12,
                          right: 82,
                          child: Transform.rotate(angle: .5 * crackProgress, child: const _Shard()),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  broken ? 'Bin broken. History cleared.' : 'Call log pages are flying into the bin…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


class _Shard extends StatelessWidget {
  const _Shard();

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(22, 22),
        painter: _BinShardPainter(),
      );
}

class _BinShardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFC247)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .18, size.height * .82)
      ..lineTo(size.width * .48, size.height * .16)
      ..lineTo(size.width * .82, size.height * .72)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BinPainter extends CustomPainter {
  const _BinPainter({
    required this.color,
    this.broken = false,
    this.progress = 0,
  });

  final Color color;
  final bool broken;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color.withValues(alpha: .12)
      ..style = PaintingStyle.fill;
    final body = Path()
      ..moveTo(size.width * .22, size.height * .29)
      ..lineTo(size.width * .29, size.height * .88)
      ..quadraticBezierTo(size.width * .5, size.height * .96, size.width * .71, size.height * .88)
      ..lineTo(size.width * .78, size.height * .29)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);
    canvas.drawLine(Offset(size.width * .15, size.height * .25), Offset(size.width * .85, size.height * .25), stroke);
    canvas.drawLine(Offset(size.width * .38, size.height * .17), Offset(size.width * .62, size.height * .17), stroke);
    canvas.drawLine(Offset(size.width * .42, size.height * .39), Offset(size.width * .44, size.height * .77), stroke);
    canvas.drawLine(Offset(size.width * .58, size.height * .39), Offset(size.width * .56, size.height * .77), stroke);
    if (broken) {
      final crack = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .045
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(size.width * .5, size.height * .28)
        ..lineTo(size.width * (.43 - .05 * progress), size.height * .48)
        ..lineTo(size.width * .56, size.height * .58)
        ..lineTo(size.width * (.46 + .08 * progress), size.height * .82);
      canvas.drawPath(path, crack);
    }
  }

  @override
  bool shouldRepaint(covariant _BinPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.broken != broken || oldDelegate.progress != progress;
}
