import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/formatters.dart';

class ShopStatsSheet extends StatelessWidget {
  final String shopName;
  final String currency;
  final DocumentReference<Map<String, dynamic>> docRef;

  const ShopStatsSheet({
    super.key,
    required this.shopName,
    required this.currency,
    required this.docRef,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencySymbol = currency == 'BDT'
        ? '৳'
        : (currency == 'USD' ? '\$' : '€');

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: docRef.collection('sales').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final salesDocs = snapshot.data?.docs ?? [];
        double totalSalesVal = 0.0;
        double todaySalesVal = 0.0;
        double monthlySalesVal = 0.0;

        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final monthStart = DateTime(now.year, now.month, 1);

        for (var doc in salesDocs) {
          final data = doc.data();
          final total = (data['total'] as num?)?.toDouble() ?? 0.0;
          totalSalesVal += total;

          DateTime saleDate = DateTime.now();
          if (data['date'] != null) {
            if (data['date'] is Timestamp) {
              saleDate = (data['date'] as Timestamp).toDate();
            } else if (data['date'] is String) {
              saleDate = DateTime.tryParse(data['date']) ?? DateTime.now();
            }
          }

          if (saleDate.isAfter(todayStart)) {
            todaySalesVal += total;
          }
          if (saleDate.isAfter(monthStart)) {
            monthlySalesVal += total;
          }
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$shopName - বেচা-বিক্রি রিপোর্ট',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildReportRow(
                context,
                'আজকের মোট বিক্রি:',
                Formatters.currency(todaySalesVal, symbol: currencySymbol),
              ),
              const SizedBox(height: 12),
              _buildReportRow(
                context,
                'চলতি মাসের বিক্রি:',
                Formatters.currency(monthlySalesVal, symbol: currencySymbol),
              ),
              const SizedBox(height: 12),
              _buildReportRow(
                context,
                'সর্বমোট বিক্রি:',
                Formatters.currency(totalSalesVal, symbol: currencySymbol),
              ),
              const SizedBox(height: 12),
              _buildReportRow(
                context,
                'মোট মেমো সংখ্যা:',
                '${salesDocs.length} টি',
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
