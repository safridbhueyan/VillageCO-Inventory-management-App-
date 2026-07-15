import 'package:flutter/material.dart';

class StockStatusBadge extends StatelessWidget {
  final double currentStock;
  final double minimumStock;

  const StockStatusBadge({
    super.key,
    required this.currentStock,
    required this.minimumStock,
  });

  String _getStockStatus(double current, double min) {
    if (current <= 0) return 'OutOfStock';
    if (current <= min * 0.5) return 'Critical';
    if (current <= min) return 'Low';
    return 'Healthy';
  }

  @override
  Widget build(BuildContext context) {
    final status = _getStockStatus(currentStock, minimumStock);
    Color color;
    String statusText;
    switch (status) {
      case 'Healthy':
        color = Colors.green;
        statusText = 'পর্যাপ্ত স্টক';
        break;
      case 'Low':
        color = Colors.orange;
        statusText = 'কম স্টক';
        break;
      case 'Critical':
        color = Colors.red;
        statusText = 'খুবই কম স্টক';
        break;
      case 'OutOfStock':
        color = Colors.grey;
        statusText = 'স্টক খালি';
        break;
      default:
        color = Colors.blue;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
