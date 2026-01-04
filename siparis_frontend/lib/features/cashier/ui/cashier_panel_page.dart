import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:siparis_frontend/features/cashier/ui/cashier_order_history_page.dart';

import '../../auth/providers/auth_provider.dart';
import '../../production/models/order_model.dart';
import '../providers/cashier_provider.dart';
import 'cashier_create_order_page.dart';

/// Ödeme loading state (hangi sipariş ödeme alıyor?)
final payingOrderIdProvider = StateProvider<int?>((ref) => null);

class CashierPanelPage extends ConsumerStatefulWidget {
  const CashierPanelPage({super.key});

  @override
  ConsumerState<CashierPanelPage> createState() => _CashierPanelPageState();
}

class _CashierPanelPageState extends ConsumerState<CashierPanelPage> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  Timer? _polling;

  @override
  void initState() {
    super.initState();
    _polling = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.invalidate(cashierOrdersProvider);
    });
  }

  @override
  void dispose() {
    _polling?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (d != null) setState(() => _fromDate = d);
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _toDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (d != null) setState(() => _toDate = d);
  }

  // Quick date preset helpers
  void _setToday() {
    final now = DateTime.now();
    setState(() {
      _fromDate = DateTime(now.year, now.month, now.day);
      _toDate = DateTime(now.year, now.month, now.day);
    });
  }

  void _setTomorrow() {
    final t = DateTime.now().add(const Duration(days: 1));
    setState(() {
      _fromDate = DateTime(t.year, t.month, t.day);
      _toDate = DateTime(t.year, t.month, t.day);
    });
  }

  void _setThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Monday
    final endOfWeek = startOfWeek.add(const Duration(days: 6)); // Sunday
    setState(() {
      _fromDate = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );
      _toDate = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
    });
  }

  bool _matchDateRange(OrderModel o) {
    if (_fromDate == null && _toDate == null) return true;
    if (o.deliveryDatetime == null) return false;

    final od = o.deliveryDatetime!; // 🔥 ARTIK PARSE YOK

    if (_fromDate != null) {
      final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      if (od.isBefore(from)) return false;
    }

    if (_toDate != null) {
      final to = DateTime(
        _toDate!.year,
        _toDate!.month,
        _toDate!.day,
        23,
        59,
        59,
      );
      if (od.isAfter(to)) return false;
    }

    return true;
  }

  /// Returns a map of [DateTime] (year, month, day) to delivery count.
  Map<DateTime, int> _dailyDeliveryCount(List<OrderModel> orders) {
    final Map<DateTime, int> map = {};
    for (final o in orders) {
      final d = o.deliveryDatetime;
      if (d == null) continue;
      final key = DateTime(d.year, d.month, d.day);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final ordersAsync = ref.watch(cashierOrdersProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    List<OrderModel> _applyFilter(List<OrderModel> orders) {
      final q = _searchCtrl.text.trim().toLowerCase();

      final filtered =
          orders.where((o) {
            final matchQuery =
                q.isEmpty ||
                (o.customerName ?? '').toLowerCase().contains(q) ||
                (o.customerPhone ?? '').toLowerCase().contains(q) ||
                (o.details ?? '').toLowerCase().contains(q) ||
                o.id.toString().contains(q);

            final matchStatus =
                _statusFilter == 'all' || o.status == _statusFilter;
            final matchDate = _matchDateRange(o);
            return matchQuery && matchStatus && matchDate;
          }).toList();

      // 🔥 AUTOMATIC SORT: nearest delivery first
      filtered.sort((a, b) {
        final ad = a.deliveryDatetime;
        final bd = b.deliveryDatetime;

        // Orders without delivery date go to bottom
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;

        return ad.compareTo(bd); // nearest first
      });

      return filtered;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasiyer Paneli'),
        actions: [
          IconButton(
            tooltip: 'Geçmiş Siparişler',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CashierOrderHistoryPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Yeni Sipariş',
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CashierCreateOrderPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(cashierOrdersProvider),
          ),
          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                auth.email ?? '',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (orders) {
          final filtered = _applyFilter(orders);
          final dailyMap = _dailyDeliveryCount(orders);
          final now = DateTime.now();
          final todayKey = DateTime(now.year, now.month, now.day);
          final todayCount = dailyMap[todayKey] ?? 0;

          return Column(
            children: [
              if (todayCount > 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bugün teslim edilecek $todayCount sipariş var',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Sipariş / müşteri / telefon ara',
                          isDense: true,
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _statusFilter,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _statusFilter = v);
                      },
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tümü')),
                        DropdownMenuItem(
                          value: 'preparing',
                          child: Text('Hazırlanıyor'),
                        ),
                        DropdownMenuItem(value: 'ready', child: Text('Hazır')),
                        DropdownMenuItem(value: 'paid', child: Text('Ödendi')),
                      ],
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _fromDate == null
                            ? 'Başlangıç'
                            : '${_fromDate!.day}.${_fromDate!.month}.${_fromDate!.year}',
                      ),
                      onPressed: _pickFromDate,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(
                        _toDate == null
                            ? 'Bitiş'
                            : '${_toDate!.day}.${_toDate!.month}.${_toDate!.year}',
                      ),
                      onPressed: _pickToDate,
                    ),
                    // Quick date preset chips
                    ActionChip(
                      label: const Text('Bugün'),
                      onPressed: _setToday,
                    ),
                    ActionChip(
                      label: const Text('Yarın'),
                      onPressed: _setTomorrow,
                    ),
                    ActionChip(
                      label: const Text('Bu hafta'),
                      onPressed: _setThisWeek,
                    ),
                    if (_fromDate != null || _toDate != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _fromDate = null;
                            _toDate = null;
                          });
                        },
                        child: const Text('Temizle'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child:
                    filtered.isEmpty
                        ? const Center(
                          child: Text(
                            'Sonuç bulunamadı',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final order = filtered[i];
                            return isMobile
                                ? _CashierOrderCardMobile(order: order)
                                : _CashierOrderCardDesktop(order: order);
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

////////////////////////////////////////////////////////////////
/// 🟦 DESKTOP CARD
////////////////////////////////////////////////////////////////

class _CashierOrderCardDesktop extends ConsumerWidget {
  final OrderModel order;
  const _CashierOrderCardDesktop({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payingId = ref.watch(payingOrderIdProvider);
    final isPaying = payingId == order.id;
    final canPay = order.status == 'ready' && (order.remainingAmount ?? 0) > 0;
    final statusColor = _statusColor(order.status ?? '');

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SOL DURUM ŞERİDİ
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
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
                          backgroundColor: statusColor.withOpacity(.15),
                        ),
                        const SizedBox(width: 8),
                        if (order.deliveryDatetime != null)
                          Chip(
                            label: Text(
                              remainingTimeText(order.deliveryDatetime),
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: remainingColor(
                              order.deliveryDatetime,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    Text(
                      order.details ?? '-',
                      style: const TextStyle(color: Colors.black87),
                    ),

                    if (order.customerName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '👤 ${order.customerName}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Divider(),

                    // PARA BİLGİLERİ – CHIP
                    Row(
                      children: [
                        _MoneyChip(
                          label: 'Toplam',
                          value: order.orderTotal,
                          icon: Icons.receipt_long,
                        ),
                        const SizedBox(width: 8),
                        _MoneyChip(
                          label: 'Kapora',
                          value: order.depositAmount,
                          icon: Icons.savings,
                        ),
                        const SizedBox(width: 8),
                        _MoneyChip(
                          label: 'Kalan',
                          value: order.remainingAmount,
                          icon: Icons.payments,
                          highlight: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ALT AKSİYONLAR
                    Row(
                      children: [
                        Text(
                          '⏰ ${order.deliveryDatetimeFormatted}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Detay',
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => _showOrderDetail(context, order),
                        ),
                        ElevatedButton.icon(
                          onPressed:
                              (!canPay || isPaying)
                                  ? null
                                  : () async {
                                    try {
                                      ref
                                          .read(payingOrderIdProvider.notifier)
                                          .state = order.id;

                                      await ref.read(
                                        markPaidProvider(order.id).future,
                                      );

                                      ref.invalidate(cashierOrdersProvider);
                                    } finally {
                                      ref
                                          .read(payingOrderIdProvider.notifier)
                                          .state = null;
                                    }
                                  },
                          icon:
                              isPaying
                                  ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.payments),
                          label: const Text('Ödeme Alındı'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////////
/// 📱 MOBILE CARD
////////////////////////////////////////////////////////////////

class _CashierOrderCardMobile extends ConsumerWidget {
  final OrderModel order;
  const _CashierOrderCardMobile({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payingId = ref.watch(payingOrderIdProvider);
    final isPaying = payingId == order.id;
    final canPay = order.status == 'ready' && (order.remainingAmount ?? 0) > 0;
    final statusColor = _statusColor(order.status ?? '');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _OrderCardContent(
          order: order,
          canPay: canPay,
          isPaying: isPaying,
          compact: true,
          statusColor: statusColor,
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////////
/// ♻️ ORTAK CONTENT
////////////////////////////////////////////////////////////////

class _OrderCardContent extends ConsumerWidget {
  final OrderModel order;
  final bool canPay;
  final bool isPaying;
  final bool compact;
  final Color? statusColor;

  const _OrderCardContent({
    required this.order,
    required this.canPay,
    required this.isPaying,
    this.compact = false,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sipariş #${order.id}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Chip(
              label: Text(order.statusLabel),
              backgroundColor: (statusColor ?? Colors.grey).withOpacity(.15),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(order.details ?? '-', maxLines: 2),
        const SizedBox(height: 8),
        Text(
          '⏰ ${order.deliveryDatetimeFormatted}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        if (order.deliveryDatetime != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(
                remainingTimeText(order.deliveryDatetime),
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: remainingColor(order.deliveryDatetime),
            ),
          ),
        ],
        const Divider(height: 20),
        Row(
          children: [
            _MoneyInfo('Toplam', order.orderTotal),
            _MoneyInfo('Kapora', order.depositAmount),
            _MoneyInfo('Kalan', order.remainingAmount, highlight: true),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showOrderDetail(context, order),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed:
                  (!canPay || isPaying)
                      ? null
                      : () async {
                        try {
                          ref.read(payingOrderIdProvider.notifier).state =
                              order.id;
                          await ref.read(markPaidProvider(order.id).future);
                          ref.invalidate(cashierOrdersProvider);
                        } finally {
                          ref.read(payingOrderIdProvider.notifier).state = null;
                        }
                      },
              child:
                  isPaying
                      ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Ödeme Alındı'),
            ),
          ],
        ),
      ],
    );
  }
}

////////////////////////////////////////////////////////////////
/// 🧾 DETAY MODAL (GÖRSELLİ)
////////////////////////////////////////////////////////////////

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
                if (o.imageUrls != null && o.imageUrls!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder:
                                  (_) => Dialog(
                                    insetPadding: EdgeInsets.zero,
                                    backgroundColor: Colors.black,
                                    child: Stack(
                                      children: [
                                        InteractiveViewer(
                                          minScale: 0.8,
                                          maxScale: 4,
                                          child: Center(
                                            child: DebugNetworkImage(
                                              rawUrl: o.imageUrls![0],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 24,
                                          right: 24,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                            ),
                                            onPressed:
                                                () => Navigator.pop(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 96,
                              height: 96,
                              child: DebugNetworkImage(rawUrl: o.imageUrls![0]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Sipariş görseli\nDokunarak tam ekran görüntüleyin',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                _detail('Durum', o.statusLabel),
                _detail('Müşteri', o.customerName),
                _detail('Telefon', o.customerPhone),
                _detail('Sipariş', o.details),
                const Divider(),
                _detail('Toplam', '${o.orderTotal} ₺'),
                _detail('Kapora', '${o.depositAmount} ₺'),
                _detail('Kalan', '${o.remainingAmount} ₺'),
                const Divider(),
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

////////////////////////////////////////////////////////////////
/// 🔧 HELPERS
////////////////////////////////////////////////////////////////

String remainingTimeText(DateTime? delivery) {
  if (delivery == null) return '';

  final now = DateTime.now();
  final diff = delivery.difference(now);

  if (diff.isNegative) return 'Süresi geçti';

  if (diff.inDays > 0) {
    return '${diff.inDays} gün kaldı';
  }
  if (diff.inHours > 0) {
    return '${diff.inHours} saat kaldı';
  }
  if (diff.inMinutes > 0) {
    return '${diff.inMinutes} dk kaldı';
  }
  return 'Az kaldı';
}

Color remainingColor(DateTime? delivery) {
  if (delivery == null) return Colors.grey.shade200;
  final diff = delivery.difference(DateTime.now());

  if (diff.inHours <= 1) return Colors.red.shade100;
  if (diff.inHours <= 4) return Colors.orange.shade100;
  return Colors.green.shade100;
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

class _MoneyInfo extends StatelessWidget {
  final String label;
  final int? value;
  final bool highlight;

  const _MoneyInfo(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            '${value ?? 0} ₺',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyChip extends StatelessWidget {
  final String label;
  final int? value;
  final IconData icon;
  final bool highlight;

  const _MoneyChip({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? Colors.green.shade700 : Colors.black54;

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        '$label: ${value ?? 0} ₺',
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      backgroundColor: Colors.grey.shade100,
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'ready':
      return Colors.orange;
    case 'paid':
      return Colors.green;
    case 'preparing':
      return Colors.blue;
    default:
      return Colors.grey;
  }
}
