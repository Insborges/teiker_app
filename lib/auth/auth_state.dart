enum AuthStatus { idle, loading, success, error }

class AuthState {
  final AuthStatus status;
  final bool isAdmin;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.idle,
    this.isAdmin = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? isAdmin,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      isAdmin: isAdmin ?? this.isAdmin,
      errorMessage: errorMessage,
    );
  }
}
