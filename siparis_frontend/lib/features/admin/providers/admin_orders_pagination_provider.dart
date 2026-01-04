import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/api/dio_provider.dart';

enum AdminOrdersScope { active, history }

class AdminOrdersState {
  final AdminOrdersScope scope;
  final List<Map<String, dynamic>> items;

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  final bool isLoadingInitial;
  final bool isLoadingMore;
  final String? error;

  const AdminOrdersState({
    required this.scope,
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.isLoadingInitial,
    required this.isLoadingMore,
    required this.error,
  });

  bool get canLoadMore => currentPage < lastPage;

  AdminOrdersState copyWith({
    AdminOrdersScope? scope,
    List<Map<String, dynamic>>? items,
    int? currentPage,
    int? lastPage,
    int? perPage,
    int? total,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    String? error,
  }) {
    return AdminOrdersState(
      scope: scope ?? this.scope,
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      perPage: perPage ?? this.perPage,
      total: total ?? this.total,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }

  static AdminOrdersState initial(AdminOrdersScope scope, {int perPage = 20}) {
    return AdminOrdersState(
      scope: scope,
      items: const [],
      currentPage: 0,
      lastPage: 1,
      perPage: perPage,
      total: 0,
      isLoadingInitial: false,
      isLoadingMore: false,
      error: null,
    );
  }
}

final adminOrdersControllerProvider = StateNotifierProvider.family<
  AdminOrdersController,
  AdminOrdersState,
  AdminOrdersScope
>((ref, scope) {
  return AdminOrdersController(ref, scope);
});

class AdminOrdersController extends StateNotifier<AdminOrdersState> {
  final Ref ref;

  AdminOrdersController(this.ref, AdminOrdersScope scope)
    : super(AdminOrdersState.initial(scope));

  String get _endpoint {
    switch (state.scope) {
      case AdminOrdersScope.active:
        return '/admin/orders/active';
      case AdminOrdersScope.history:
        return '/admin/orders/history';
    }
  }

  Future<void> loadFirstPage({int? perPage}) async {
    if (state.isLoadingInitial) return;

    state = state.copyWith(
      isLoadingInitial: true,
      isLoadingMore: false,
      error: null,
      items: const [],
      currentPage: 0,
      lastPage: 1,
      total: 0,
      perPage: perPage ?? state.perPage,
    );

    try {
      await _fetchPage(1, replace: true);
    } catch (e) {
      state = state.copyWith(isLoadingInitial: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingInitial || state.isLoadingMore) return;
    if (!state.canLoadMore) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      await _fetchPage(state.currentPage + 1, replace: false);
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() => loadFirstPage(perPage: state.perPage);

  Future<void> _fetchPage(int page, {required bool replace}) async {
    final dio = ref.read(dioProvider);

    final res = await dio.get(
      _endpoint,
      queryParameters: {'page': page, 'per_page': state.perPage},
    );

    final data = Map<String, dynamic>.from(res.data);
    final itemsRaw = (data['data'] as List).cast<dynamic>();

    final items =
        itemsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final meta = Map<String, dynamic>.from(data['meta'] as Map);

    final currentPage = (meta['current_page'] as num).toInt();
    final lastPage = (meta['last_page'] as num).toInt();
    final perPage = (meta['per_page'] as num).toInt();
    final total = (meta['total'] as num).toInt();

    state = state.copyWith(
      items: replace ? items : [...state.items, ...items],
      currentPage: currentPage,
      lastPage: lastPage,
      perPage: perPage,
      total: total,
      isLoadingInitial: false,
      isLoadingMore: false,
      error: null,
    );
  }
}
