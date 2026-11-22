import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../services/call_service.dart';
import '../services/contact_service.dart';
import '../services/messaging_service.dart';
import '../services/phone_service.dart';
import '../services/profile_service.dart';
import 'call_screen.dart';
import 'direct_chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _results = [];
  bool _loadingContacts = true;
  bool _searching = false;
  String? _error;
  String? _searchedValue;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _loadingContacts = true);
    try {
      final rows = await ContactService.instance.listContacts();
      if (mounted) setState(() => _contacts = rows);
    } catch (_) {
      if (mounted) setState(() => _error = 'Contacts are temporarily unavailable. Please try again.');
    } finally {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    _searchGeneration++;
    if (query.length < 3) {
      setState(() {
        _results = [];
        _error = null;
        _searchedValue = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _results = [];
      _error = null;
      _searchedValue = query;
      _searching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 450), () => _searchPeople(value));
  }

  bool _looksLikePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 8 && RegExp(r'^[+0-9\s().-]+$').hasMatch(value.trim());
  }

  Future<void> _searchPeople(String value) async {
    final query = value.trim();
    if (query.length < 3) return;
    final generation = ++_searchGeneration;
    setState(() {
      _searching = true;
      _error = null;
      _searchedValue = query;
    });
    try {
      final List<Map<String, dynamic>> matches;
      if (_looksLikePhone(query)) {
        final result = await PhoneService.instance.searchByPhone(query);
        matches = result == null ? [] : [result];
      } else {
        matches = await ProfileService.instance.searchUsers(query);
      }
      if (mounted && generation == _searchGeneration) setState(() => _results = matches);
    } catch (e) {
      if (mounted && generation == _searchGeneration) {
        final message = e.toString().replaceFirst('Exception: ', '').replaceFirst('FormatException: ', '');
        setState(() {
          _results = [];
          _error = message.contains('E.164') || message.contains('country code')
              ? 'For phone search, include the +country code, for example +14155550123.'
              : message;
        });
      }
    } finally {
      if (mounted && generation == _searchGeneration) setState(() => _searching = false);
    }
  }

  Future<void> _addByNumber() async {
    final controller = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add by phone number'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+14155550123',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Find account')),
        ],
      ),
    );
    controller.dispose();
    if (phone == null || phone.isEmpty) return;
    _search.text = phone;
    await _searchPeople(phone);
  }

  Future<void> _addContact(Map<String, dynamic> person) async {
    try {
      await ContactService.instance.addContact(person['id'] as String);
      await _loadContacts();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact added.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _removeContact(Map<String, dynamic> person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove contact?'),
        content: Text('Remove ${_name(person)} from your contacts? Existing chat history will remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove contact')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await ContactService.instance.removeContact(person['id'] as String);
      await _loadContacts();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact removed.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _openChat(Map<String, dynamic> person) async {
    try {
      final userId = person['id'] as String;
      if (!await ContactService.instance.isContact(userId)) {
        await ContactService.instance.addContact(userId);
        await _loadContacts();
      }
      final conversationId = await MessagingService.instance.openConversation(userId);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DirectChatScreen(conversationId: conversationId, otherProfile: person),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _startCall(Map<String, dynamic> person, String type) async {
    try {
      final credentials = await CallService.instance.startCall(
        recipientId: person['id'] as String,
        callType: type,
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(credentials: credentials, remoteName: _name(person)),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to start call: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  String _name(Map<String, dynamic> person) {
    final displayName = person['display_name'] as String? ?? '';
    return displayName.trim().isNotEmpty ? displayName : person['username'] as String? ?? 'HiCALL user';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isSearching = _searchedValue != null && _searchedValue!.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _loadContacts,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            'Find people and start a private conversation.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _searchPeople,
                  decoration: const InputDecoration(
                    hintText: 'Search username or phone',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              FilledButton.tonalIcon(
                onPressed: _addByNumber,
                icon: const Icon(Icons.add_call, size: 19),
                label: const Text('Add number'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Search by exact username or full phone number with country code. Exact phone lookup can reveal that an account exists, but the number itself is never shown to other users.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12, height: 1.35),
          ),
          if (_searching) ...[
            const SizedBox(height: 14),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _HintCard(icon: Icons.info_outline, text: _error!, color: colors.error),
          ],
          if (!_searching && isSearching && _results.isEmpty && _error == null) ...[
            const SizedBox(height: 18),
            const _EmptyState(icon: Icons.person_search_outlined, title: 'No account found', message: 'Check the username or enter the exact verified phone number.'),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _Heading('Search results'),
            const SizedBox(height: 8),
            ..._results.map((person) => _PersonCard(
                  person: person,
                  isContact: _contacts.any((c) => c['id'] == person['id']),
                  onAdd: () => _addContact(person),
                  onRemove: () => _removeContact(person),
                  onChat: () => _openChat(person),
                  onAudio: () => _startCall(person, 'audio'),
                  onVideo: () => _startCall(person, 'video'),
                  name: _name(person),
                )),
          ],
          if (!isSearching) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: _Heading('My contacts')),
                if (_loadingContacts) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            if (!_loadingContacts && _contacts.isEmpty)
              const _EmptyState(icon: Icons.people_outline_rounded, title: 'No contacts yet', message: 'Search by username or use Add number to find someone.'),
            ..._contacts.map((person) => _PersonCard(
                  person: person,
                  isContact: true,
                  onAdd: () {},
                  onRemove: () => _removeContact(person),
                  onChat: () => _openChat(person),
                  onAudio: () => _startCall(person, 'audio'),
                  onVideo: () => _startCall(person, 'video'),
                  name: _name(person),
                )),
          ],
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.isContact,
    required this.onAdd,
    required this.onRemove,
    required this.onChat,
    required this.onAudio,
    required this.onVideo,
    required this.name,
  });

  final Map<String, dynamic> person;
  final bool isContact;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onChat;
  final VoidCallback onAudio;
  final VoidCallback onVideo;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final username = person['username'] as String? ?? 'user';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.primary,
              child: Text(name.isEmpty ? 'H' : name.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('@$username', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            if (!isContact)
              IconButton.filledTonal(onPressed: onAdd, tooltip: 'Add contact', icon: const Icon(Icons.person_add_alt_1_rounded))
            else ...[
              IconButton(onPressed: onChat, tooltip: 'Message', icon: const Icon(Icons.chat_bubble_outline_rounded)),
              IconButton(onPressed: onAudio, tooltip: 'Audio call', icon: const Icon(Icons.call_rounded, color: Color(0xFF168254))),
              IconButton(onPressed: onVideo, tooltip: 'Video call', icon: const Icon(Icons.videocam_rounded, color: Color(0xFF1678E8))),
              PopupMenuButton<String>(
                tooltip: 'Contact options',
                onSelected: (value) {
                  if (value == 'remove') onRemove();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'remove', child: Text('Remove contact')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 18),
      child: Column(children: [
        Icon(icon, size: 34, color: colors.primary),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, height: 1.35)),
      ]),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 19), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13, height: 1.35)))]),
      );
}
