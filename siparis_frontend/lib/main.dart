import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'features/auth/providers/auth_provider.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    //Future.microtask(() => ref.read(authProvider.notifier).);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Çınar Sipariş',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const AppRouter(),
    );
  }
}
