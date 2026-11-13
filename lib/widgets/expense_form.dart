import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../services/state_provider.dart';
import '../utils/constants.dart';

class ExpenseForm extends StatefulWidget {
  final Expense? expense;
  final String monthKey;
  const ExpenseForm({super.key, this.expense, required this.monthKey});
  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _nameCtrl = TextEditingController();
  final _amtCtrl  = TextEditingController();
  String _category = kCategories[0];
  int? _dueDate;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _nameCtrl.text = widget.expense!.name;
      _amtCtrl.text  = formatAmountInput(widget.expense!.amount);
      _category      = widget.expense!.category;
      _dueDate       = widget.expense!.dueDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.read<StateProvider>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.expense == null ? 'Add Expense' : 'Edit Expense',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Expense name')),
          const SizedBox(height: 12),
          TextField(controller: _amtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [kAmountInputFormatter],
            decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: kCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _dueDate?.toString() ?? '',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Due date (day of month, optional)'),
            onChanged: (v) => _dueDate = int.tryParse(v),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () {
                final name = _nameCtrl.text.trim();
                final amount = double.parse((double.tryParse(_amtCtrl.text) ?? 0).toStringAsFixed(2));
                if (name.isEmpty || amount <= 0) return;
                if (widget.expense == null) {
                  sp.addExpense(widget.monthKey, Expense(
                    id: genId(), name: name, category: _category,
                    amount: amount, dueDate: _dueDate));
                } else {
                  sp.updateExpense(widget.monthKey, Expense(
                    id: widget.expense!.id, name: name, category: _category,
                    amount: amount, dueDate: _dueDate, paid: widget.expense!.paid));
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            )),
          ]),
        ]),
      ),
    );
  }
}
