import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_provider.dart';

class RevenueRangeResult {
  final String from;
  final String to;
  final double totalRevenue;
  final int orderCount;

  RevenueRangeResult({
    required this.from,
    required this.to,
    required this.totalRevenue,
    required this.orderCount,
  });

  factory RevenueRangeResult.fromJson(Map<String, dynamic> json) {
    return RevenueRangeResult(
      from: json['from'],
      to: json['to'],
      totalRevenue: (json['total_revenue'] as num).toDouble(),
      orderCount: (json['order_count'] as num).toInt(),
    );
  }
}

final revenueRangeProvider =
    FutureProvider.family<RevenueRangeResult, ({DateTime from, DateTime to})>((
      ref,
      params,
    ) async {
      final dio = ref.read(dioProvider);

      final res = await dio.get(
        '/admin/dashboard/revenue-range',
        queryParameters: {
          'from': params.from.toIso8601String().substring(0, 10),
          'to': params.to.toIso8601String().substring(0, 10),
        },
      );

      return RevenueRangeResult.fromJson(Map<String, dynamic>.from(res.data));
    });
