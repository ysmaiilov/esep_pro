import 'package:flutter/material.dart';
import 'auth.dart';
import 'store.dart';
import 'ui.dart';

/// Биринчи экран: Google аккаунту менен кирүү.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool busy = false;

  Future<void> _login() async {
    setState(() => busy = true);
    try {
      final user = await signInWithGoogle();
      if (user == null) toast(tr('login_cancelled'));
    } catch (_) {
      toast(tr('login_error'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Icon(Icons.storefront_rounded, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text(tr('login_title'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(tr('login_desc'), textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 40),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: busy ? null : _login,
                icon: busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login_rounded),
                label: Text(tr('login_google')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Колдонуучу кирген болсо — негизги экран, болбосо кирүү экраны.
class AuthGate extends StatelessWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});
  @override
  Widget build(BuildContext context) => StreamBuilder(
        stream: authChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snap.data == null ? const LoginScreen() : child;
        },
      );
}
