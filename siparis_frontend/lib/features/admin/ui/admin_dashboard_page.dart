import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siparis_frontend/features/admin/providers/admin_orders_pagination_provider.dart';
import 'package:siparis_frontend/features/admin/ui/admin_active_orders_page.dart';
import 'package:siparis_frontend/features/admin/ui/admin_order_history_page.dart';
import 'package:siparis_frontend/features/admin/ui/admin_order_list_page.dart';
import 'package:siparis_frontend/features/admin/ui/admin_orders_page.dart';
import 'package:siparis_frontend/features/admin/widgets/alert_cards.dart';
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
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminDashboardProvider),
          ),
          ElevatedButton(
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => const AdminOrdersPage(
                          scope: AdminOrdersScope.active,
                        ),
                  ),
                ),
            child: const Text('Aktif Siparişler'),
          ),
          OutlinedButton(
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => const AdminOrdersPage(
                          scope: AdminOrdersScope.history,
                        ),
                  ),
                ),
            child: const Text('Geçmiş Siparişler'),
          ),
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
              const SizedBox(height: 16),
              AlertCards(
                late: d['alerts']['late_orders'],
                soon: d['alerts']['soon_orders'],
                noDeposit: d['alerts']['no_deposit_orders'],
                onLateTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminOrderListPage(type: 'late'),
                      ),
                    ),
                onSoonTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminOrderListPage(type: 'soon'),
                      ),
                    ),
                onNoDepositTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => const AdminOrderListPage(type: 'no_deposit'),
                      ),
                    ),
              ),

              const SizedBox(height: 16),
              _StatCard(
                title: 'Bugün Ciro',
                value: '${d['today']['revenue']} ₺',
                icon: Icons.payments,
              ),
              _StatCard(
                title: 'Bugün Sipariş',
                value: '${d['today']['order_count']}',
                icon: Icons.receipt_long,
              ),
              _StatCard(
                title: 'Yarın Teslim',
                value: '${d['tomorrow']['order_count']}',
                icon: Icons.calendar_today,
              ),
              _StatCard(
                title: 'Bu Hafta Ciro',
                value: '${d['week']['revenue']} ₺',
                icon: Icons.bar_chart,
              ),
              const SizedBox(height: 16),
              const RevenueRangeCard(),
              const SizedBox(height: 24),

              /// 📊 7 Günlük Ciro Grafiği
              Revenue7DaysChart(
                data: List<Map<String, dynamic>>.from(d['last_7_days_revenue']),
              ),

              const SizedBox(height: 24),

              const Text(
                'Sipariş Durumları',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
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

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
      backgroundColor: color.withOpacity(0.15),
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
    );
  }
}
