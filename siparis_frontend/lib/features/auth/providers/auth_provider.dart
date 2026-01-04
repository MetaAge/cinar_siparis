import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_state.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _loadFromStorage();
  }

  // -------------------------
  // LOAD (PAGE REFRESH FIX)
  // -------------------------
  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');
    final email = prefs.getString('email');
    final role = prefs.getString('role');

    state = AuthState(
      token: token,
      email: email,
      role: role,
      initialized: true,
    );
  }

  // -------------------------
  // LOGIN
  // -------------------------
  Future<void> login({
    required String token,
    required String email,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('token', token);
    await prefs.setString('email', email);
    await prefs.setString('role', role);

    state = AuthState(
      token: token,
      email: email,
      role: role,
      initialized: true,
    );
  }

  // -------------------------
  // LOGOUT
  // -------------------------
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    state = const AuthState(initialized: true);
  }
}
