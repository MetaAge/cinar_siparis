import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/image_proxy.dart';
import '../../production/models/order_model.dart';
import '../providers/cashier_provider.dart';

class CashierOrderHistoryPage extends ConsumerWidget {
  const CashierOrderHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(cashierOrderHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş Siparişler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(cashierOrderHistoryProvider),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('Geçmiş sipariş yok'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _HistoryOrderCard(order: orders[i]),
          );
        },
      ),
    );
  }
}

class _HistoryOrderCard extends StatelessWidget {
  final OrderModel order;
  const _HistoryOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final hasImage = order.imageUrls.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Thumbnail
            if (hasImage) ...[
              _Thumbnail(url: order.imageUrls.first),
              const SizedBox(width: 12),
            ],

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Sipariş #${order.id}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(order.statusLabel),
                        backgroundColor: Colors.green.shade100,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(order.details ?? '-'),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(order.customerName ?? '-')),
                      const Icon(Icons.phone, size: 16),
                      const SizedBox(width: 6),
                      Text(order.customerPhone ?? '-'),
                    ],
                  ),

                  const Divider(height: 24),

                  Row(
                    children: [
                      _Money('Toplam', order.orderTotal),
                      _Money('Kapora', order.depositAmount),
                      _Money('Kalan', order.remainingAmount),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16),
                      const SizedBox(width: 6),
                      Text('Teslim: ${order.deliveryDatetimeFormatted}'),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _showOrderDetail(context, order),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;
  const _Thumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 64,
        height: 64,
        child: DebugNetworkImage(rawUrl: url),
      ),
    );
  }
}

/// 🔐 Converts raw storage URL into Laravel CORS-safe public-image route
String resolveImageUrl(String rawUrl) {
  if (rawUrl.isEmpty) return rawUrl;

  // Example:
  // http://localhost:8000/storage/orders/abc.png
  // → http://localhost:8000/public-image/orders/abc.png
  if (rawUrl.contains('/storage/')) {
    return rawUrl.replaceFirst('/storage/', '/public-image/');
  }

  return rawUrl;
}

class DebugNetworkImage extends StatelessWidget {
  final String rawUrl;
  const DebugNetworkImage({super.key, required this.rawUrl});

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveImageUrl(rawUrl);

    debugPrint('🖼 RAW IMAGE URL: $rawUrl');
    debugPrint('🔁 RESOLVED IMAGE URL: $resolvedUrl');

    return Image.network(
      rawUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, e, __) {
        debugPrint('❌ IMAGE LOAD ERROR: $e');
        return const Center(
          child: Icon(Icons.broken_image, size: 40, color: Colors.black38),
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

class _Money extends StatelessWidget {
  final String label;
  final int? value;
  const _Money(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value != null ? '$value ₺' : '-'),
        ],
      ),
    );
  }
}

void _showOrderDetail(BuildContext context, OrderModel o) {
  showDialog(
    context: context,
    builder:
        (_) => AlertDialog(
          title: Text('Sipariş #${o.id}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('Müşteri', o.customerName),
                _detail('Telefon', o.customerPhone),
                _detail('Sipariş', o.details),
                _detail('Toplam', '${o.orderTotal} ₺'),
                _detail('Kapora', '${o.depositAmount} ₺'),
                _detail('Kalan', '${o.remainingAmount} ₺'),
                _detail('Teslim', o.deliveryDatetimeFormatted),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
  );
}

Widget _detail(String label, String? value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 90, child: Text('$label:')),
        Expanded(child: Text(value ?? '-')),
      ],
    ),
  );
}
