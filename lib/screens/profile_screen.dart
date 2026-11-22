import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/phone_service.dart';
import '../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  Map<String, dynamic>? _phone;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ProfileService.instance.myProfile();
      final phone = await PhoneService.instance.ownVerifiedPhone();
      if (!mounted) { return; }
      _displayName.text = profile?['display_name'] as String? ?? '';
      _username.text = profile?['username'] as String? ?? '';
      setState(() {
        _phone = phone;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) { return; }
      setState(() {
        _loading = false;
        _error = 'Profile details are temporarily unavailable. Please try again.';
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProfileService.instance.updateMyProfile(
        username: _username.text,
        displayName: _displayName.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.code == '23505'
          ? 'That username is already taken. Choose another one.'
          : 'Could not save your profile. Please try again.');
    } catch (e) {
      if (mounted) { setState(() => _error = e.toString().replaceFirst('FormatException: ', '')); }
    } finally {
      if (mounted) { setState(() => _saving = false); }
    }
  }

  Future<void> _addPhone() async {
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PhoneVerificationDialog(),
    );
    if (verified == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your number is verified and private.')));
      }
    }
  }

  Future<void> _removePhone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from phone search?'),
        content: const Text('Other users will no longer find your HiCALL profile using this number. Supabase Auth may retain the verified number for account-security use.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove from search')),
        ],
      ),
    );
    if (confirmed != true) { return; }
    try {
      await PhoneService.instance.disableOwnPhoneDiscovery();
      await _load();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your number is hidden from phone search.'))); }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _enablePhoneSearch() async {
    try {
      await PhoneService.instance.enableOwnPhoneDiscovery();
      await _load();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your verified number is searchable again.'))); }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final colors = Theme.of(context).colorScheme;
    if (_loading) { return const Center(child: CircularProgressIndicator()); }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(Icons.person_rounded, size: 42, color: colors.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  _displayName.text.isEmpty ? 'Your HiCALL profile' : _displayName.text,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 3),
                  Text(user!.email!, style: TextStyle(color: colors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Your profile'),
          const SizedBox(height: 10),
          TextField(
            controller: _displayName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Display name', prefixIcon: Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email_rounded)),
          ),
          const SizedBox(height: 12),
          if (_error != null) _InlineMessage(text: _error!, isError: true),
          if (_error != null) const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _saving ? null : _saveProfile,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: const Text('Save profile'),
          ),
          const SizedBox(height: 26),
          _sectionTitle(context, 'Private phone number'),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.privacy_tip_outlined, color: colors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _phone == null
                                  ? 'No verified number yet'
                                  : (_phone!['discoverable'] == true ? 'Verified and searchable' : 'Verified, hidden from search'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _phone == null
                                  ? 'Add your number privately with SMS verification. It stays hidden until you explicitly enable search.'
                                  : '${_phone!['phone_e164']}\n${_phone!['discoverable'] == true ? 'Other users may find your profile by entering this exact number, but they will never see the number itself.' : 'Only you can see this number in your profile. It is currently hidden from other users’ phone search.'}',
                              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_phone == null)
                    OutlinedButton.icon(
                      onPressed: _addPhone,
                      icon: const Icon(Icons.add_call),
                      label: const Text('Add and verify number'),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(onPressed: _addPhone, icon: const Icon(Icons.edit_outlined), label: const Text('Change number')),
                        TextButton.icon(
                          onPressed: _phone!['discoverable'] == true ? _removePhone : _enablePhoneSearch,
                          icon: Icon(_phone!['discoverable'] == true ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          label: Text(_phone!['discoverable'] == true ? 'Remove from search' : 'Enable search'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your phone number is not shown on public profiles, contact cards, chats, or call screens. Supabase Auth may retain it for account-security use. SMS verification must be enabled by the service administrator.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      );
}

class _PhoneVerificationDialog extends StatefulWidget {
  const _PhoneVerificationDialog();

  @override
  State<_PhoneVerificationDialog> createState() => _PhoneVerificationDialogState();
}

class _PhoneVerificationDialogState extends State<_PhoneVerificationDialog> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() { _busy = true; _error = null; });
    try {
      await PhoneService.instance.requestVerification(_phone.text);
      if (mounted) { setState(() => _codeSent = true); }
    } catch (e) {
      if (mounted) { setState(() => _error = _friendly(e)); }
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Future<void> _verify() async {
    setState(() { _busy = true; _error = null; });
    try {
      await PhoneService.instance.verify(_phone.text, _code.text);
      if (mounted) { Navigator.pop(context, true); }
    } catch (e) {
      if (mounted) { setState(() => _error = _friendly(e)); }
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  String _friendly(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').replaceFirst('FormatException: ', '');
    if (text.toLowerCase().contains('provider') || text.toLowerCase().contains('sms')) {
      return 'SMS verification is not configured for HiCALL yet. Ask the administrator to enable an SMS provider in Supabase.';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Verify your number'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your full number with country code. HiCALL uses it only for private number discovery.'),
              const SizedBox(height: 14),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                enabled: !_codeSent && !_busy,
                decoration: const InputDecoration(labelText: 'Phone number', hintText: '+14155550123', prefixIcon: Icon(Icons.phone_outlined)),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'SMS code', prefixIcon: Icon(Icons.sms_outlined)),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                _InlineMessage(text: _error!, isError: true),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_codeSent ? 'Verify number' : 'Send code'),
          ),
        ],
      );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: TextStyle(color: color, fontSize: 13, height: 1.35)),
    );
  }
}
