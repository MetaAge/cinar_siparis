import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/dio_provider.dart';
import '../../production/models/order_model.dart';

final cashierOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/cashier/orders');
  return (res.data as List).map((e) => OrderModel.fromJson(e)).toList();
});

final markPaidProvider = FutureProvider.family<void, int>((ref, orderId) async {
  final dio = ref.read(dioProvider);
  await dio.patch('/cashier/orders/$orderId/paid');
});
final payingOrderIdProvider = StateProvider<int?>((ref) => null);

final cashierOrderHistoryProvider = FutureProvider<List<OrderModel>>((
  ref,
) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/cashier/orders/history');
  return (res.data as List).map((e) => OrderModel.fromJson(e)).toList();
});
