import 'package:intl/intl.dart';

class OrderModel {
  final int id;

  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? details;
  final List<String> imageUrls;

  final int? orderTotal;
  final int? depositAmount;
  final int? remainingAmount;

  final DateTime? deliveryDatetime;
  final String? status;

  OrderModel({
    required this.id,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.details,
    required this.imageUrls,
    this.orderTotal,
    this.depositAmount,
    this.remainingAmount,
    this.deliveryDatetime,
    this.status,
  });

  // -------------------------
  // JSON PARSE (SAFE)
  // -------------------------
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final List<String> urls = [];

    final single = json['image_url'];
    if (single is String && single.trim().isNotEmpty) {
      urls.add(single.trim());
    }

    final multi = json['image_urls'];
    if (multi is List) {
      for (final x in multi) {
        if (x is String && x.trim().isNotEmpty) urls.add(x.trim());
      }
    }
    return OrderModel(
      id: json['id'] as int,

      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerAddress: json['customer_address'] as String?,
      details: json['order_details'] as String?,
      imageUrls: urls,

      orderTotal: _toInt(json['order_total']),
      depositAmount: _toInt(json['deposit_amount']),
      remainingAmount: _toInt(json['remaining_amount']),

      deliveryDatetime:
          json['delivery_datetime'] != null
              ? DateTime.parse(json['delivery_datetime'])
              : null,

      status: json['status'] as String?,
    );
  }

  // -------------------------
  // VALUE PARSER (CRITICAL)
  // -------------------------
  static int? _toInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is double) return value.toInt();

    if (value is String) {
      // "1200" / "1200.00"
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      return parsed?.toInt();
    }

    return null;
  }

  // -------------------------
  // UI HELPERS
  // -------------------------
  String get statusLabel {
    switch (status) {
      case 'ready':
        return 'Hazır';
      case 'preparing':
        return 'Hazırlanıyor';
      case "paid":
        return "Ödendi";
      default:
        return status ?? '-';
    }
  }

  String? get deliveryDatetimeFormatted {
    if (deliveryDatetime == null) return null;
    return DateFormat('dd.MM.yyyy HH:mm').format(deliveryDatetime!);
  }

  bool get isLate {
    if (deliveryDatetime == null) return false;
    return deliveryDatetime!.isBefore(DateTime.now()) && status != 'ready';
  }
}
