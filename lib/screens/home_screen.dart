import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../services/call_preferences_service.dart';
import 'call_history_screen.dart';
import 'call_screen.dart';
import 'chats_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
import '../widgets/slide_action.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  RealtimeChannel? _incomingChannel;
  final Set<String> _handledCalls = {};
  final Set<String> _processingCalls = {};

  static const _titles = ['Chats', 'Contacts', 'Calls', 'Me'];

  @override
  void initState() {
    super.initState();
    _listenForIncomingCalls();
    unawaited(_checkPendingIncomingCalls());
  }

  void _listenForIncomingCalls() {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) { return; }
    _incomingChannel = client
        .channel('hicall-incoming-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'call_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final id = payload.newRecord['call_id'] as String?;
            if (id != null) { unawaited(_handleIncomingCall(id)); }
          },
        )
        .subscribe();
  }

  Future<void> _checkPendingIncomingCalls() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) { return; }
    try {
      final rows = await client
          .from('call_participants')
          .select('call_id')
          .eq('user_id', userId)
          .order('invited_at', ascending: false)
          .limit(20);
      for (final row in rows) {
        if (!mounted) { return; }
        await _handleIncomingCall(row['call_id'] as String);
      }
    } catch (_) {
      // Realtime remains active; do not expose call or profile data in diagnostics.
    }
  }

  Future<void> _handleIncomingCall(String callId) async {
    if (!mounted || _handledCalls.contains(callId) || !_processingCalls.add(callId)) { return; }
    try {
      final client = Supabase.instance.client;
      final call = await client
          .from('call_sessions')
          .select('id, created_by, call_type, status, expires_at')
          .eq('id', callId)
          .maybeSingle();
      if (call == null || call['status'] != 'ringing' || call['created_by'] == client.auth.currentUser?.id) { return; }
      final expiry = DateTime.tryParse(call['expires_at'] as String? ?? '');
      if (expiry == null || !expiry.isAfter(DateTime.now().toUtc())) { return; }

      final caller = await client
          .from('profiles')
          .select('username, display_name, avatar_path')
          .eq('id', call['created_by'])
          .maybeSingle();
      if (!mounted) { return; }
      final displayName = caller?['display_name'] as String? ?? '';
      final callerName = displayName.trim().isNotEmpty
          ? displayName
          : caller?['username'] as String? ?? 'HiCALL user';
      _handledCalls.add(callId);
      final isVideo = call['call_type'] == 'video';
      await CallPreferencesService.playIncomingRingtone();
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded),
          title: Text(isVideo ? 'Incoming video call' : 'Incoming audio call'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$callerName is calling you.'),
                const SizedBox(height: 18),
                SlideAction(
                  label: 'Slide to answer',
                  icon: Icons.call_rounded,
                  glowColor: const Color(0xFF39D8E8),
                  onCompleted: () => Navigator.pop(dialogContext, true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Decline'),
            ),
          ],
        ),
      );
      await CallPreferencesService.stopIncomingRingtone();
      if (!mounted) { return; }
      if (accepted == true) {
        final credentials = await CallService.instance.joinCall(callId);
        if (!mounted) { return; }
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CallScreen(credentials: credentials, remoteName: callerName),
        ));
      } else {
        await CallService.instance.declineCall(callId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Incoming call could not be handled: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      await CallPreferencesService.stopIncomingRingtone();
      _processingCalls.remove(callId);
    }
  }

  Future<void> _removeIncomingChannel() async {
    final channel = _incomingChannel;
    _incomingChannel = null;
    if (channel != null) { await Supabase.instance.client.removeChannel(channel); }
  }

  @override
  void dispose() {
    unawaited(_removeIncomingChannel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pages = [ChatsScreen(), ContactsScreen(), CallHistoryScreen(), ProfileScreen()];
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => AuthService.instance.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) => setState(() => selectedIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call_rounded),
            label: 'Calls',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
