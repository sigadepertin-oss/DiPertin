import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/google_sign_in_config.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  serverClientId: kGoogleSignInServerClientId,
  scopes: ['email', 'profile'],
);

/// Login Google -> Firebase Auth.
/// Retorna [UserCredential] ou lança exceção se falhar / usuário cancelar.
Future<UserCredential> signInWithGoogleForFirebase() async {
  try {
    await _googleSignIn.signOut();
  } catch (_) {}

  final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

  if (googleUser == null) {
    throw StateError('Login Google cancelado pelo usuário.');
  }

  final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

  final String? idToken = googleAuth.idToken;
  final String? accessToken = googleAuth.accessToken;

  if (idToken == null && accessToken == null) {
    throw StateError(
      'Google não devolveu idToken nem accessToken. '
      'Confirma SHA-1 no Firebase Console e que o método Google está ativo em Authentication.',
    );
  }

  final OAuthCredential credential = GoogleAuthProvider.credential(
    idToken: idToken,
    accessToken: accessToken,
  );

  return FirebaseAuth.instance.signInWithCredential(credential);
}

/// Sign out do Google (útil para logout completo).
Future<void> signOutGoogle() async {
  try {
    await _googleSignIn.signOut();
  } catch (e) {
    debugPrint('signOutGoogle: $e');
  }
}

/// Tenta reautenticar silenciosamente no Google (sem mostrar o seletor de conta)
/// e completar o login no Firebase. Usado pelo fluxo de "Acessar por Digital"
/// quando o vínculo biométrico local é do tipo Google.
///
/// Se o silent sign-in falhar (sessão expirou, conta removida etc.), faz
/// fallback para o fluxo interativo normal.
Future<UserCredential> signInWithGoogleSilentForFirebase({
  String? emailEsperado,
}) async {
  GoogleSignInAccount? googleUser;
  try {
    googleUser = await _googleSignIn.signInSilently(suppressErrors: true);
  } catch (e) {
    debugPrint('signInSilently falhou: $e');
    googleUser = null;
  }

  if (googleUser == null ||
      (emailEsperado != null &&
          emailEsperado.trim().toLowerCase() !=
              googleUser.email.trim().toLowerCase())) {
    // Fallback: pede para o usuário escolher a conta.
    return signInWithGoogleForFirebase();
  }

  final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

  final String? idToken = googleAuth.idToken;
  final String? accessToken = googleAuth.accessToken;

  if (idToken == null && accessToken == null) {
    // Sem tokens — cai no fluxo interativo.
    return signInWithGoogleForFirebase();
  }

  final OAuthCredential credential = GoogleAuthProvider.credential(
    idToken: idToken,
    accessToken: accessToken,
  );

  return FirebaseAuth.instance.signInWithCredential(credential);
}
