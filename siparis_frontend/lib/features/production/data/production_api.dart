import 'package:dio/dio.dart';
import '../models/order_model.dart';

class ProductionApi {
  final Dio dio;
  ProductionApi(this.dio);

  Future<List<OrderModel>> today() async {
    final res = await dio.get('/production/orders/today');
    if (res.statusCode != 200) {
      throw Exception(_msg(res.data) ?? 'Bugün teslim alınamadı');
    }
    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<OrderModel>> late() async {
    final res = await dio.get('/production/orders/late');
    if (res.statusCode != 200) {
      throw Exception(_msg(res.data) ?? 'Gecikenler alınamadı');
    }
    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<OrderModel>> upcoming() async {
    final res = await dio.get('/production/orders/upcoming');
    if (res.statusCode != 200) {
      throw Exception(_msg(res.data) ?? 'Yaklaşanlar alınamadı');
    }
    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> markReady(int id) async {
    final res = await dio.patch('/orders/$id/ready');
    if (res.statusCode != 200) {
      throw Exception('Hazırlandı işlemi başarısız');
    }
  }

  String? _msg(dynamic data) {
    if (data is Map && data['message'] != null)
      return data['message'].toString();
    return null;
  }
}
