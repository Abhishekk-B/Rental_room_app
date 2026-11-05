import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label = status;

    switch (status.toUpperCase()) {
      case 'PAID':
        bg = AppColors.paidChipBg;
        text = AppColors.paidChipText;
        label = 'Paid';
        break;
      case 'PARTIALLY_PAID':
        bg = AppColors.pendingChipBg;
        text = AppColors.pendingChipText;
        label = 'Partial';
        break;
      case 'OVERDUE':
        bg = AppColors.overdueChipBg;
        text = AppColors.overdueChipText;
        label = 'Overdue';
        break;
      case 'UNPAID':
        bg = const Color(0xFFFFEBEE);
        text = const Color(0xFFC62828);
        label = 'Unpaid';
        break;
      case 'OCCUPIED':
      case 'ACTIVE':
        bg = const Color(0xFFE8F5E9);
        text = const Color(0xFF2E7D32);
        label = status == 'ACTIVE' ? 'Active' : 'Occupied';
        break;
      case 'VACANT':
      case 'TERMINATED':
        bg = const Color(0xFFECEFF1);
        text = const Color(0xFF546E7A);
        label = status == 'TERMINATED' ? 'Vacated' : 'Vacant';
        break;
      default:
        bg = Colors.grey.shade200;
        text = Colors.grey.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
