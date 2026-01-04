import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/order_model.dart';
import '../providers/production_providers.dart';

class ProductionPanelPage extends ConsumerStatefulWidget {
  const ProductionPanelPage({super.key});

  @override
  ConsumerState<ProductionPanelPage> createState() =>
      _ProductionPanelPageState();
}

class _ProductionPanelPageState extends ConsumerState<ProductionPanelPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  Timer? _pollingTimer;
  final TextEditingController _customerFilterCtrl = TextEditingController();
  String _customerFilter = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);

    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.invalidate(productionTodayProvider);
      ref.invalidate(productionLateProvider);
      ref.invalidate(productionUpcomingProvider);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _customerFilterCtrl.dispose();
    _tab.dispose();
    super.dispose();
  }

  void _refreshCurrentTab() {
    final idx = _tab.index;
    if (idx == 0) ref.invalidate(productionTodayProvider);
    if (idx == 1) ref.invalidate(productionLateProvider);
    if (idx == 2) ref.invalidate(productionUpcomingProvider);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('İmalat Paneli'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _refreshCurrentTab,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Çıkış',
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
          if (auth.email != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(auth.email!, style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Bugün'),
            Tab(text: 'Geciken'),
            Tab(text: 'Yaklaşan'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _customerFilterCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Müşteri adına göre filtrele',
                isDense: true,
              ),
              onChanged: (v) {
                setState(() => _customerFilter = v.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _OrdersTab(
                  kind: _OrdersKind.today,
                  customerFilter: _customerFilter,
                ),
                _OrdersTab(
                  kind: _OrdersKind.late,
                  customerFilter: _customerFilter,
                ),
                _OrdersTab(
                  kind: _OrdersKind.upcoming,
                  customerFilter: _customerFilter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _OrdersKind { today, late, upcoming }

class _OrdersTab extends ConsumerWidget {
  final _OrdersKind kind;
  final String customerFilter;
  const _OrdersTab({required this.kind, required this.customerFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = switch (kind) {
      _OrdersKind.today => ref.watch(productionTodayProvider),
      _OrdersKind.late => ref.watch(productionLateProvider),
      _OrdersKind.upcoming => ref.watch(productionUpcomingProvider),
    };

    final title = switch (kind) {
      _OrdersKind.today => 'Bugün Teslim',
      _OrdersKind.late => 'Geciken Siparişler',
      _OrdersKind.upcoming => 'Yaklaşan Teslim',
    };

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (e, _) => _ErrorState(
            title: title,
            message: e.toString(),
            onRetry: () {
              if (kind == _OrdersKind.today)
                ref.invalidate(productionTodayProvider);
              if (kind == _OrdersKind.late)
                ref.invalidate(productionLateProvider);
              if (kind == _OrdersKind.upcoming)
                ref.invalidate(productionUpcomingProvider);
            },
          ),
      data: (orders) {
        final filteredOrders =
            customerFilter.isEmpty
                ? orders
                : orders.where((o) {
                  final name = (o.customerName ?? '').toLowerCase();
                  return name.contains(customerFilter);
                }).toList();

        Widget densityHeader() {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.bar_chart, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                Text(
                  'Toplam Sipariş: ${filteredOrders.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        if (filteredOrders.isEmpty) {
          return const _EmptyState(title: 'Sonuç bulunamadı');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            densityHeader(),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filteredOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final o = filteredOrders[i];
                  return _OrderCard(
                    order: o,
                    highlight: kind == _OrdersKind.late,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final bool highlight;

  const _OrderCard({required this.order, required this.highlight});

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _loading = false;

  Widget _remainingTimeBadge(DateTime? delivery) {
    if (delivery == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final diff = delivery.difference(now);

    Color bg;
    String text;

    if (diff.isNegative) {
      bg = Colors.red;
      text = 'Gecikti';
    } else if (diff.inHours <= 24) {
      bg = Colors.orange;
      text = '${diff.inHours} sa';
    } else {
      bg = Colors.blue;
      text = '${diff.inDays} gün';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: bg, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _markReady() async {
    setState(() => _loading = true);

    try {
      await ref.read(markReadyProvider(widget.order.id).future);

      ref.invalidate(productionTodayProvider);
      ref.invalidate(productionLateProvider);
      ref.invalidate(productionUpcomingProvider);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDetails(BuildContext context) {
    final o = widget.order;
    final hasImages = o.imageUrls.isNotEmpty;
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Sipariş #${o.id} Detayları'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Görseller bölümü
                  if (hasImages) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        "Sipariş Görselleri",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children:
                            o.imageUrls.map((url) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => _FullscreenImage(url: url),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: DebugNetworkImage(rawUrl: url),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                  // Müşteri Bilgileri bölümü başlığı
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      "Müşteri Bilgileri",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _detailRowPolished('Müşteri', o.customerName ?? '-'),
                  _detailRowPolished('Telefon', o.customerPhone ?? '-'),
                  const SizedBox(height: 16),
                  // Sipariş Bilgileri bölümü başlığı
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      "Sipariş Bilgileri",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _detailRowPolished('Sipariş', o.details ?? '-'),
                  const SizedBox(height: 8),
                  _detailRowPolished(
                    'Toplam',
                    '${o.orderTotal.toString() ?? '-'} ₺',
                  ),
                  _detailRowPolished(
                    'Kapora',
                    '${o.depositAmount.toString() ?? 0} ₺',
                  ),
                  _detailRowPolished(
                    'Kalan',
                    '${o.remainingAmount.toString() ?? '-'} ₺',
                  ),
                  const SizedBox(height: 8),
                  _detailRowPolished(
                    'Teslim',
                    o.deliveryDatetimeFormatted ?? '-',
                  ),
                  _detailRowPolished('Durum', o.statusLabel),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final hasImages = o.imageUrls.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol durum şeridi
            Container(
              width: 6,
              height: 110,
              decoration: BoxDecoration(
                color: widget.highlight ? Colors.redAccent : Colors.green,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),

            // Orta içerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık ve üst bilgiler
                  Row(
                    children: [
                      Text(
                        'Sipariş #${o.id}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (o.imageUrls.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.image,
                          size: 18,
                          color: Colors.black54,
                        ),
                      ],
                      const SizedBox(width: 8),
                      _StatusChip(status: o.status),
                      const Spacer(),
                      _remainingTimeBadge(o.deliveryDatetime),
                      IconButton(
                        tooltip: 'Detay',
                        onPressed: () => _showDetails(context),
                        icon: const Icon(Icons.info_outline),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // 👤 Müşteri adı – kart üzerinde görünür
                  if (o.customerName != null && o.customerName!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          o.customerName!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  else
                    const Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.black38,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Müşteri adı yok',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 6),

                  // Sipariş adı / detayları - always visible and prominent
                  if (o.details != null && o.details!.isNotEmpty) ...[
                    Text(
                      o.details!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Sipariş adı belirtilmemiş',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  // [Sipariş görsel önizleme (thumbnail) KALDIRILDI]
                  const SizedBox(height: 8),

                  // Alt bilgiler (Teslim tarihi ve kalan tutar)
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        o.deliveryDatetimeFormatted ?? '-',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      if (o.remainingAmount != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Kalan: ${o.remainingAmount} ₺',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Aksiyon
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _markReady,
                      icon:
                          _loading
                              ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.check),
                      label: const Text('Hazırlandı'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Original detail row kept for card use
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Polished detail row for modal: muted label, normal value
  Widget _detailRowPolished(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  const _EmptyState({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Text('$title: Sipariş yok'),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String? status;
  const _StatusChip({this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ready' => Colors.green,
      'preparing' => Colors.orange,
      _ => Colors.grey,
    };

    final text = switch (status) {
      'ready' => 'Hazır',
      'preparing' => 'Hazırlanıyor',
      _ => status ?? '-',
    };

    return Chip(
      label: Text(text),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ImageGallery extends StatefulWidget {
  final List<String> urls;
  const _ImageGallery({required this.urls});

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => index = i),
            itemBuilder: (_, i) {
              final url = widget.urls[i];
              if (url.isEmpty) {
                return const Center(child: Icon(Icons.broken_image, size: 40));
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: DebugNetworkImage(rawUrl: url),
              );
            },
          ),
          if (widget.urls.length > 1)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${index + 1}/${widget.urls.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
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
      resolvedUrl,
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

class _FullscreenImage extends StatelessWidget {
  final String url;
  const _FullscreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: DebugNetworkImage(rawUrl: url),
        ),
      ),
    );
  }
}
