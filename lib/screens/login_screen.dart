import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final username = TextEditingController();
  final displayName = TextEditingController();
  bool register = false;
  bool busy = false;
  bool obscurePassword = true;
  String? error;
  String? notice;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    username.dispose();
    displayName.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      if (register) {
        if (displayName.text.trim().isEmpty) {
          throw const FormatException('Enter your display name.');
        }
        if (!RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch(username.text.trim())) {
          throw const FormatException('Username must be 3–24 characters using letters, numbers or underscore.');
        }
        await AuthService.instance.signUp(
          email: email.text,
          password: password.text,
          username: username.text,
          displayName: displayName.text,
        );
        if (mounted) {
          setState(() => notice = 'Check your inbox to confirm your email. Open the link on this device to return to HiCALL.');
        }
      } else {
        await AuthService.instance.signIn(email.text, password.text);
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = _friendlyAuthError(e.message));
    } catch (e) {
      if (mounted) setState(() => error = _friendlyAuthError(e.toString()));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _friendlyAuthError(String raw) {
    final message = raw.replaceFirst('AuthRetryableFetchException(message: ', '').replaceFirst(')', '').trim();
    if (message.toLowerCase().contains('profiles_username_lower_unique')) {
      return 'That username is already taken. Try another one.';
    }
    if (message.toLowerCase().contains('invalid login credentials')) {
      return 'Email or password is incorrect.';
    }
    if (message.toLowerCase().contains('database error saving new user')) {
      return 'We could not finish creating this account. Try a different username or contact support if it continues.';
    }
    return message.isEmpty ? 'Something went wrong. Please try again.' : message;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 86,
                      height: 86,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: SvgPicture.asset('assets/hicall_icon.svg'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'HiCALL',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    register ? 'Create your calling account' : 'Talk face to face, wherever you are.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  if (register) ...[
                    TextField(
                      controller: displayName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Display name', prefixIcon: Icon(Icons.person_outline_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: username,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Username', hintText: '3–24 letters, numbers or _', prefixIcon: Icon(Icons.alternate_email_rounded)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => busy ? null : submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: obscurePassword ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                        icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    _MessageBanner(text: error!, isError: true),
                  ],
                  if (notice != null) ...[
                    const SizedBox(height: 14),
                    _MessageBanner(text: notice!, isError: false),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(register ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              register = !register;
                              error = null;
                              notice = null;
                            }),
                    child: Text(register ? 'Already have an account? Sign in' : 'New to HiCALL? Create account'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your phone number is not required to create an account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Theme.of(context).colorScheme.error : const Color(0xFF168254);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.mark_email_read_outlined, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}
