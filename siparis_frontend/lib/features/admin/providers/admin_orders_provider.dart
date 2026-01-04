import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_provider.dart';

final adminOrdersProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, type) async {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/admin/orders', queryParameters: {'type': type});
    return Map<String, dynamic>.from(res.data);
  },
);
final activeOrdersProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/admin/orders/active');
  return res.data['orders'] as List;
});

final historyOrdersProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/admin/orders/history');
  return res.data['orders'] as List;
});
