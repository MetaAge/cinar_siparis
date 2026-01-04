import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siparis_frontend/features/admin/widgets/order_tile.dart';
import '../providers/admin_orders_provider.dart';

class AdminActiveOrdersPage extends ConsumerWidget {
  const AdminActiveOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Aktif Siparişler')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('Aktif sipariş yok'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final o = orders[i];
              return OrderTile(o: o);
            },
          );
        },
      ),
    );
  }
}
