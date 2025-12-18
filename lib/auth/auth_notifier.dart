import 'package:flutter_riverpod/legacy.dart';
import 'auth_state.dart';
import '../backend/auth_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(AuthService());
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

  Future<bool> login(String email, String password) async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      final user = await _authService.login(email, password);

      state = state.copyWith(
        status: AuthStatus.success,
        isAdmin: user.endsWith("@teiker.ch"),
        errorMessage: null,
      );

      return true;
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
