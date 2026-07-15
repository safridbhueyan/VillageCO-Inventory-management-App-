import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../supply_chain/supply_chain_controller.dart';

class TransferActionPanel extends ConsumerStatefulWidget {
  final SupplyChainOrder order;

  const TransferActionPanel({super.key, required this.order});

  @override
  ConsumerState<TransferActionPanel> createState() => _TransferActionPanelState();
}

class _TransferActionPanelState extends ConsumerState<TransferActionPanel> {
  late final TextEditingController _qtySentController;
  late final TextEditingController _qtyRecController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _qtySentController = TextEditingController(text: widget.order.quantityRequested.toString());
    _qtyRecController = TextEditingController(text: widget.order.quantityRequested.toString());
  }

  @override
  void dispose() {
    _qtySentController.dispose();
    _qtyRecController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Column(
      children: [
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _qtySentController,
                  decoration: InputDecoration(
                    labelText: 'প্রেরিত পরিমাণ',
                    prefixIcon: const Icon(Icons.unarchive_rounded),
                    suffixText: order.productUnit,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'পরিমাণ দিন';
                    final num = double.tryParse(val);
                    if (num == null || num < 0) return 'সঠিক পরিমাণ দিন';
                    return null;
                  },
                  onChanged: (val) {
                    _qtyRecController.text = val;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _qtyRecController,
                  decoration: InputDecoration(
                    labelText: 'গৃহীত পরিমাণ',
                    prefixIcon: const Icon(Icons.archive_rounded),
                    suffixText: order.productUnit,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'পরিমাণ দিন';
                    final num = double.tryParse(val);
                    if (num == null || num < 0) return 'সঠিক পরিমাণ দিন';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('প্রত্যাখ্যান করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _handleReject(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('অনুমোদন করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _handleApprove(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleApprove(BuildContext context) async {
    if (_formKey.currentState?.validate() ?? false) {
      final qtySent = double.parse(_qtySentController.text);
      final qtyRec = double.parse(_qtyRecController.text);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await ref.read(supplyChainServiceProvider).approveRequest(widget.order.id, qtySent, qtyRec);
        if (context.mounted) {
          Navigator.pop(context); // dismiss loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('অনুরোধটি সফলভাবে অনুমোদিত হয়েছে এবং স্টক আপডেট হয়েছে।')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('অনুমোদন ব্যর্থ হয়েছে: $e')));
        }
      }
    }
  }

  void _handleReject(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(supplyChainServiceProvider).rejectRequest(widget.order.id);
      if (context.mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('অনুরোধটি প্রত্যাখ্যান করা হয়েছে।')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('অপারেশন ব্যর্থ হয়েছে: $e')));
      }
    }
  }
}
