import 'package:flutter/material.dart';

class OrderTile extends StatelessWidget {
  final Map<String, dynamic> o;
  final bool isHistory;

  const OrderTile({super.key, required this.o, this.isHistory = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          isHistory ? Icons.check_circle : Icons.timelapse,
          color: isHistory ? Colors.green : Colors.orange,
        ),
        title: Text(o['customer_name'] ?? '—'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o['details'] ?? ''),
            const SizedBox(height: 4),
            Text(
              'Teslim: ${o['delivery_datetime']}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        trailing: Text('${o['remaining_amount']} ₺'),
      ),
    );
  }
}
