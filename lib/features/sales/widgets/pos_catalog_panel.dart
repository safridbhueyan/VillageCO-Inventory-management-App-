import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/widgets/product_image_widget.dart';
import '../../../core/utils/formatters.dart';
import '../../products/products_controller.dart';
import '../pos_controller.dart';
import '../pos_screen.dart';

class PosCatalogPanel extends ConsumerWidget {
  final List<ProductWithDetails> products;
  final AsyncValue<List<Category>> categoriesAsync;
  final TextEditingController searchController;
  final Future<void> Function() onRefresh;

  const PosCatalogPanel({
    super.key,
    required this.products,
    required this.categoriesAsync,
    required this.searchController,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final posCategoryId = ref.watch(posCategoryFilterProvider);
    final productSearchQuery = ref.watch(posProductSearchQueryProvider);
    final cart = ref.watch(posCartProvider);

    return Container(
      color: theme.colorScheme.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'নাম বা বারকোড দিয়ে পণ্য খুঁজুন...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: productSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          ref.read(posProductSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : const Icon(Icons.qr_code),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                ref.read(posProductSearchQueryProvider.notifier).state = val;
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
            child: Row(
              children: [
                ActionChip(
                  label: const Text('সব পণ্য'),
                  onPressed: () => ref.read(posCategoryFilterProvider.notifier).state = null,
                  backgroundColor: posCategoryId == null ? theme.colorScheme.primaryContainer : null,
                  labelStyle: TextStyle(color: posCategoryId == null ? theme.colorScheme.primary : null),
                ),
                const SizedBox(width: 8),
                ...categoriesAsync.maybeWhen(
                  data: (categories) => categories.map((cat) {
                    final isSelected = posCategoryId == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        label: Text(cat.name),
                        onPressed: () => ref.read(posCategoryFilterProvider.notifier).state = cat.id,
                        backgroundColor: isSelected ? theme.colorScheme.primaryContainer : null,
                        labelStyle: TextStyle(color: isSelected ? theme.colorScheme.primary : null),
                      ),
                    );
                  }).toList(),
                  orElse: () => [],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: products.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: 300,
                        alignment: Alignment.center,
                        child: const Text('ম্যাচিং কোনো পণ্য পাওয়া যায়নি।'),
                      ),
                    )
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final item = products[index];
                        final p = item.product;
                        final cartItemIndex = cart.items.indexWhere((ci) => ci.product.id == p.id);
                        final double cartQuantity = cartItemIndex >= 0 ? cart.items[cartItemIndex].quantity : 0.0;
                        final isOut = (p.currentStock - cartQuantity) <= 0;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                          ),
                          child: InkWell(
                            onTap: isOut
                                ? null
                                : () {
                                    ref.read(posCartProvider.notifier).addItem(p);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${p.name} কার্টে যোগ হয়েছে'),
                                        duration: const Duration(milliseconds: 600),
                                      ),
                                    );
                                  },
                            borderRadius: BorderRadius.circular(12),
                            child: Opacity(
                              opacity: isOut ? 0.5 : 1.0,
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ProductImageWidget(
                                          imagePath: p.imagePath,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          borderRadius: 8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      p.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(Formatters.currency(p.sellingPrice), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                      isOut ? 'স্টক খালি' : '${Formatters.number(p.currentStock)} ${p.unit} অবশিষ্ট',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isOut ? Colors.red : Colors.grey,
                                        fontWeight: isOut ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
