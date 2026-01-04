import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:siparis_frontend/features/admin/providers/revenue_range_provider.dart';

class RevenueRangeCard extends ConsumerStatefulWidget {
  const RevenueRangeCard({super.key});

  @override
  ConsumerState<RevenueRangeCard> createState() => _RevenueRangeCardState();
}

class _RevenueRangeCardState extends ConsumerState<RevenueRangeCard> {
  DateTimeRange range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      revenueRangeProvider((from: range.start, to: range.end)),
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                const Text(
                  '📊 Tarih Aralığı Ciro',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: const Text('Tarih'),
                  onPressed: () async {
                    final r = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      initialDateRange: range,
                    );
                    if (r != null) {
                      setState(() => range = r);
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            async.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Hata: $e'),
              data: (d) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('dd.MM.yyyy').format(range.start)}'
                      ' → ${DateFormat('dd.MM.yyyy').format(range.end)}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${d.totalRevenue.toStringAsFixed(0)} ₺',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${d.orderCount} adet ödenmiş sipariş'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
