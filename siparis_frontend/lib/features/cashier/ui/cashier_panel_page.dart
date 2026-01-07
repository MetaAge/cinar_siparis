import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:siparis_frontend/features/cashier/ui/cashier_order_history_page.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/providers/auth_provider.dart';
import '../../production/models/order_model.dart';
import '../providers/cashier_provider.dart';
import 'cashier_create_order_page.dart';

enum AlertType { overdue, dueSoon, today, unpaid }

class AlertCardData {
  final AlertType type;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final int count;
  final List<OrderModel> orders;

  AlertCardData({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.count,
    required this.orders,
  });
}

/// Ödeme loading state (hangi sipariş ödeme alıyor?)
final payingOrderIdProvider = StateProvider<int?>((ref) => null);

class CashierPanelPage extends ConsumerStatefulWidget {
  const CashierPanelPage({super.key});

  @override
  ConsumerState<CashierPanelPage> createState() => _CashierPanelPageState();
}

class _CashierPanelPageState extends ConsumerState<CashierPanelPage> {
  List<AlertCardData> _buildAlerts(List<OrderModel> orders) {
    final now = DateTime.now();

    final overdue =
        orders.where((o) {
          if (o.deliveryDatetime == null) return false;
          return o.deliveryDatetime!.isBefore(now) && o.status != 'paid';
        }).toList();

    final today =
        orders.where((o) {
          if (o.deliveryDatetime == null) return false;
          final d = o.deliveryDatetime!;
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).toList();

    final dueSoon =
        orders.where((o) {
          if (o.deliveryDatetime == null) return false;
          final diff = o.deliveryDatetime!.difference(now);
          return diff.inHours > 0 && diff.inHours <= 4;
        }).toList();

    final unpaid =
        orders.where((o) {
          return (o.remainingAmount ?? 0) > 0 && o.status != 'paid';
        }).toList();

    final List<AlertCardData> alerts = [];

    if (overdue.isNotEmpty) {
      alerts.add(
        AlertCardData(
          type: AlertType.overdue,
          title: 'Süresi Geçen',
          subtitle: 'Teslim zamanı geçmiş siparişler',
          color: Colors.red.shade100,
          icon: Icons.warning_amber,
          count: overdue.length,
          orders: overdue,
        ),
      );
    }

    if (today.isNotEmpty) {
      alerts.add(
        AlertCardData(
          type: AlertType.today,
          title: 'Bugün Teslim',
          subtitle: 'Bugün teslim edilecek siparişler',
          color: Colors.blue.shade100,
          icon: Icons.today,
          count: today.length,
          orders: today,
        ),
      );
    }

    if (dueSoon.isNotEmpty) {
      alerts.add(
        AlertCardData(
          type: AlertType.dueSoon,
          title: 'Yaklaşan',
          subtitle: '4 saat içinde teslim',
          color: Colors.orange.shade100,
          icon: Icons.timer,
          count: dueSoon.length,
          orders: dueSoon,
        ),
      );
    }

    if (unpaid.isNotEmpty) {
      alerts.add(
        AlertCardData(
          type: AlertType.unpaid,
          title: 'Ödeme Bekleyen',
          subtitle: 'Kapora / kalan tutarı olanlar',
          color: Colors.green.shade100,
          icon: Icons.payments,
          count: unpaid.length,
          orders: unpaid,
        ),
      );
    }

    return alerts;
  }

  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _orderIdCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  String _statusFilter = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showAdvancedFilters = false;
  bool _next3HoursOnly = false;
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
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _orderIdCtrl.dispose();
    _detailsCtrl.dispose();
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

  void _setWeekend() {
    final now = DateTime.now();
    final daysToSaturday = (6 - now.weekday) % 7; // Saturday = 6
    final saturday = now.add(Duration(days: daysToSaturday));
    final sunday = saturday.add(const Duration(days: 1));
    setState(() {
      _fromDate = DateTime(saturday.year, saturday.month, saturday.day);
      _toDate = DateTime(sunday.year, sunday.month, sunday.day);
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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width < 900;
    final isDesktop = size.width >= 1200;

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

            final matchAdvanced =
                (_nameCtrl.text.trim().isEmpty ||
                    (o.customerName ?? '')
                        .toLowerCase()
                        .contains(_nameCtrl.text.trim().toLowerCase())) &&
                (_phoneCtrl.text.trim().isEmpty ||
                    (o.customerPhone ?? '')
                        .toLowerCase()
                        .contains(_phoneCtrl.text.trim().toLowerCase())) &&
                (_orderIdCtrl.text.trim().isEmpty ||
                    o.id.toString().contains(_orderIdCtrl.text.trim())) &&
                (_detailsCtrl.text.trim().isEmpty ||
                    (o.details ?? '')
                        .toLowerCase()
                        .contains(_detailsCtrl.text.trim().toLowerCase()));

            final matchStatus =
                _statusFilter == 'all' || o.status == _statusFilter;
            final matchDate = _matchDateRange(o);
            final matchNext3Hours =
                !_next3HoursOnly ||
                (o.deliveryDatetime != null &&
                    o.deliveryDatetime!.isAfter(DateTime.now()) &&
                    o.deliveryDatetime!
                            .difference(DateTime.now())
                            .inHours <=
                        3);

            return matchQuery &&
                matchAdvanced &&
                matchStatus &&
                matchDate &&
                matchNext3Hours;
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
        actions:
            isMobile
                ? [
                  IconButton(
                    tooltip: 'Yenile',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(cashierOrdersProvider),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'history':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CashierOrderHistoryPage(),
                            ),
                          );
                          break;
                        case 'new':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CashierCreateOrderPage(),
                            ),
                          );
                          break;
                        case 'logout':
                          ref.read(authProvider.notifier).logout();
                          break;
                      }
                    },
                    itemBuilder:
                        (_) => [
                          const PopupMenuItem(
                            value: 'history',
                            child: ListTile(
                              leading: Icon(Icons.history),
                              title: Text('Geçmiş Siparişler'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'new',
                            child: ListTile(
                              leading: Icon(Icons.add),
                              title: Text('Yeni Sipariş'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'logout',
                            child: ListTile(
                              leading: Icon(Icons.logout),
                              title: Text('Çıkış'),
                            ),
                          ),
                        ],
                  ),
                ]
                : [
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
          final phoneFrequency = _phoneFrequencyMap(orders);
          final totalOrders = orders.length;
          final preparingCount =
              orders.where((o) => o.status == 'preparing').length;
          final readyCount = orders.where((o) => o.status == 'ready').length;
          final unpaidSum = orders.fold<int>(
            0,
            (prev, o) => prev + (o.remainingAmount ?? 0),
          );
          final overdueCount =
              orders.where(
                (o) =>
                    o.deliveryDatetime != null &&
                    o.deliveryDatetime!.isBefore(DateTime.now()) &&
                    o.status != 'paid',
              ).length;

          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth =
                  constraints.maxWidth > 1320 ? 1280.0 : constraints.maxWidth;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              // Alert Cards v2
              ...(() {
                final alerts = _buildAlerts(orders);
                if (alerts.isNotEmpty) {
                  final cardHeight = isDesktop ? 140.0 : 110.0;
                          final cardWidth = isDesktop ? 200.0 : 160.0;
                          final titleStyle = TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 16 : 15,
                          );
                          final countStyle = TextStyle(
                            fontSize: isDesktop ? 14 : 13,
                          );
                          return [
                            SizedBox(
                              height: cardHeight,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  4,
                                ),
                                scrollDirection: Axis.horizontal,
                                itemCount: alerts.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(width: 12),
                                itemBuilder: (_, i) {
                                  final a = alerts[i];
                                  return GestureDetector(
                                    onTap: () {
                                      final isMobile =
                                          MediaQuery.of(context).size.width <
                                          700;

                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) {
                                          return Center(
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth:
                                                    isMobile
                                                        ? double.infinity
                                                        : 520,
                                                maxHeight:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.height *
                                                    0.9,
                                              ),
                                              child: Container(
                                                margin:
                                                    isMobile
                                                        ? EdgeInsets.zero
                                                        : const EdgeInsets.symmetric(
                                                          vertical: 24,
                                                        ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        isMobile ? 0 : 20,
                                                      ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    // HEADER
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.fromLTRB(
                                                            16,
                                                            12,
                                                            8,
                                                            8,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            a.icon,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              a.title,
                                                              style: const TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.close,
                                                            ),
                                                            onPressed:
                                                                () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                    ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    const Divider(height: 1),

                                                    // LIST
                                                    Expanded(
                                                      child:
                                                          a.orders.isEmpty
                                                              ? const Center(
                                                                child: Text(
                                                                  'Sipariş bulunamadı',
                                                                  style: TextStyle(
                                                                    color:
                                                                        Colors
                                                                            .black54,
                                                                  ),
                                                                ),
                                                              )
                                                              : ListView.separated(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      12,
                                                                    ),
                                                                itemCount:
                                                                    a
                                                                        .orders
                                                                        .length,
                                                                separatorBuilder:
                                                                    (_, __) =>
                                                                        const SizedBox(
                                                                          height:
                                                                              8,
                                                                        ),
                                                                itemBuilder: (
                                                                  _,
                                                                  index,
                                                                ) {
                                                                  final o =
                                                                      a.orders[index];
                                                                  return InkWell(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          12,
                                                                        ),
                                                                    onTap: () {
                                                                      Navigator.pop(
                                                                        context,
                                                                      );
                                                                      _showOrderDetail(
                                                                        context,
                                                                        o,
                                                                      );
                                                                    },
                                                                    child: Container(
                                                                      padding:
                                                                          const EdgeInsets.all(
                                                                            12,
                                                                          ),
                                                                      decoration: BoxDecoration(
                                                                        color:
                                                                            Colors.grey.shade50,
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              12,
                                                                            ),
                                                                        border: Border.all(
                                                                          color:
                                                                              Colors.black12,
                                                                        ),
                                                                      ),
                                                                      child: Row(
                                                                        children: [
                                                                          // LEFT
                                                                          Expanded(
                                                                            child: Column(
                                                                              crossAxisAlignment:
                                                                                  CrossAxisAlignment.start,
                                                                              children: [
                                                                                Text(
                                                                                  o.customerName ??
                                                                                      '—',
                                                                                  style: const TextStyle(
                                                                                    fontWeight:
                                                                                        FontWeight.w600,
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(
                                                                                  height:
                                                                                      4,
                                                                                ),
                                                                                Text(
                                                                                  o.deliveryDatetimeFormatted ??
                                                                                      '-',
                                                                                  style: const TextStyle(
                                                                                    fontSize:
                                                                                        12,
                                                                                    color:
                                                                                        Colors.black54,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                8,
                                                                          ),
                                                                          // RIGHT
                                                                          Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.end,
                                                                            children: [
                                                                              Text(
                                                                                '${o.remainingAmount ?? 0} ₺',
                                                                                style: const TextStyle(
                                                                                  fontWeight:
                                                                                      FontWeight.bold,
                                                                                ),
                                                                              ),
                                                                              const SizedBox(
                                                                                height:
                                                                                    4,
                                                                              ),
                                                                              Chip(
                                                                                label: Text(
                                                                                  o.statusLabel,
                                                                                ),
                                                                                visualDensity:
                                                                                    VisualDensity.compact,
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    child: Container(
                                      width: cardWidth,
                                      padding: EdgeInsets.all(
                                        isDesktop ? 16 : 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: a.color,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.black12,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            a.icon,
                                            size: isDesktop ? 28 : 26,
                                          ),
                                          const Spacer(),
                                          Text(a.title, style: titleStyle),
                                          Text(
                                            '${a.count} sipariş',
                                            style: countStyle,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ];
                        }
                        return [];
                      })(),
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
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatChip(
                      label: 'Toplam',
                      value: '$totalOrders',
                      icon: Icons.list_alt,
                    ),
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
                      value: '$overdueCount',
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final filtersStack =
                                    constraints.maxWidth < 860 ||
                                    isMobile ||
                                    isTablet;
                                final searchWidth =
                                    filtersStack ? constraints.maxWidth : 320.0;

                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  alignment: WrapAlignment.start,
                                  children: [
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: searchWidth,
                                        minWidth:
                                            filtersStack
                                                ? constraints.maxWidth
                                                : 240,
                                      ),
                                      child: TextField(
                                        controller: _searchCtrl,
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          prefixIcon: const Icon(Icons.search),
                                          hintText:
                                              'Sipariş / müşteri / telefon ara',
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
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
                                        DropdownMenuItem(
                                          value: 'all',
                                          child: Text('Tümü'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'preparing',
                                          child: Text('Hazırlanıyor'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'ready',
                                          child: Text('Hazır'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'paid',
                                          child: Text('Ödendi'),
                                        ),
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
                            ActionChip(
                              label: Text(
                                _next3HoursOnly
                                    ? 'Önümüzdeki 3 saat (açık)'
                                    : 'Önümüzdeki 3 saat',
                              ),
                              avatar: const Icon(Icons.schedule, size: 16),
                              onPressed: () => setState(
                                () => _next3HoursOnly = !_next3HoursOnly,
                              ),
                            ),
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
                            ActionChip(
                              label: const Text('Hafta sonu'),
                              onPressed: _setWeekend,
                            ),
                            if (_fromDate != null || _toDate != null)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _fromDate = null;
                                    _toDate = null;
                                    _next3HoursOnly = false;
                                  });
                                },
                                child: const Text('Temizle'),
                              ),
                                    TextButton.icon(
                                      onPressed: () => setState(
                                        () => _showAdvancedFilters =
                                            !_showAdvancedFilters,
                                      ),
                                      icon: Icon(
                                        _showAdvancedFilters
                                            ? Icons.expand_less
                                            : Icons.manage_search,
                                      ),
                                      label: Text(
                                        _showAdvancedFilters
                                            ? 'Gelişmiş filtreleri gizle'
                                            : 'Gelişmiş filtreler',
                                      ),
                                    ),
                                    if (_showAdvancedFilters)
                                      SizedBox(
                                        width: filtersStack
                                            ? constraints.maxWidth
                                            : constraints.maxWidth - 24,
                                        child: Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            _AdvancedField(
                                              controller: _nameCtrl,
                                              label: 'Ad',
                                              icon: Icons.person,
                                              onChanged: () => setState(() {}),
                                            ),
                                            _AdvancedField(
                                              controller: _phoneCtrl,
                                              label: 'Telefon',
                                              icon: Icons.phone,
                                              keyboardType: TextInputType.phone,
                                              onChanged: () => setState(() {}),
                                            ),
                                            _AdvancedField(
                                              controller: _orderIdCtrl,
                                              label: 'Sipariş No',
                                              icon: Icons.tag,
                                              keyboardType: TextInputType.number,
                                              onChanged: () => setState(() {}),
                                            ),
                                            _AdvancedField(
                                              controller: _detailsCtrl,
                                              label: 'Sipariş içeriği',
                                              icon: Icons.list_alt,
                                              onChanged: () => setState(() {}),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                child:
                    filtered.isEmpty
                        ? const Center(
                          child: Text(
                            'Sonuç bulunamadı\nFiltreleri kontrol edin veya temizleyin',
                            style: TextStyle(color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (_, i) {
                                    final order = filtered[i];
                                    final isFrequentCustomer = _isFrequent(
                                      phoneFrequency,
                                      order.customerPhone,
                                    );
                                    return isMobile
                                        ? _CashierOrderCardMobile(
                                          order: order,
                                          isFrequentCustomer:
                                              isFrequentCustomer,
                                        )
                                        : _CashierOrderCardDesktop(
                                          order: order,
                                          isFrequentCustomer:
                                              isFrequentCustomer,
                                        );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
  final bool isFrequentCustomer;
  const _CashierOrderCardDesktop({
    required this.order,
    required this.isFrequentCustomer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payingId = ref.watch(payingOrderIdProvider);
    final isPaying = payingId == order.id;
    final canPay = order.status == 'ready' && (order.remainingAmount ?? 0) > 0;
    final statusColor = _statusColor(order.status ?? '');
    final hasPhone = (order.customerPhone ?? '').trim().isNotEmpty;
    final hasAddress = (order.customerAddress ?? '').trim().isNotEmpty;

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showOrderDetail(context, order),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOL DURUM ŞERİDİ
            Container(
              width: 8,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Sipariş #${order.id}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Chip(
                            label: Text(order.statusLabel),
                            backgroundColor: statusColor.withOpacity(.15),
                          ),
                          const SizedBox(width: 8),
                          if (isFrequentCustomer)
                            Chip(
                              label: const Text('Sık müşteri'),
                              backgroundColor: Colors.amber.shade100,
                            ),
                          const SizedBox(width: 4),
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
                    ),

                    const SizedBox(height: 6),
                    Text(
                      order.details ?? '-',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),

                    if (order.customerName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '👤 ${order.customerName}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    if (hasPhone || hasAddress) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (hasPhone)
                            Chip(
                              label: Text(order.customerPhone!),
                              avatar: const Icon(Icons.phone, size: 16),
                              backgroundColor: Colors.grey.shade100,
                              visualDensity: VisualDensity.compact,
                            ),
                          if (hasAddress)
                            Chip(
                              label: Text(
                                order.customerAddress!,
                                overflow: TextOverflow.ellipsis,
                              ),
                              avatar: const Icon(Icons.place, size: 16),
                              backgroundColor: Colors.grey.shade100,
                              visualDensity: VisualDensity.compact,
                            ),
                          if (hasPhone)
                            _QuickActionIcon(
                              icon: Icons.call,
                              tooltip: 'Ara',
                              onTap: () => _launchDialer(order.customerPhone!),
                            ),
                          if (hasPhone)
                            _QuickActionIcon(
                              icon: Icons.chat,
                              tooltip: 'WhatsApp',
                              onTap:
                                  () => _launchWhatsApp(order.customerPhone!),
                            ),
                          if (hasAddress)
                            _QuickActionIcon(
                              icon: Icons.map_outlined,
                              tooltip: 'Haritada aç',
                              onTap: () => _launchMaps(order.customerAddress!),
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),
                    const SizedBox(height: 12),

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
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed:
                              (!canPay || isPaying)
                                  ? null
                                  : () => _handlePayment(context, ref, order),
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
  final bool isFrequentCustomer;
  const _CashierOrderCardMobile({
    required this.order,
    required this.isFrequentCustomer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payingId = ref.watch(payingOrderIdProvider);
    final isPaying = payingId == order.id;
    final canPay = order.status == 'ready' && (order.remainingAmount ?? 0) > 0;
    final statusColor = _statusColor(order.status ?? '');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showOrderDetail(context, order),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _OrderCardContent(
            order: order,
            canPay: canPay,
            isPaying: isPaying,
            isFrequentCustomer: isFrequentCustomer,
            compact: true,
            statusColor: statusColor,
          ),
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
  final bool isFrequentCustomer;

  const _OrderCardContent({
    required this.order,
    required this.canPay,
    required this.isPaying,
    required this.isFrequentCustomer,
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
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: compact ? 14 : 15,
              ),
            ),
            const Spacer(),
            if (isFrequentCustomer)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip(
                  label: const Text('Sık müşteri'),
                  backgroundColor: Colors.amber.shade100,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            Chip(
              label: Text(order.statusLabel),
              backgroundColor: (statusColor ?? Colors.grey).withOpacity(.15),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          order.details ?? '-',
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          '⏰ ${order.deliveryDatetimeFormatted}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        if ((order.customerPhone ?? '').isNotEmpty ||
            (order.customerAddress ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if ((order.customerPhone ?? '').isNotEmpty)
                Chip(
                  label: Text(order.customerPhone!),
                  avatar: const Icon(Icons.phone, size: 16),
                  backgroundColor: Colors.grey.shade100,
                  visualDensity: VisualDensity.compact,
                ),
              if ((order.customerAddress ?? '').isNotEmpty)
                Chip(
                  label: Text(
                    order.customerAddress!,
                    overflow: TextOverflow.ellipsis,
                  ),
                  avatar: const Icon(Icons.place, size: 16),
                  backgroundColor: Colors.grey.shade100,
                  visualDensity: VisualDensity.compact,
                ),
              if ((order.customerPhone ?? '').isNotEmpty)
                _QuickActionIcon(
                  icon: Icons.call,
                  tooltip: 'Ara',
                  onTap: () => _launchDialer(order.customerPhone!),
                ),
              if ((order.customerPhone ?? '').isNotEmpty)
                _QuickActionIcon(
                  icon: Icons.chat,
                  tooltip: 'WhatsApp',
                  onTap: () => _launchWhatsApp(order.customerPhone!),
                ),
              if ((order.customerAddress ?? '').isNotEmpty)
                _QuickActionIcon(
                  icon: Icons.map_outlined,
                  tooltip: 'Haritada aç',
                  onTap: () => _launchMaps(order.customerAddress!),
                ),
            ],
          ),
        ],
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
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showOrderDetail(context, order),
            ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                    ),
                    onPressed:
                        (!canPay || isPaying)
                            ? null
                            : () => _handlePayment(context, ref, order),
                    icon:
                        isPaying
                      ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.payments),
              label: const Text('Ödeme Alındı'),
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

Future<void> _handlePayment(
  BuildContext context,
  WidgetRef ref,
  OrderModel order,
) async {
  final remaining = order.remainingAmount ?? 0;
  final isOverdue =
      order.deliveryDatetime != null &&
      order.deliveryDatetime!.isBefore(DateTime.now());

  final amountCtrl = TextEditingController(
    text: remaining > 0 ? remaining.toString() : '',
  );
  final noteCtrl = TextEditingController();
  String? error;

  final confirmed =
      await showDialog<bool>(
        context: context,
        builder:
            (ctx) => StatefulBuilder(
              builder: (ctx, setState) {
                return AlertDialog(
                  title: const Text('Ödeme Onayı'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kalan tutar: $remaining ₺'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ödenecek tutar',
                          hintText: 'Kalan tutarı yazın',
                        ),
                      ),
                      if (isOverdue) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: noteCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Gecikme notu (zorunlu)',
                            hintText: 'Neden gecikti / açıklama',
                          ),
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Vazgeç'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final entered =
                            int.tryParse(amountCtrl.text.trim());
                        if (entered != remaining) {
                          setState(
                            () => error =
                                'Lütfen kalan tutarı ($remaining) aynen yazın',
                          );
                          return;
                        }
                        if (isOverdue && noteCtrl.text.trim().isEmpty) {
                          setState(
                            () => error = 'Geciken sipariş için not zorunlu',
                          );
                          return;
                        }
                        setState(() => error = null);
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Onayla'),
                    ),
                  ],
                );
              },
            ),
      ) ??
      false;

  if (!confirmed) return;

  // Not persisted yet; logged for audit until backend supports notes.
  if (noteCtrl.text.trim().isNotEmpty) {
    debugPrint('Payment note (local): ${noteCtrl.text.trim()}');
  }

  try {
    ref.read(payingOrderIdProvider.notifier).state = order.id;
    await ref.read(markPaidProvider(order.id).future);
    ref.invalidate(cashierOrdersProvider);
  } finally {
    ref.read(payingOrderIdProvider.notifier).state = null;
  }
}

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

Map<String, int> _phoneFrequencyMap(List<OrderModel> orders) {
  final Map<String, int> counts = {};
  for (final o in orders) {
    final phone = (o.customerPhone ?? '').trim();
    if (phone.isEmpty) continue;
    counts[phone] = (counts[phone] ?? 0) + 1;
  }
  return counts;
}

bool _isFrequent(Map<String, int> map, String? phone) {
  if (phone == null || phone.trim().isEmpty) return false;
  return (map[phone.trim()] ?? 0) >= 3;
}

class _AdvancedField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final VoidCallback onChanged;

  const _AdvancedField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}

class _QuickActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _QuickActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Tooltip(message: tooltip, child: Icon(icon, size: 18)),
      ),
    );
  }
}

String _digitsOnly(String input) {
  final buffer = StringBuffer();
  for (final ch in input.split('')) {
    if (RegExp(r'\d').hasMatch(ch)) buffer.write(ch);
  }
  return buffer.toString();
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

Future<void> _launchDialer(String phone) async {
  final cleaned = _digitsOnly(phone);
  if (cleaned.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: cleaned);
  await _safeLaunch(uri);
}

Future<void> _launchWhatsApp(String phone) async {
  final cleaned = _digitsOnly(phone);
  if (cleaned.isEmpty) return;
  final uri = Uri.parse('https://wa.me/$cleaned');
  await _safeLaunch(uri);
}

Future<void> _launchMaps(String address) async {
  final encoded = Uri.encodeComponent(address);
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$encoded',
  );
  await _safeLaunch(uri);
}

Future<void> _safeLaunch(Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) debugPrint('Launch failed for $uri');
  } catch (e) {
    debugPrint('Launch error for $uri: $e');
  }
}
