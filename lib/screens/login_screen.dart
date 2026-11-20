import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), password = TextEditingController(), username = TextEditingController(), displayName = TextEditingController();
  bool register = false, busy = false;
  String? error, notice;
  @override void dispose() { email.dispose(); password.dispose(); username.dispose(); displayName.dispose(); super.dispose(); }

  Future<void> submit() async {
    setState(() { busy = true; error = null; notice = null; });
    try {
      if (register) {
        if (!RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch(username.text.trim())) {
          throw Exception('Username must be 3–24 characters using letters, numbers or underscore.');
        }
        await AuthService.instance.signUp(email: email.text, password: password.text, username: username.text, displayName: displayName.text);
        if (mounted) setState(() => notice = 'Check your email to confirm your account, then sign in.');
      } else {
        await AuthService.instance.signIn(email.text, password.text);
      }
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(26), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SvgPicture.asset('assets/hicall_icon.svg', width: 116, height: 116),
        const SizedBox(height: 12),
        const Text('HiCALL', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 2)),
        const SizedBox(height: 8), Text(register ? 'Create your calling account' : 'Clear calls. Simple connections.', textAlign: TextAlign.center),
        const SizedBox(height: 30),
        if (register) ...[
          TextField(controller: displayName, decoration: const InputDecoration(labelText: 'Display name')),
          const SizedBox(height: 12),
          TextField(controller: username, decoration: const InputDecoration(labelText: 'Username (3–24 letters, numbers or _)')),
          const SizedBox(height: 12),
        ],
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
        if (notice != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(notice!, style: const TextStyle(color: Color(0xFF65DDAA)))),
        const SizedBox(height: 22),
        ElevatedButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(register ? 'Create account' : 'Sign in')),
        TextButton(onPressed: busy ? null : () => setState(() { register = !register; error = null; notice = null; }),
          child: Text(register ? 'Already have an account? Sign in' : 'New to HiCALL? Create account')),
      ]))))));
}
