import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/features/auth/services/auth_repository.dart';

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._authRepository) : super(const AsyncData<void>(null));

  final AuthRepository _authRepository;

  void clearState() {
    state = const AsyncData<void>(null);
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(
      () => _authRepository.signIn(email: email, password: password),
    );
  }

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

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authRepository.signInWithGoogle(),
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(
      () => _authRepository.sendPasswordResetEmail(email: email),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(_authRepository.signOut);
  }
}



