import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../suppliers_controller.dart';

class UpdateDamageDialog extends ConsumerStatefulWidget {
  final DamagedItem damage;
  final String supplierId;

  const UpdateDamageDialog({super.key, required this.damage, required this.supplierId});

  @override
  ConsumerState<UpdateDamageDialog> createState() => _UpdateDamageDialogState();
}

class _UpdateDamageDialogState extends ConsumerState<UpdateDamageDialog> {
  late String status;
  late final TextEditingController notesController;

  @override
  void initState() {
    super.initState();
    status = widget.damage.status;
    notesController = TextEditingController(text: widget.damage.notes);
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ক্ষতিগ্রস্ত পণ্য মীমাংসা স্ট্যাটাস'),
      content: StatefulBuilder(
        builder: (context, setDlgState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'স্ট্যাটাস বদলুন', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Pending Replacement', child: Text('Pending Replacement (প্রতিস্থাপন অপেক্ষমান)')),
                  DropdownMenuItem(value: 'Replaced', child: Text('Replaced (প্রতিস্থাপিত)')),
                  DropdownMenuItem(value: 'Pending Refund', child: Text('Pending Refund (ফেরত অপেক্ষমান)')),
                  DropdownMenuItem(value: 'Refunded', child: Text('Refunded (ফেরতকৃত)')),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => status = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'মীমাংসা নোট', border: OutlineInputBorder()),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: () {
            final isResolved = status == 'Replaced' || status == 'Refunded';
            
            ref.read(suppliersControllerProvider.notifier).updateDamagedItemStatus(
              id: widget.damage.id,
              supplierId: widget.supplierId,
              status: status,
              resolutionDate: isResolved ? DateTime.now() : null,
              notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
            );
            Navigator.pop(context);
          },
          child: const Text('মীমাংসা করুন'),
        ),
      ],
    );
  }
}
