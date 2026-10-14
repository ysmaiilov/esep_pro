import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google аккаунту менен кирүү. Колдонуучу баш тарткан болсо null кайтарат.
final GoogleSignIn _googleSignIn = GoogleSignIn();

Stream<User?> authChanges() => FirebaseAuth.instance.authStateChanges();

User? get currentUser => FirebaseAuth.instance.currentUser;

Future<User?> signInWithGoogle() async {
  final account = await _googleSignIn.signIn();
  if (account == null) return null;
  final auth = await account.authentication;
  final credential = GoogleAuthProvider.credential(
    accessToken: auth.accessToken,
    idToken: auth.idToken,
  );
  final result = await FirebaseAuth.instance.signInWithCredential(credential);
  return result.user;
}

Future<void> signOut() async {
  await _googleSignIn.signOut();
  await FirebaseAuth.instance.signOut();
}
