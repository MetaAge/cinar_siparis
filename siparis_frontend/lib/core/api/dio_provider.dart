import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siparis_frontend/config/app_config.dart';

import '../../features/auth/providers/auth_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final auth = ref.watch(authProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: {
        if (auth.token != null) 'Authorization': 'Bearer ${auth.token}',
        'Accept': 'application/json',
      },
    ),
  );

  return dio;
});
