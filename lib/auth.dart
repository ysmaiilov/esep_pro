import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google аккаунту менен кирүү. Колдонуучу баш тарткан болсо null кайтарат.
final GoogleSignIn _googleSignIn = GoogleSignIn();

enum AuthFailure { network, config, other }

/// Кирүү ийгиликсиз болгондогу түрү жана коду.
class AuthException implements Exception {
  final AuthFailure kind;
  final String code;
  const AuthException(this.kind, this.code);
  @override
  String toString() => 'AuthException($kind, $code)';
}

Stream<User?> authChanges() => FirebaseAuth.instance.authStateChanges();

User? get currentUser => FirebaseAuth.instance.currentUser;

bool _signingIn = false;

AuthException _classify(Object e) {
  if (e is AuthException) return e;
  if (e is SocketException) return const AuthException(AuthFailure.network, 'socket');
  if (e is PlatformException) {
    final msg = '${e.code} ${e.message}';
    if (e.code == 'network_error' || msg.contains('NETWORK_ERROR')) {
      return AuthException(AuthFailure.network, e.code);
    }
    if (e.code == 'sign_in_failed' || msg.contains('DEVELOPER_ERROR') || msg.contains('ApiException: 10')) {
      return AuthException(AuthFailure.config, e.code);
    }
    return AuthException(AuthFailure.other, e.code);
  }
  if (e is FirebaseAuthException) {
    if (e.code == 'network-request-failed') return AuthException(AuthFailure.network, e.code);
    return AuthException(AuthFailure.other, e.code);
  }
  return AuthException(AuthFailure.other, e.runtimeType.toString());
}

Future<GoogleSignInAuthentication?> _authenticate(GoogleSignInAccount account) async {
  try {
    final auth = await account.authentication;
    return auth.idToken == null ? null : auth;
  } catch (e) {
    debugPrint('Google authentication failed: $e');
    return null;
  }
}

/// null — колдонуучу жокко чыгарды. Ката болсо [AuthException] ыргытат.
Future<User?> signInWithGoogle() async {
  if (_signingIn) return null;
  _signingIn = true;
  try {
    var account = await _googleSignIn.signIn();
    if (account == null) return null;
    var auth = await _authenticate(account);
    if (auth == null) {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      account = await _googleSignIn.signIn();
      if (account == null) return null;
      auth = await _authenticate(account);
      if (auth == null) throw const AuthException(AuthFailure.other, 'no_id_token');
    }
    final credential = GoogleAuthProvider.credential(accessToken: auth.accessToken, idToken: auth.idToken);
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    return result.user;
  } catch (e) {
    if (e is PlatformException) {
      debugPrint('Google sign-in error: code=${e.code} message=${e.message}');
    } else {
      debugPrint('Google sign-in error: $e');
    }
    throw _classify(e);
  } finally {
    _signingIn = false;
  }
}

Future<void> signOut() async {
  try {
    await _googleSignIn.signOut();
  } catch (_) {}
  try {
    await _googleSignIn.disconnect();
  } catch (_) {}
  await FirebaseAuth.instance.signOut();
}
