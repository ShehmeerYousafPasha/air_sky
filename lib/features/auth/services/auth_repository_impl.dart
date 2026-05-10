import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:air_sky/features/auth/services/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._firebaseAuth, this._firestore)
      : _googleSignIn = GoogleSignIn();

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final UserCredential credential = await _firebaseAuth
        .signInWithEmailAndPassword(email: email, password: password);

    final User? user = credential.user;
    if (user != null) {
      await user.reload();
      final User? refreshedUser = _firebaseAuth.currentUser;
      if (refreshedUser != null && !refreshedUser.emailVerified) {
        await _firebaseAuth.signOut();
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message:
              'Verify your email address before logging in. Check your inbox for the verification link.',
        );
      }
    }

    return credential;
  }

  @override
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final UserCredential credential = await _firebaseAuth
        .createUserWithEmailAndPassword(email: email, password: password);

    final User? user = credential.user;
    if (user != null) {
      await user.updateDisplayName(name);
      await user.sendEmailVerification();
      await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
        'uid': user.uid,
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'isGuest': false,
      }, SetOptions(merge: true));
      await _firebaseAuth.signOut();
    }

    return credential;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-cancelled',
        message: 'Google Sign-In was cancelled by user.',
      );
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential =
        await _firebaseAuth.signInWithCredential(credential);

    final User? user = userCredential.user;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'uid': user.uid,
          'name': user.displayName ?? 'Google User',
          'email': user.email ?? '',
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'isGuest': false,
        },
        SetOptions(merge: true),
      );
    }

    return userCredential;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}



