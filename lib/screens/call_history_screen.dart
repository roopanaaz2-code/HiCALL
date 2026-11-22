import 'package:material_ui/material_ui.dart';
import '../services/call_history_service.dart';
import '../services/call_service.dart';
import 'call_screen.dart';
import 'contacts_screen.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<Map<String, dynamic>> _calls = [];
  bool _loading = true;
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
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallScreen(credentials: credentials, remoteName: _name(profile))));
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
                Text('Recent calls', style: TextStyle(color: colors.onSurfaceVariant)),
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
                      leading: CircleAvatar(
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.primary,
                        child: Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded),
                      ),
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
