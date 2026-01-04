import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siparis_frontend/features/admin/ui/admin_dashboard_page.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/auth/ui/login_page.dart';
import 'features/production/ui/production_panel_page.dart';
import 'features/cashier/ui/cashier_panel_page.dart';

class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (!auth.isLoggedIn) {
      return const LoginPage();
    }

    if (auth.role == 'production') {
      return const ProductionPanelPage();
    }

    if (auth.role == 'cashier') {
      return const CashierPanelPage();
    }
    if (auth.role == 'admin') {
      return const AdminDashboardPage();
    }

    return const Scaffold(
      body: Center(child: Text('Rol bulunamadı / Yetkisiz')),
    );
  }
}
