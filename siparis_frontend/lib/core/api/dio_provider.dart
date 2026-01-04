import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final auth = ref.watch(authProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8000/api',
      headers: {
        if (auth.token != null) 'Authorization': 'Bearer ${auth.token}',
        'Accept': 'application/json',
      },
    ),
  );

  return dio;
});
