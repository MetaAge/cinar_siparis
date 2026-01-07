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
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  String _sort = 'date_asc';

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
    _searchCtrl.dispose();
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

    List<Map<String, dynamic>> applyFilters(List<Map<String, dynamic>> items) {
      final q = _searchCtrl.text.trim().toLowerCase();
      final filtered = items.where((o) {
        final name = (o['customer_name'] ?? '').toString().toLowerCase();
        final details = (o['details'] ?? '').toString().toLowerCase();
        final status = (o['status'] ?? '').toString();
        final matchQuery =
            q.isEmpty || name.contains(q) || details.contains(q);
        final matchStatus = _statusFilter == 'all' || status == _statusFilter;
        return matchQuery && matchStatus;
      }).toList();

      filtered.sort((a, b) {
        int cmp;
        final da = DateTime.tryParse((a['delivery_datetime'] ?? '') as String? ?? '');
        final db = DateTime.tryParse((b['delivery_datetime'] ?? '') as String? ?? '');
        cmp = () {
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        }();
        if (_sort == 'date_desc') cmp = -cmp;
        if (_sort == 'total_desc' || _sort == 'total_asc') {
          final ta = (a['order_total'] ?? 0) as num;
          final tb = (b['order_total'] ?? 0) as num;
          cmp = ta.compareTo(tb);
          if (_sort == 'total_desc') cmp = -cmp;
        }
        return cmp;
      });
      return filtered;
    }

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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 240,
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Müşteri / detay ara',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        DropdownButton<String>(
                          value: _statusFilter,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _statusFilter = v);
                          },
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Durum: Tümü')),
                            DropdownMenuItem(value: 'preparing', child: Text('Hazırlanıyor')),
                            DropdownMenuItem(value: 'ready', child: Text('Hazır')),
                            DropdownMenuItem(value: 'paid', child: Text('Ödendi')),
                          ],
                        ),
                        DropdownButton<String>(
                          value: _sort,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _sort = v);
                          },
                          items: const [
                            DropdownMenuItem(value: 'date_asc', child: Text('Tarih ↑')),
                            DropdownMenuItem(value: 'date_desc', child: Text('Tarih ↓')),
                            DropdownMenuItem(value: 'total_asc', child: Text('Tutar ↑')),
                            DropdownMenuItem(value: 'total_desc', child: Text('Tutar ↓')),
                          ],
                        ),
                        if (_searchCtrl.text.isNotEmpty || _statusFilter != 'all')
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _searchCtrl.clear();
                                _statusFilter = 'all';
                                _sort = 'date_asc';
                              });
                            },
                            child: const Text('Temizle'),
                          ),
                      ],
                    ),
                  ),
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
                                itemCount: applyFilters(st.items).length + 1,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final filtered = applyFilters(st.items);
                                  if (i == filtered.length) {
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
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              child: Column(
                                children: const [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(height: 6),
                                  Text('Hepsi yüklendi'),
                                ],
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
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
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
    final total = o['order_total'];

    final hasImage =
        (o['image_url'] != null && (o['image_url'] as String).isNotEmpty);

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {}, // reserved for future detail tap
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
                      Text(
                        details,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(
                          delivery,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    total != null ? '$total ₺' : '—',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (hasImage)
                    Chip(
                      label: const Text('Görsel'),
                      backgroundColor: Colors.blueGrey.shade50,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
