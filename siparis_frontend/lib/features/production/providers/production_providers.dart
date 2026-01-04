import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_provider.dart';
import '../data/production_api.dart';
import '../models/order_model.dart';

final productionApiProvider = Provider<ProductionApi>((ref) {
  return ProductionApi(ref.watch(dioProvider));
});

final productionTodayProvider = FutureProvider.autoDispose<List<OrderModel>>((
  ref,
) async {
  return ref.watch(productionApiProvider).today();
});

final productionLateProvider = FutureProvider.autoDispose<List<OrderModel>>((
  ref,
) async {
  return ref.watch(productionApiProvider).late();
});

final productionUpcomingProvider = FutureProvider.autoDispose<List<OrderModel>>(
  (ref) async {
    return ref.watch(productionApiProvider).upcoming();
  },
);

final markReadyProvider = FutureProvider.family<void, int>((ref, id) async {
  await ref.watch(productionApiProvider).markReady(id);

  // optimistic refresh
  /*ref.invalidate(productionTodayProvider);
  ref.invalidate(productionLateProvider);
  ref.invalidate(productionUpcomingProvider);*/
});
