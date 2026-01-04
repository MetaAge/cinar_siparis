import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';

class RoleGuard extends ConsumerWidget {
  final String requiredRole;
  final Widget child;

  const RoleGuard({super.key, required this.requiredRole, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    // 1️⃣ Storage henüz okunmadı → bekle
    if (!auth.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 2️⃣ Login yok
    if (!auth.isLoggedIn) {
      return const Scaffold(body: Center(child: Text('Giriş yapılmamış')));
    }

    // 3️⃣ Rol uyuşmuyor
    if (auth.role != requiredRole) {
      return const Scaffold(
        body: Center(child: Text('Rol bulunamadı / Yetkisiz')),
      );
    }

    // 4️⃣ Her şey OK
    return child;
  }
}
