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
    _tab = TabController(length: 4, vsync: this);

    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.invalidate(productionTodayProvider);
      ref.invalidate(productionLateProvider);
      ref.invalidate(productionUpcomingProvider);
      ref.invalidate(productionHistoryProvider);
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
    if (idx == 3) ref.invalidate(productionHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
          tabs: [
            _TabWithCount(label: 'Bugün', provider: productionTodayProvider),
            _TabWithCount(label: 'Geciken', provider: productionLateProvider),
            _TabWithCount(
              label: 'Yaklaşan',
              provider: productionUpcomingProvider,
            ),
            _TabWithCount(label: 'Geçmiş', provider: productionHistoryProvider),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _customerFilterCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Müşteri adına göre filtrele',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
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
                _OrdersTab(
                  kind: _OrdersKind.history,
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

enum _OrdersKind { today, late, upcoming, history }

class _OrdersTab extends ConsumerStatefulWidget {
  final _OrdersKind kind;
  final String customerFilter;
  const _OrdersTab({required this.kind, required this.customerFilter});

  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab> {
  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final async = switch (kind) {
      _OrdersKind.today => ref.watch(productionTodayProvider),
      _OrdersKind.late => ref.watch(productionLateProvider),
      _OrdersKind.upcoming => ref.watch(productionUpcomingProvider),
      _OrdersKind.history => ref.watch(productionHistoryProvider),
    };

    final title = switch (kind) {
      _OrdersKind.today => 'Bugün Teslim',
      _OrdersKind.late => 'Geciken Siparişler',
      _OrdersKind.upcoming => 'Yaklaşan Teslim',
      _OrdersKind.history => 'Geçmiş Siparişler',
    };

    void _maybeNotify(List<OrderModel> orders) {
      final criticalCount = orders.where((o) => _isCritical(o)).length;
      final lateCount =
          orders.where((o) => o.isLate && o.status != 'ready').length;

      if (lateCount > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ScaffoldMessenger.maybeOf(context)?.mounted ?? false) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ $lateCount geciken sipariş var'),
                backgroundColor: Colors.red.shade600,
              ),
            );
          }
        });
      } else if (criticalCount > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ScaffoldMessenger.maybeOf(context)?.mounted ?? false) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⏰ Teslime 3 saatten az kalan $criticalCount sipariş var',
                ),
                backgroundColor: Colors.orange.shade700,
              ),
            );
          }
        });
      }
    }

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (e, _) => _ErrorState(
            title: title,
            message: e.toString(),
            onRetry: () {
              if (kind == _OrdersKind.today) {
                ref.invalidate(productionTodayProvider);
              }
              if (kind == _OrdersKind.late) {
                ref.invalidate(productionLateProvider);
              }
              if (kind == _OrdersKind.upcoming) {
                ref.invalidate(productionUpcomingProvider);
              }
              if (kind == _OrdersKind.history) {
                ref.invalidate(productionHistoryProvider);
              }
            },
          ),
      data: (orders) {
        _maybeNotify(orders);
        final filteredOrders =
            widget.customerFilter.isEmpty
                ? orders
                : orders.where((o) {
                  final name = (o.customerName ?? '').toLowerCase();
                  return name.contains(widget.customerFilter);
                }).toList();

        final readyCount =
            filteredOrders.where((o) => o.status == 'ready').length;
        final lateCount =
            filteredOrders.where((o) => o.isLate && o.status != 'ready').length;
        final preparingCount =
            filteredOrders.where((o) => o.status == 'preparing').length;
        final unpaidSum = filteredOrders.fold<int>(
          0,
          (p, o) => p + (o.remainingAmount ?? 0),
        );
        final criticalOrders =
            filteredOrders.where((o) => _isCritical(o)).toList();
        final lateOrders =
            filteredOrders
                .where((o) => o.isLate && o.status != 'ready')
                .toList();
        final nonLateOrders =
            filteredOrders
                .where((o) => !(o.isLate && o.status != 'ready'))
                .toList();

        // Reorder: late first, then others by delivery time
        final sortedOrders = [...lateOrders, ...nonLateOrders]..sort((a, b) {
          final ad = a.deliveryDatetime;
          final bd = b.deliveryDatetime;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
        });

        Widget densityHeader() {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.bar_chart,
                      size: 18,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Toplam Sipariş: ${filteredOrders.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatChip(
                      label: 'Hazırlanıyor',
                      value: '$preparingCount',
                      icon: Icons.timer,
                      color: Colors.blue.shade50,
                    ),
                    _StatChip(
                      label: 'Hazır',
                      value: '$readyCount',
                      icon: Icons.check_circle,
                      color: Colors.green.shade50,
                    ),
                    _StatChip(
                      label: 'Geciken',
                      value: '$lateCount',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red.shade50,
                    ),
                    _StatChip(
                      label: 'Ödenmemiş',
                      value: '$unpaidSum ₺',
                      icon: Icons.payments,
                      color: Colors.orange.shade50,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _HourlyHeatmap(orders: filteredOrders),
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
            if (criticalOrders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Teslime 3 saatten az kalan ${criticalOrders.length} sipariş var',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (criticalOrders.isNotEmpty) const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: sortedOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final o = sortedOrders[i];
                  return _OrderCard(
                    order: o,
                    highlight: kind == _OrdersKind.late,
                    showReadyButton: kind != _OrdersKind.history,
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
  final bool showReadyButton;

  const _OrderCard({
    required this.order,
    required this.highlight,
    this.showReadyButton = true,
  });

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
      text = diff.inHours >= 1 ? '${diff.inHours} sa' : '${diff.inMinutes} dk';
    } else {
      bg = Colors.blue;
      text = '${diff.inDays} gün';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bg.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: bg, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _markReady() async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Onay'),
                content: const Text('Bu siparişi hazırlandı olarak işaretle?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Vazgeç'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Onayla'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!confirm) return;

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
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sipariş #${o.id} Detayları',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Müşteri Bilgileri
                    _sectionHeader('Müşteri Bilgileri', Icons.person),
                    _detailRowPolished('Müşteri', o.customerName ?? '-'),
                    _detailRowPolished('Telefon', o.customerPhone ?? '-'),
                    const SizedBox(height: 12),

                    // Sipariş Bilgileri
                    _sectionHeader('Sipariş Bilgileri', Icons.list_alt),
                    _detailRowPolished('Sipariş', o.details ?? '-'),
                    const SizedBox(height: 6),
                    _detailRowPolished(
                      'Toplam',
                      '${o.orderTotal?.toString() ?? '-'} ₺',
                    ),
                    _detailRowPolished(
                      'Kapora',
                      '${o.depositAmount?.toString() ?? 0} ₺',
                    ),
                    _detailRowPolished(
                      'Kalan',
                      '${o.remainingAmount?.toString() ?? '-'} ₺',
                    ),
                    _detailRowPolished('Durum', o.statusLabel),
                    _detailRowPolished(
                      'Teslim',
                      o.deliveryDatetimeFormatted ?? '-',
                    ),
                    if (hasImages) ...[
                      const SizedBox(height: 14),
                      _sectionHeader('Görseller', Icons.image),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        padding: const EdgeInsets.all(10),
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
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Kapat'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          elevation: 1,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showDetails(context),
            hoverColor: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sol durum şeridi
                  Container(
                    width: 6,
                    height: 120,
                    decoration: BoxDecoration(
                      color:
                          widget.highlight
                              ? Colors.redAccent
                              : _statusColor(widget.order.status),
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
                        if (o.customerName != null &&
                            o.customerName!.isNotEmpty)
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

                        // Sipariş adı / detayları
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

                        const SizedBox(height: 8),

                        // Alt bilgiler (Teslim tarihi ve kalan tutar)
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: Colors.black54,
                            ),
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

                        if (widget.showReadyButton)
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
          ),
        ),
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

Widget _sectionHeader(String text, IconData icon) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ],
    ),
  );
}

bool _isCritical(OrderModel o) {
  if (o.deliveryDatetime == null) return false;
  if (o.status == 'ready') return false;
  final diff = o.deliveryDatetime!.difference(DateTime.now());
  return diff.inMinutes >= 0 && diff.inHours < 3;
}

class _HourlyHeatmap extends StatelessWidget {
  final List<OrderModel> orders;
  const _HourlyHeatmap({required this.orders});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final buckets = List<int>.filled(12, 0);
    for (final o in orders) {
      final d = o.deliveryDatetime;
      if (d == null) continue;
      final diffHours = d.difference(now).inHours;
      if (diffHours < 0 || diffHours >= buckets.length) continue;
      buckets[diffHours]++;
    }

    final maxVal = buckets.fold<int>(0, (p, e) => e > p ? e : p);
    if (maxVal == 0) {
      return const Text(
        'Önümüzdeki 12 saatte teslim yok',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Önümüzdeki 12 saat dağılımı',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(buckets.length, (i) {
            final val = buckets[i];
            final height = 6 + (val / maxVal) * 24;
            final color =
                val > 0
                    ? Color.lerp(
                      Colors.orange.shade200,
                      Colors.red.shade400,
                      val / maxVal,
                    )!
                    : Colors.grey.shade200;
            return Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: height,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '+${i}h',
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$title: Sipariş yok'),
            const SizedBox(height: 8),
            const Text(
              'Filtreyi temizlemeyi deneyin',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text('$label: $value'),
      backgroundColor: color ?? Colors.grey.shade100,
      visualDensity: VisualDensity.compact,
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

class _TabWithCount extends ConsumerWidget {
  final String label;
  final FutureProvider<List<OrderModel>> provider;
  const _TabWithCount({required this.label, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(provider)
        .maybeWhen(data: (orders) => orders.length, orElse: () => null);
    final text = count == null ? label : '$label • $count';
    return Tab(text: text);
  }
}

Color _statusColor(String? status) {
  switch (status) {
    case 'ready':
      return Colors.green;
    case 'preparing':
      return Colors.orange;
    default:
      return Colors.grey;
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
