import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/firebase_sync_service.dart';
import '../../../core/utils/formatters.dart';
import '../../reports/reports_controller.dart';
import '../../settings/settings_controller.dart';
import '../pos_controller.dart';
import '../pos_screen.dart';
import 'pos_cart_items_list.dart';
import 'pos_checkout_summary.dart';
import 'pos_discount_dialog.dart';
import 'pos_receipt_dialog.dart';
import 'pos_customer_dialog.dart';

class PosCheckoutPanel extends ConsumerStatefulWidget {
  final PosCartState cart;
  final AsyncValue<List<Customer>> customersAsync;
  final TextEditingController paidAmountController;

  const PosCheckoutPanel({
    super.key,
    required this.cart,
    required this.customersAsync,
    required this.paidAmountController,
  });

  @override
  ConsumerState<PosCheckoutPanel> createState() => _PosCheckoutPanelState();
}

class _PosCheckoutPanelState extends ConsumerState<PosCheckoutPanel> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paidAmount = ref.watch(posPaidAmountProvider);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'চলতি কার্ট',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: PosCartItemsList(cart: widget.cart),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: widget.customersAsync.maybeWhen(
                    data: (customers) => DropdownButtonFormField<Customer?>(
                      value: (widget.cart.selectedCustomer != null &&
                              customers.any((c) => c.id == widget.cart.selectedCustomer!.id))
                          ? customers.firstWhere((c) => c.id == widget.cart.selectedCustomer!.id)
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'কাস্টমার',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                          tooltip: 'নতুন কাস্টমার যোগ করুন',
                          onPressed: () => showDialog(
                            context: context,
                            builder: (context) => const PosCustomerDialog(),
                          ),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('সাধারণ কাস্টমার')),
                        ...customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
                      ],
                      onChanged: (val) {
                        ref.read(posCartProvider.notifier).setCustomer(val);
                      },
                    ),
                    orElse: () => const Text('কাস্টমার তালিকা লোড হচ্ছে...'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => PosDiscountDialog(cart: widget.cart),
                  ),
                  icon: const Icon(Icons.percent_rounded, size: 18),
                  label: Text(
                    widget.cart.discount > 0
                        ? 'ছাড়: ৳${Formatters.number(widget.cart.discountAmount)}'
                        : 'ডিসকাউন্ট',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Cash', label: Text('ক্যাশ'), icon: Icon(Icons.money)),
                ButtonSegment(value: 'Mobile Banking', label: Text('মোবাইল'), icon: Icon(Icons.phone_iphone)),
                ButtonSegment(value: 'Card', label: Text('কার্ড'), icon: Icon(Icons.credit_card)),
              ],
              selected: {widget.cart.paymentMethod},
              onSelectionChanged: (set) {
                ref.read(posCartProvider.notifier).setPaymentMethod(set.first);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.paidAmountController,
              decoration: const InputDecoration(
                labelText: 'পরিশোধিত টাকা (Paid Amount)',
                border: OutlineInputBorder(),
                prefixText: '৳ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (val) {
                ref.read(posPaidAmountProvider.notifier).state = double.tryParse(val) ?? 0.0;
              },
            ),
            const SizedBox(height: 12),
            PosCheckoutSummary(cart: widget.cart, paidAmount: paidAmount),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: widget.cart.items.isEmpty
                    ? null
                    : () async {
                        try {
                          final cartItems = List<CartItem>.from(widget.cart.items);
                          final customer = widget.cart.selectedCustomer;
                          final paidVal = ref.read(posPaidAmountProvider);
                          final completedSale = await ref.read(posCartProvider.notifier).completeSale();
                          widget.paidAmountController.clear();
                          ref.read(posPaidAmountProvider.notifier).state = 0.0;
                          ref.invalidate(salesHistoryProvider);
                          ref.invalidate(dashboardMetricsProvider);

                          final settings = ref.read(settingsControllerProvider).valueOrNull;
                          if (settings != null) {
                            ref.read(firebaseSyncServiceProvider).syncSaleOnComplete(
                              sale: completedSale,
                              items: cartItems,
                              paidAmount: paidVal,
                              customerName: customer?.name ?? 'সাধারণ কাস্টমার',
                              settings: settings,
                            ).catchError((e) {
                              debugPrint('Background sale sync failed: $e');
                            });
                          }

                          if (mounted) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => PosReceiptDialog(
                                sale: completedSale,
                                cartStateAtCheckout: widget.cart,
                                paidAmount: paidVal,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('বিক্রি সম্পন্ন করতে ত্রুটি: $e')),
                            );
                          }
                        }
                      },
                child: const Text(
                  'বিক্রি সম্পন্ন করুন',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
