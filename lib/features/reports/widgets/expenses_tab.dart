import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/formatters.dart';
import '../reports_controller.dart';
import 'add_expense_dialog.dart';

class ExpensesTab extends ConsumerWidget {
  final AsyncValue<List<Expense>> expensesAsync;

  const ExpensesTab({
    super.key,
    required this.expensesAsync,
  });

  String _translateCategory(String category) {
    switch (category) {
      case 'Rent': return 'দোকান ভাড়া';
      case 'Electricity': return 'বিদ্যুৎ বিল';
      case 'Internet': return 'ইন্টারনেট বিল';
      case 'Transport': return 'পরিবহন ভাড়া';
      case 'Salary': return 'কর্মচারী বেতন';
      default: return 'অন্যান্য খরচ';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'দোকানের আনুষঙ্গিক খরচ সমূহ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => const AddExpenseDialog(),
                ),
                icon: const Icon(Icons.add),
                label: const Text('খরচ লিখুন'),
              ),
            ],
          ),
        ),
        Expanded(
          child: expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('খরচ তালিকা লোড ব্যর্থ: $err')),
            data: (expenses) {
              if (expenses.isEmpty) {
                return const Center(child: Text('কোনো খরচের বিবরণ নেই।'));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: expenses.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final ex = expenses[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.money_off, color: Colors.white),
                    ),
                    title: Text(
                      ex.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${_translateCategory(ex.category)} • ${Formatters.date(ex.date)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '- ${Formatters.currency(ex.amount)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            ref.read(expensesControllerProvider.notifier).deleteExpense(ex.id);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
