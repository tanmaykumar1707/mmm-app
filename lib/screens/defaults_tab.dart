import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/state_provider.dart';
import '../models/expense.dart';
import '../utils/constants.dart';

class DefaultsTab extends StatelessWidget {
  const DefaultsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StateProvider>();
    final defaults = sp.state.defaults;
    final total = defaults.fold(0.0, (s, e) => s + e.amount);

    return Column(children: [
      Container(color: kPrimary, padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Row(children: [
          const Text('Default Expenses', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(formatINRFull(total), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        ])),
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kBlue.withOpacity(0.08),
            border: Border.all(color: kBlue.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12)),
          child: const Text(
            'These are copied to a new month when you tap "Copy Defaults to Start". '
            'Edit them to match your recurring monthly expenses.',
            style: TextStyle(fontSize: 13, color: kTextMid))),
        const SizedBox(height: 16),
        // People manager
        _PeopleSection(sp: sp),
        const SizedBox(height: 16),
        // Default expenses list
        ...defaults.map((e) => Card(margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(e.category),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(formatINRFull(e.amount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (!sp.isReadOnly) PopupMenuButton(itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: kDanger))),
              ], onSelected: (v) {
                if (v == 'edit') {
                  showModalBottomSheet(context: context, isScrollControlled: true,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => _DefaultForm(expense: e));
                } else {
                  sp.deleteDefault(e.id);
                }
              }),
            ]),
          ))),
        if (!sp.isReadOnly) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Default Expense'),
              onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => const _DefaultForm()),
            )),
          const SizedBox(height: 24),
          // Danger zone
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            const Text('Danger Zone', style: TextStyle(fontWeight: FontWeight.w600, color: kDanger)),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: kDanger, side: const BorderSide(color: kDanger)),
              onPressed: () async {
                final ok = await showDialog<bool>(context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear All Data?'),
                    content: const Text('This will delete all expenses, cards, LB entries and cash records. This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: kDanger),
                        onPressed: () => Navigator.pop(context, true), child: const Text('Delete All')),
                    ],
                  ));
                if (ok == true && context.mounted) context.read<StateProvider>().clearAll();
              },
              child: const Text('Clear All Data'),
            )),
          ]))),
        ],
      ])),
    ]);
  }
}

class _PeopleSection extends StatefulWidget {
  final StateProvider sp;
  const _PeopleSection({required this.sp});
  @override
  State<_PeopleSection> createState() => _PeopleSectionState();
}

class _PeopleSectionState extends State<_PeopleSection> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('People', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      const SizedBox(height: 10),
      ...widget.sp.state.people.map((p) => ListTile(dense: true, contentPadding: EdgeInsets.zero,
        title: Text(p), trailing: widget.sp.isReadOnly ? null :
          IconButton(icon: const Icon(Icons.delete_outline, color: kDanger, size: 18),
            onPressed: () => widget.sp.deletePerson(p)))),
      if (!widget.sp.isReadOnly) Row(children: [
        Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'Add person', isDense: true))),
        IconButton(icon: const Icon(Icons.add_circle, color: kPrimary),
          onPressed: () {
            if (_ctrl.text.trim().isNotEmpty) { widget.sp.addPerson(_ctrl.text.trim()); _ctrl.clear(); }
          }),
      ]),
    ])));
}

class _DefaultForm extends StatefulWidget {
  final Expense? expense;
  const _DefaultForm({this.expense});
  @override
  State<_DefaultForm> createState() => _DefaultFormState();
}

class _DefaultFormState extends State<_DefaultForm> {
  final _nameCtrl = TextEditingController();
  final _amtCtrl  = TextEditingController();
  String _category = kCategories[0];
  int? _dueDate;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _nameCtrl.text = widget.expense!.name;
      _amtCtrl.text  = widget.expense!.amount.toStringAsFixed(0);
      _category      = widget.expense!.category;
      _dueDate       = widget.expense!.dueDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.read<StateProvider>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.expense == null ? 'Add Default' : 'Edit Default',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 12),
        TextField(controller: _amtCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹')),
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
              final amount = double.tryParse(_amtCtrl.text) ?? 0;
              if (name.isEmpty || amount <= 0) return;
              final exp = Expense(id: widget.expense?.id ?? genId(),
                name: name, category: _category, amount: amount, dueDate: _dueDate);
              if (widget.expense == null) sp.addDefault(exp);
              else sp.updateDefault(exp);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          )),
        ]),
      ])),
    );
  }
}
