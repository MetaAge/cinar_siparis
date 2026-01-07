import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siparis_frontend/features/admin/providers/admin_orders_pagination_provider.dart';
import 'package:siparis_frontend/features/admin/ui/admin_orders_page.dart';
import 'package:siparis_frontend/features/admin/widgets/revenue_range_card.dart';
import 'package:siparis_frontend/features/admin/widgets/revenue_widget.dart';
import 'package:siparis_frontend/features/auth/providers/auth_provider.dart';
import '../providers/admin_dashboard_provider.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(adminDashboardProvider),
          ),
          const SizedBox(width: 4),
          _PillButton(
            icon: Icons.list_alt,
            label: 'Aktif Siparişler',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => const AdminOrdersPage(
                      scope: AdminOrdersScope.active,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _PillButton(
            outlined: true,
            icon: Icons.history,
            label: 'Geçmiş Siparişler',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => const AdminOrdersPage(
                      scope: AdminOrdersScope.history,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (d) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              Builder(
                builder: (_) {
                  final last7 =
                      List<Map<String, dynamic>>.from(d['last_7_days_revenue']);
                  final todayRev = last7.isNotEmpty
                      ? (last7.last['revenue'] as num).toDouble()
                      : 0.0;
                  final prevRev =
                      last7.length > 1
                          ? (last7[last7.length - 2]['revenue'] as num).toDouble()
                          : 0.0;
                  final revChange = _calcChange(prevRev, todayRev);

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        title: 'Bugün Ciro',
                        value: '${d['today']['revenue']} ₺',
                        icon: Icons.payments,
                        accent: Colors.green,
                        change: revChange,
                      ),
                      _StatCard(
                        title: 'Bugün Sipariş',
                        value: '${d['today']['order_count']}',
                        icon: Icons.receipt_long,
                        accent: Colors.blue,
                      ),
                      _StatCard(
                        title: 'Yarın Teslim',
                        value: '${d['tomorrow']['order_count']}',
                        icon: Icons.calendar_today,
                        accent: Colors.orange,
                      ),
                      _StatCard(
                        title: 'Bu Hafta Ciro',
                        value: '${d['week']['revenue']} ₺',
                        icon: Icons.bar_chart,
                        accent: Colors.purple,
                      ),
                    ],
                  );
                },
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [],
              ), // spacer hack
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: RevenueRangeCard(),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Revenue7DaysChart(
                    data: List<Map<String, dynamic>>.from(
                      d['last_7_days_revenue'],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sipariş Durumları',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusChip(
                            'Hazırlanıyor',
                            d['status_distribution']['preparing'],
                            Colors.blue,
                          ),
                          _StatusChip(
                            'Hazır',
                            d['status_distribution']['ready'],
                            Colors.orange,
                          ),
                          _StatusChip(
                            'Ödendi',
                            d['status_distribution']['paid'],
                            Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final double? change;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.change,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (change != null) ...[
                    const SizedBox(height: 4),
                    _TrendBadge(change: change!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatusChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      side: outlined ? BorderSide(color: Colors.deepPurple.shade200.withValues(alpha: 0.8)) : null,
      backgroundColor:
          outlined ? Colors.transparent : Colors.deepPurple.withValues(alpha: 0.08),
      foregroundColor: Colors.deepPurple,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
    return OutlinedButton.icon(
      onPressed: onTap,
      style: style,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double change; // e.g. 0.12 = +12%, -0.05 = -5%
  const _TrendBadge({required this.change});

  @override
  Widget build(BuildContext context) {
    final isUp = change >= 0;
    final color = isUp ? Colors.green : Colors.red;
    final icon = isUp ? Icons.trending_up : Icons.trending_down;
    final percent = (change.abs() * 100).toStringAsFixed(1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '${isUp ? '+' : '-'}$percent%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

double? _calcChange(double prev, double current) {
  if (prev == 0 && current == 0) return null;
  if (prev == 0) return 1.0; // infinite growth, show as +100%
  return (current - prev) / prev;
}
