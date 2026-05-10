import 'package:firebase_auth/firebase_auth.dart';

import 'package:air_sky/features/auth/services/auth_repository.dart';

class UnavailableAuthRepository implements AuthRepository {
  static const String _serviceUnavailableMessage =
      'Auth service is temporarily unavailable. Please try again later.';

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(null);

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    throw FirebaseAuthException(
      code: 'firebase-not-configured',
      message: _serviceUnavailableMessage,
    );
  }

  @override
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    throw FirebaseAuthException(
      code: 'firebase-not-configured',
      message: _serviceUnavailableMessage,
    );
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    throw FirebaseAuthException(
      code: 'firebase-not-configured',
      message: _serviceUnavailableMessage,
    );
  }

  @override
  Future<UserCredential> signInWithGoogle() {
    throw FirebaseAuthException(
      code: 'firebase-not-configured',
      message: _serviceUnavailableMessage,
    );
  }

  @override
  Future<void> signOut() async {
    throw FirebaseAuthException(
      code: 'firebase-not-configured',
      message: _serviceUnavailableMessage,
    );
  }
}



