import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/call_service.dart';
import '../services/messaging_service.dart';
import 'call_screen.dart';

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({super.key, required this.conversationId, required this.otherProfile});

  final String conversationId;
  final Map<String, dynamic> otherProfile;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final Set<String> _messageIds = {};
  final List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  String get _userId => Supabase.instance.client.auth.currentUser!.id;

  String get _name {
    final displayName = widget.otherProfile['display_name'] as String? ?? '';
    return displayName.trim().isNotEmpty ? displayName : widget.otherProfile['username'] as String? ?? 'HiCALL user';
  }

  @override
  void initState() {
    super.initState();
    _channel = MessagingService.instance.subscribeToMessages(widget.conversationId, _onMessage);
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    final channel = _channel;
    if (channel != null) { unawaited(MessagingService.instance.closeChannel(channel)); }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await MessagingService.instance.listMessages(widget.conversationId);
      if (!mounted) { return; }
      setState(() {
        for (final row in rows) {
          final id = row['id'] as String;
          if (_messageIds.add(id)) { _messages.add(row); }
        }
        _messages.sort((a, b) => _timestamp(a).compareTo(_timestamp(b)));
        _loading = false;
      });
      _scrollToLatest();
    } catch (_) {
      if (mounted) { setState(() { _loading = false; _error = 'Messages could not be loaded. Check your connection and try again.'; }); }
    }
  }

  DateTime _timestamp(Map<String, dynamic> row) => DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

  void _onMessage(Map<String, dynamic> message) {
    if (!mounted) { return; }
    final id = message['id'] as String?;
    if (id == null || !_messageIds.add(id)) { return; }
    setState(() {
      _messages.add(message);
      _messages.sort((a, b) => _timestamp(a).compareTo(_timestamp(b)));
    });
    _scrollToLatest();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) { _scroll.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut); }
    });
  }

  Future<void> _send() async {
    final value = _text.text.trim();
    if (value.isEmpty || _sending) { return; }
    if (value.length > 4000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Messages must be 4,000 characters or fewer.')));
      return;
    }
    setState(() => _sending = true);
    try {
      await MessagingService.instance.sendMessage(widget.conversationId, value);
      _text.clear();
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Message not sent: ${e.toString().replaceFirst('Exception: ', '')}'))); }
    } finally {
      if (mounted) { setState(() => _sending = false); }
    }
  }

  Future<void> _startCall(String type) async {
    try {
      final credentials = await CallService.instance.startCall(
        recipientId: widget.otherProfile['id'] as String,
        callType: type,
      );
      if (!mounted) { return; }
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallScreen(credentials: credentials, remoteName: _name)));
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to start call: ${e.toString().replaceFirst('Exception: ', '')}'))); }
    }
  }

  String _time(Map<String, dynamic> message) {
    final date = _timestamp(message).toLocal();
    if (date.millisecondsSinceEpoch == 0) { return ''; }
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reversed = _messages.reversed.toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.primary,
              child: Text(_name.isEmpty ? 'H' : _name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  Text('@${widget.otherProfile['username'] ?? ''}', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Audio call', onPressed: () => _startCall('audio'), icon: const Icon(Icons.call_rounded)),
          IconButton(tooltip: 'Video call', onPressed: () => _startCall('video'), icon: const Icon(Icons.videocam_rounded)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              MaterialBanner(
                content: Text(_error!),
                actions: [TextButton(onPressed: _load, child: const Text('Retry'))],
              ),
            Expanded(
              child: _loading && _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.waving_hand_outlined, color: colors.primary, size: 36),
                                const SizedBox(height: 12),
                                const Text('Say hello', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 5),
                                Text('Start a private conversation with $_name.', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          itemCount: reversed.length,
                          itemBuilder: (context, index) {
                            final message = reversed[index];
                            final own = message['sender_id'] == _userId;
                            return Align(
                              alignment: own ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 7),
                                decoration: BoxDecoration(
                                  color: own ? colors.primary : colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(own ? 18 : 5),
                                    bottomRight: Radius.circular(own ? 5 : 18),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(message['body'] as String? ?? '', style: TextStyle(color: own ? Colors.white : colors.onSurface, height: 1.3)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(_time(message), style: TextStyle(fontSize: 10, color: own ? Colors.white70 : colors.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
              decoration: BoxDecoration(color: colors.surface, border: Border(top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 4000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Message', counterText: '', isDense: true),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
