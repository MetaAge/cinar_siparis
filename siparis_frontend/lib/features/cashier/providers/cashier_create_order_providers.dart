import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_provider.dart';

class CreateOrderPayload {
  final String customerName;
  final String customerPhone;
  final String orderDetails;
  final int totalAmount;
  final int depositAmount;
  final String deliveryDatetime; // "YYYY-MM-DD HH:mm:ss"
  final String? imageUrl;

  CreateOrderPayload({
    required this.customerName,
    required this.customerPhone,
    required this.orderDetails,
    required this.totalAmount,
    required this.depositAmount,
    required this.deliveryDatetime,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'order_details': orderDetails,
    'total_amount': totalAmount,
    'deposit_amount': depositAmount,
    'delivery_datetime': deliveryDatetime,
    if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
  };
}

final createCashierOrderProvider =
    FutureProvider.family<void, CreateOrderPayload>((ref, payload) async {
      final dio = ref.read(dioProvider);
      await dio.post('/cashier/orders', data: payload.toJson());
    });

final uploadOrderImageProvider = FutureProvider.family<String, MultipartFile>((
  ref,
  file,
) async {
  final dio = ref.read(dioProvider);
  final form = FormData.fromMap({'image': file});
  final res = await dio.post('/cashier/orders/upload-image', data: form);
  return res.data['image_url'] as String;
});
