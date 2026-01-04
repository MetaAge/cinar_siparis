import 'package:dio/dio.dart';

class AuthApi {
  final Dio dio;
  AuthApi(this.dio);

  Future<LoginResult> login(String email, String password) async {
    final res = await dio.post(
      '/login',
      data: {'email': email, 'password': password},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (res.statusCode != 200) {
      final msg =
          (res.data is Map && res.data['message'] != null)
              ? res.data['message'].toString()
              : 'Giriş başarısız';
      throw Exception(msg);
    }

    final data = res.data as Map;
    final token = data['token']?.toString();
    final user = data['user'];

    if (token == null || token.isEmpty || user is! Map) {
      throw Exception('Login response format hatalı');
    }

    return LoginResult(token: token, user: Map<String, dynamic>.from(user));
  }

  Future<void> logout() async {
    await dio.post('/logout');
  }
}

class LoginResult {
  final String token;
  final Map<String, dynamic> user;
  LoginResult({required this.token, required this.user});
}
