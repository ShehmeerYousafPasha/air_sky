import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/features/auth/services/auth_repository.dart';

/// State controller for authentication operations.
///
/// Manages async state for:
/// - Email/password sign in and sign up
/// - Google Sign-In
/// - Password reset email
/// - Sign out
///
/// Returns [AsyncValue<void>] to UI for loading/error states:
/// - [AsyncLoading]: Operation in progress
/// - [AsyncData]: Success
/// - [AsyncError]: Failure with error details
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._authRepository) : super(const AsyncData<void>(null));

  final AuthRepository _authRepository;

  /// Clears auth state, typically called when entering auth screens.
  void clearState() {
    state = const AsyncData<void>(null);
  }

  /// Attempts to sign in with email and password.
  /// 
  /// Sets state to [AsyncLoading] during operation.
  /// On success, Firebase Auth is updated and authStateChangesProvider notifies.
  /// On failure, state becomes [AsyncError] with user-friendly message.
  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(
      () => _authRepository.signIn(email: email, password: password),
    );
  }

  /// Attempts to create a new user account.
  ///
  /// Email verification is sent after successful signup.
  /// User is signed out automatically until email is verified.
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(
      () =>
          _authRepository.signUp(name: name, email: email, password: password),
    );
  }

  /// Attempts to sign in using Google OAuth.
  ///
  /// Opens Google Sign-In flow; user completes login via Google account selector.
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authRepository.signInWithGoogle(),
    );
  }

  /// Sends password reset email to provided address.
  /// 
  /// No authentication required; anyone can request reset for any email.
  Future<void> sendPasswordResetEmail({required String email}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(
      () => _authRepository.sendPasswordResetEmail(email: email),
    );
  }

  /// Signs out the current user.
  ///
  /// Clears Firebase Auth session; authStateChangesProvider notifies with null User.
  Future<void> signOut() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(_authRepository.signOut);
  }
}



