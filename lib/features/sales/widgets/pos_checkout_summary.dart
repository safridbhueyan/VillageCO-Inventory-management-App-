import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../pos_controller.dart';

class PosCheckoutSummary extends StatelessWidget {
  final PosCartState cart;
  final double paidAmount;

  const PosCheckoutSummary({
    super.key,
    required this.cart,
    required this.paidAmount,
  });

  Widget _buildCheckoutSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 14,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
              color: color != null && !isBold ? color : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: fontSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        _buildCheckoutSummaryRow('উপ-মোট বিল', Formatters.currency(cart.subtotal)),
        if (cart.discount > 0)
          _buildCheckoutSummaryRow(
            'ডিসকাউন্ট ছাড়',
            '- ${Formatters.currency(cart.discountAmount)}',
            color: Colors.red,
          ),
        const Divider(height: 16),
        _buildCheckoutSummaryRow(
          'মোট পরিশোধযোগ্য বিল',
          Formatters.currency(cart.total),
          isBold: true,
          fontSize: 18,
          color: theme.colorScheme.primary,
        ),
        if (paidAmount > 0) ...[
          const SizedBox(height: 4),
          _buildCheckoutSummaryRow('পরিশোধিত টাকা', Formatters.currency(paidAmount)),
          _buildCheckoutSummaryRow(
            paidAmount >= cart.total ? 'ফেরতযোগ্য টাকা' : 'বাকি বিল',
            Formatters.currency((paidAmount - cart.total).abs()),
            color: paidAmount >= cart.total ? Colors.green : Colors.orange,
            isBold: true,
          ),
        ],
      ],
    );
  }
}
