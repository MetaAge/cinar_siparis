import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_provider.dart';

final adminDashboardProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/admin/dashboard');
  return Map<String, dynamic>.from(res.data);
});
