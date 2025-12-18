import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'auth_state.dart';
import '../backend/auth_service.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final isAdminProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.maybeWhen(
    data: (user) => AuthService.isAdminEmail(user?.email),
    orElse: () => false,
  );
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

  Future<bool> login(String email, String password) async {
    try {
      state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
      final credential = await _authService.login(email, password);

      state = state.copyWith(
        status: AuthStatus.success,
        isAdmin: AuthService.isAdminEmail(credential.user?.email),
        errorMessage: null,
      );

      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message ?? "Erro ao autenticar.",
      );

      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );

      return false;
    }
  }

  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }

  void reset() {
    state = const AuthState();
  }
}
