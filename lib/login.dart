import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
    if (busy) return;
    setState(() => busy = true);
    try {
      final user = await signInWithGoogle();
      if (user == null) toast(tr('login_cancelled'));
    } on AuthException catch (e) {
      final suffix = kDebugMode ? ' [${e.code}]' : '';
      toast((e.kind == AuthFailure.network ? tr('login_network') : tr('login_error')) + suffix);
    } catch (e) {
      toast(tr('login_error') + (kDebugMode ? ' [$e]' : ''));
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
/// Аккаунт алмашканда маалымат ошол адамдыкына өзгөрөт.
class AuthGate extends StatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _sub;
  late final Stream<User?> _auth = authChanges().asBroadcastStream();

  @override
  void initState() {
    super.initState();
    _sub = _auth.listen((user) => store.switchUser(user?.uid));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: _auth,
        initialData: currentUser,
        builder: (context, snap) {
          final user = snap.data;
          if (user == null) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return const LoginScreen();
          }
          return ListenableBuilder(
            listenable: store,
            builder: (context, _) => store.loaded
                ? widget.child
                : const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        },
      );
}
