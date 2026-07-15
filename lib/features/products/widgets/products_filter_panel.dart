import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../products_controller.dart';
import '../../categories/categories_controller.dart';

class ProductsFilterPanel extends ConsumerWidget {
  const ProductsFilterPanel({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Healthy': return Colors.green;
      case 'Low': return Colors.orange;
      case 'Critical': return Colors.red;
      case 'OutOfStock': return Colors.grey;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(productsFilterProvider);
    final categoriesAsync = ref.watch(categoriesControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'নাম বা বারকোড দিয়ে পণ্য খুঁজুন...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) {
                    ref.read(productsFilterProvider.notifier).update((s) => s.copyWith(searchQuery: val));
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  value: filter.sortBy,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('সর্বশেষ যোগ করা')),
                    DropdownMenuItem(value: 'name_asc', child: Text('নাম: ক-অ')),
                    DropdownMenuItem(value: 'name_desc', child: Text('নাম: অ-ক')),
                    DropdownMenuItem(value: 'stock_asc', child: Text('স্টক: কম থেকে বেশি')),
                    DropdownMenuItem(value: 'stock_desc', child: Text('স্টক: বেশি থেকে কম')),
                    DropdownMenuItem(value: 'price_asc', child: Text('মূল্য: কম থেকে বেশি')),
                    DropdownMenuItem(value: 'price_desc', child: Text('মূল্য: বেশি থেকে কম')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(productsFilterProvider.notifier).update((s) => s.copyWith(sortBy: val));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('প্রিয় পণ্য'),
                    ],
                  ),
                  selected: filter.favoritesOnly,
                  onSelected: (val) {
                    ref.read(productsFilterProvider.notifier).update((s) => s.copyWith(favoritesOnly: val));
                  },
                ),
                const SizedBox(width: 8),
                ...categoriesAsync.maybeWhen(
                  data: (categories) => categories.map((cat) {
                    final isSelected = filter.categoryId == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (val) {
                          ref.read(productsFilterProvider.notifier).update(
                                (s) => s.copyWith(categoryId: val ? cat.id : null),
                              );
                        },
                      ),
                    );
                  }).toList(),
                  orElse: () => [],
                ),
                const VerticalDivider(width: 16),
                ...[
                  {'id': 'Healthy', 'label': 'পর্যাপ্ত স্টক'},
                  {'id': 'Low', 'label': 'কম স্টক'},
                  {'id': 'Critical', 'label': 'খুবই কম স্টক'},
                  {'id': 'OutOfStock', 'label': 'স্টক নেই'},
                ].map((status) {
                  final isSelected = filter.stockStatus == status['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(status['label']!),
                      selected: isSelected,
                      selectedColor: _getStatusColor(status['id']!).withOpacity(0.2),
                      onSelected: (val) {
                        ref.read(productsFilterProvider.notifier).update(
                              (s) => s.copyWith(stockStatus: val ? status['id'] : null),
                            );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
