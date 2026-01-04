import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _kToken = 'auth_token';

  Future<void> save(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, token);
  }

  Future<String?> read() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
  }
}
