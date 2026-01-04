import 'package:flutter/material.dart';

class AlertCards extends StatelessWidget {
  final int late;
  final int soon;
  final int noDeposit;

  final VoidCallback onLateTap;
  final VoidCallback onSoonTap;
  final VoidCallback onNoDepositTap;

  const AlertCards({
    super.key,
    required this.late,
    required this.soon,
    required this.noDeposit,
    required this.onLateTap,
    required this.onSoonTap,
    required this.onNoDepositTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (late > 0)
          _AlertCard(
            color: Colors.red,
            icon: Icons.warning_amber_rounded,
            title: 'Geciken Siparişler',
            message: '$late adet siparişin teslim süresi geçti',
            onTap: onLateTap,
          ),

        if (soon > 0)
          _AlertCard(
            color: Colors.orange,
            icon: Icons.access_time,
            title: 'Yaklaşan Teslimler',
            message: '$soon sipariş 1 saat içinde teslim edilecek',
            onTap: onSoonTap,
          ),

        if (noDeposit > 0)
          _AlertCard(
            color: Colors.amber.shade800,
            icon: Icons.payments_outlined,
            title: 'Kapora Eksik',
            message: '$noDeposit siparişte kapora alınmadı',
            onTap: onNoDepositTap,
          ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  const _AlertCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: color.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
        subtitle: Text(message),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
