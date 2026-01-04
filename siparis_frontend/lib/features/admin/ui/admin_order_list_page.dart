import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_orders_provider.dart';

class AdminOrderListPage extends ConsumerWidget {
  final String type;
  const AdminOrderListPage({super.key, required this.type});

  String get title {
    switch (type) {
      case 'late':
        return 'Geciken Siparişler';
      case 'soon':
        return 'Yaklaşan Teslimler';
      case 'no_deposit':
        return 'Kapora Alınmamış Siparişler';
      default:
        return 'Siparişler';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminOrdersProvider(type));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (d) {
          final orders = d['orders'] as List;

          if (orders.isEmpty) {
            return const Center(child: Text('Sipariş bulunamadı'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final o = orders[i];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(o['customer_name'] ?? '—'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o['details'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        'Teslim: ${o['delivery_datetime']}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  trailing: Text('${o['remaining_amount']} ₺'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
