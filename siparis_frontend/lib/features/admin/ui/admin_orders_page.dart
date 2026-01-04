import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_orders_pagination_provider.dart';

class AdminOrdersPage extends ConsumerStatefulWidget {
  final AdminOrdersScope scope;
  const AdminOrdersPage({super.key, required this.scope});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();

    // İlk yükleme
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(adminOrdersControllerProvider(widget.scope).notifier)
          .loadFirstPage(perPage: 20);
    });

    _scroll.addListener(() {
      final pos = _scroll.position;
      if (!pos.hasPixels || !pos.hasContentDimensions) return;

      // sona yaklaşınca load more (120px kala)
      if (pos.pixels >= pos.maxScrollExtent - 120) {
        ref
            .read(adminOrdersControllerProvider(widget.scope).notifier)
            .loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get _title =>
      widget.scope == AdminOrdersScope.active
          ? 'Aktif Siparişler'
          : 'Geçmiş Siparişler';

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(adminOrdersControllerProvider(widget.scope));
    final ctrl = ref.read(adminOrdersControllerProvider(widget.scope).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: ctrl.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          st.isLoadingInitial
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Üst bilgi barı (pagination meta)
                  _MetaBar(
                    total: st.total,
                    currentPage: st.currentPage,
                    lastPage: st.lastPage,
                  ),

                  Expanded(
                    child:
                        st.items.isEmpty
                            ? const Center(child: Text('Sipariş yok'))
                            : RefreshIndicator(
                              onRefresh: ctrl.refresh,
                              child: ListView.separated(
                                controller: _scroll,
                                padding: const EdgeInsets.all(16),
                                itemCount: st.items.length + 1, // +1 footer
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  if (i == st.items.length) {
                                    // footer
                                    if (st.isLoadingMore) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    if (st.canLoadMore) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: OutlinedButton.icon(
                                          onPressed: ctrl.loadMore,
                                          icon: const Icon(Icons.expand_more),
                                          label: const Text('Daha Fazla Yükle'),
                                        ),
                                      );
                                    }
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Center(
                                        child: Text('Hepsi yüklendi'),
                                      ),
                                    );
                                  }

                                  final o = st.items[i];
                                  return _OrderCard(o: o);
                                },
                              ),
                            ),
                  ),

                  if (st.error != null)
                    Material(
                      color: Colors.red.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(child: Text(st.error!)),
                            TextButton(
                              onPressed: ctrl.refresh,
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
    );
  }
}

class _MetaBar extends StatelessWidget {
  final int total;
  final int currentPage;
  final int lastPage;

  const _MetaBar({
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  @override
  Widget build(BuildContext context) {
    final text =
        currentPage == 0
            ? 'Toplam: $total'
            : 'Toplam: $total • Sayfa: $currentPage/$lastPage';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black87)),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> o;
  const _OrderCard({required this.o});

  @override
  Widget build(BuildContext context) {
    final customer = (o['customer_name'] ?? '—').toString();
    final details = (o['details'] ?? '').toString();
    final delivery = (o['delivery_datetime'] ?? '—').toString();
    final remaining = o['remaining_amount'];

    final hasImage =
        (o['image_url'] != null && (o['image_url'] as String).isNotEmpty);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 2),
                child: Icon(Icons.image, color: Colors.blueGrey.shade400),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (details.isNotEmpty)
                    Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Text(
                    'Teslim: $delivery',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              remaining != null ? '$remaining ₺' : '—',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
