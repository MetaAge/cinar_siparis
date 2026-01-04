class AuthState {
  final String? token;
  final String? email;
  final String? role;
  final bool initialized;

  const AuthState({
    this.token,
    this.email,
    this.role,
    this.initialized = false,
  });

  bool get isLoggedIn => token != null && role != null;
}
