import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/messaging_service.dart';
import 'contacts_screen.dart';
import 'direct_chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await MessagingService.instance.listConversations();
      if (mounted) setState(() => _conversations = rows);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chats are temporarily unavailable. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _name(Map<String, dynamic> profile) {
    final displayName = profile['display_name'] as String? ?? '';
    return displayName.trim().isNotEmpty ? displayName : profile['username'] as String? ?? 'HiCALL user';
  }

  String _preview(Map<String, dynamic>? message) {
    if (message == null) return 'Start your conversation';
    final body = (message['body'] as String? ?? '').replaceAll('\n', ' ');
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return '${message['sender_id'] == currentUserId ? 'You: ' : ''}$body';
  }

  String _time(dynamic value) {
    if (value is! String) return '';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}';
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final profile = Map<String, dynamic>.from(row['other_profile'] as Map);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DirectChatScreen(
        conversationId: row['id'] as String,
        otherProfile: profile,
      ),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading && _conversations.isEmpty
          ? ListView(children: const [SizedBox(height: 180), Center(child: CircularProgressIndicator())])
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Text('Your conversations', style: TextStyle(color: colors.onSurfaceVariant)),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: colors.error)),
                  ),
                if (_conversations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
                          child: Icon(Icons.chat_bubble_outline_rounded, color: colors.primary, size: 34),
                        ),
                        const SizedBox(height: 18),
                        const Text('Start a conversation', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 7),
                        Text('Add someone by username or verified phone number, then send a message or call.', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, height: 1.4)),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactsScreen())),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Find people'),
                        ),
                      ],
                    ),
                  ),
                ..._conversations.map((row) {
                  final profile = Map<String, dynamic>.from(row['other_profile'] as Map);
                  final name = _name(profile);
                  final message = row['latest_message'] is Map ? Map<String, dynamic>.from(row['latest_message'] as Map) : null;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.primary,
                        child: Text(name.isEmpty ? 'H' : name.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_preview(message), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      trailing: Text(_time(message?['created_at']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
                      onTap: () => _open(row),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
