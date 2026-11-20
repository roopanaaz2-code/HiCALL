import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../services/profile_service.dart';
import 'call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  final search = TextEditingController();
  Timer? debounce;
  RealtimeChannel? incomingChannel;
  final Set<String> handledCalls = {};
  List<Map<String, dynamic>> users = [];
  Map<String, dynamic>? me;
  bool loading = false;
  String? error;
  @override void initState() { super.initState(); loadMe(); listenForIncomingCalls(); }
  @override void dispose() {
    debounce?.cancel(); search.dispose();
    if (incomingChannel != null) Supabase.instance.client.removeChannel(incomingChannel!);
    super.dispose();
  }

  Future<void> loadMe() async {
    try { final p = await ProfileService.instance.myProfile(); if (mounted) setState(() => me = p); } catch (_) {}
  }

  void listenForIncomingCalls() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) { return; }
    incomingChannel = Supabase.instance.client.channel('hicall-incoming-$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert, schema: 'public', table: 'call_participants',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
        callback: (payload) {
          final id = payload.newRecord['call_id'] as String?;
          if (id != null) handleIncomingCall(id);
        },
      ).subscribe();
  }

  Future<void> handleIncomingCall(String callId) async {
    if (!mounted || handledCalls.contains(callId)) { return; }
    handledCalls.add(callId);
    try {
      final client = Supabase.instance.client;
      final call = await client.from('call_sessions').select('id, created_by, call_type, status')
        .eq('id', callId).maybeSingle();
      if (call == null || call['status'] != 'ringing' || call['created_by'] == client.auth.currentUser?.id) { return; }
      final caller = await client.from('profiles').select('username, display_name')
        .eq('id', call['created_by']).maybeSingle();
      if (!mounted) { return; }
      final callerName = (caller?['display_name'] as String?)?.isNotEmpty == true
        ? caller!['display_name'] as String : (caller?['username'] as String? ?? 'HiCALL user');
      final isVideo = call['call_type'] == 'video';
      final accepted = await showDialog<bool>(
        context: context, barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(isVideo ? 'Incoming video call' : 'Incoming audio call'),
          content: Text('$callerName is calling you.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Decline')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Accept')),
          ],
        ),
      );
      if (!mounted) { return; }
      if (accepted == true) {
        final credentials = await CallService.instance.joinCall(callId);
        if (!mounted) { return; }
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallScreen(credentials: credentials, remoteName: callerName)));
      } else {
        await CallService.instance.declineCall(callId);
      }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Incoming call error: $e'))); }
    }
  }

  void onSearch(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () => searchUsers(value));
  }
  Future<void> searchUsers(String value) async {
    if (value.trim().length < 3) { if (mounted) { setState(() { users = []; error = null; }); } return; }
    setState(() { loading = true; error = null; });
    try { final result = await ProfileService.instance.searchUsers(value); if (mounted) { setState(() => users = result); } }
    catch (e) { if (mounted) { setState(() => error = e.toString()); } }
    finally { if (mounted) { setState(() => loading = false); } }
  }
  Future<void> startCall(Map<String, dynamic> user, String type) async {
    try {
      final credentials = await CallService.instance.startCall(recipientId: user['id'] as String, callType: type);
      if (!mounted) { return; }
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) =>
        CallScreen(credentials: credentials, remoteName: (user['display_name'] as String?)?.isNotEmpty == true ? user['display_name'] as String : user['username'] as String)));
    } catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to start call: $e'))); } }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('HiCALL', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      actions: [IconButton(tooltip: 'Sign out', onPressed: () => AuthService.instance.signOut(), icon: const Icon(Icons.logout))]),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Text((me?['display_name'] as String?)?.isNotEmpty == true ? 'Hello, ${me!['display_name']}' : 'Make a call',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6), const Text('Search by username to start a call.', style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 22),
      TextField(controller: search, onChanged: onSearch, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search username (min. 3 characters)')),
      const SizedBox(height: 18),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
      if (!loading && search.text.trim().length >= 3 && users.isEmpty && error == null) const Text('No users found.'),
      ...users.map((u) => Card(color: const Color(0xFF101A36), child: ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFF087DE0), child: Icon(Icons.person)),
        title: Text((u['display_name'] as String?)?.isNotEmpty == true ? u['display_name'] as String : u['username'] as String),
        subtitle: Text('@${u['username']}'),
        trailing: Wrap(spacing: 0, children: [
          IconButton(tooltip: 'Audio call', onPressed: () => startCall(u, 'audio'), icon: const Icon(Icons.call, color: Color(0xFF55DDAA))),
          IconButton(tooltip: 'Video call', onPressed: () => startCall(u, 'video'), icon: const Icon(Icons.videocam, color: Color(0xFF16D5F4))),
        ]),
      ))),
      const SizedBox(height: 26), const Divider(color: Colors.white12),
      const ListTile(leading: Icon(Icons.shield_outlined, color: Color(0xFF16D5F4)),
        title: Text('Private by design'), subtitle: Text('Email addresses are not exposed in public profile search.')),
    ]),
  );
}
