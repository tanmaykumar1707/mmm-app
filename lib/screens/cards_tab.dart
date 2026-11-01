import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/state_provider.dart';
import '../models/card_model.dart';
import '../utils/constants.dart';

class CardsTab extends StatefulWidget {
  const CardsTab({super.key});
  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> {
  late int _year, _month;
  String? _filterPerson;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year; _month = now.month;
  }

  String get _key => monthKey(_year, _month);

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StateProvider>();
    final cards = sp.state.cards;
    final allTxns = cards.map((c) => sp.cardTxns(c.id, _key)).expand((t) => t).toList();
    final cashList = sp.cashTxns(_key);
    final filteredCash = _filterPerson == null ? cashList : cashList.where((t) => t.spentBy == _filterPerson).toList();

    final grandTotal = allTxns.fold(0.0, (s, t) => s + t.amount) +
        cashList.fold(0.0, (s, t) => s + t.amount);
    final thisBill = allTxns.where((t) => !t.nextBill).fold(0.0, (s, t) => s + t.amount);
    final nextBill = allTxns.where((t) => t.nextBill).fold(0.0, (s, t) => s + t.amount);
    final cashTotal = cashList.fold(0.0, (s, t) => s + t.amount);

    return Column(children: [
      // Month nav header
      Container(
        color: kPrimary,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => setState(() { _month--; if (_month < 1) { _month = 12; _year--; } })),
          Text('${kMonths[_month - 1]} $_year',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () => setState(() { _month++; if (_month > 12) { _month = 1; _year++; } })),
        ]),
      ),
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        // Grand summary
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          _GrandTile('All Cards', grandTotal, kTextDark),
          _GrandTile('This Bill', thisBill, kBlue),
          _GrandTile('Next Bill', nextBill, kWarn),
          _GrandTile('Cash', cashTotal, kAccent),
        ]))),
        const SizedBox(height: 8),
        // Person filter
        if (sp.state.people.isNotEmpty) ...[
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterPill('All', _filterPerson == null, () => setState(() => _filterPerson = null)),
              ...sp.state.people.map((p) => _FilterPill(p, _filterPerson == p,
                () => setState(() => _filterPerson = _filterPerson == p ? null : p))),
            ])),
          const SizedBox(height: 12),
        ],
        // Manage cards button
        if (!sp.isReadOnly)
          Align(alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.credit_card, size: 16),
              label: const Text('Manage Cards'),
              onPressed: () => _showManageCards(context, sp),
            )),
        // Cards
        if (cards.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
            Icon(Icons.credit_card_off_outlined, size: 56, color: kTextLight.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text('No cards added yet', style: TextStyle(color: kTextMid)),
            if (!sp.isReadOnly) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Card'),
                onPressed: () => _showManageCards(context, sp),
              ),
            ],
          ]))),
        ...cards.map((card) => _CardSection(card: card, monthKey: _key, filterPerson: _filterPerson, sp: sp)),
        // Cash section
        _CashSection(monthKey: _key, cashTxns: filteredCash, allCash: cashList, sp: sp),
        const SizedBox(height: 80),
      ])),
    ]);
  }

  void _showManageCards(BuildContext context, StateProvider sp) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ManageCardsSheet(sp: sp),
    );
  }
}

Widget _GrandTile(String label, double val, Color color) => Expanded(child: Column(children: [
  Text(label, style: const TextStyle(fontSize: 10, color: kTextLight, fontWeight: FontWeight.w500)),
  const SizedBox(height: 4),
  Text(formatINRFull(val), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
]));

Widget _FilterPill(String label, bool active, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: active ? kPrimary : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: active ? kPrimary : const Color(0xFFE5E7EB)),
    ),
    child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
      color: active ? Colors.white : kTextMid)),
  ),
);

class _CardSection extends StatelessWidget {
  final CreditCard card; final String monthKey;
  final String? filterPerson; final StateProvider sp;
  const _CardSection({required this.card, required this.monthKey,
    required this.filterPerson, required this.sp});

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) { return kPrimary; }
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(card.color);
    final allTxns = sp.cardTxns(card.id, monthKey);
    final txns = filterPerson == null ? allTxns : allTxns.where((t) => t.spentBy == filterPerson).toList();
    final thisBillTxns = txns.where((t) => !t.nextBill).toList();
    final nextBillTxns  = txns.where((t) => t.nextBill).toList();
    final total = allTxns.fold(0.0, (s, t) => s + t.amount);
    final billKey = '${card.id}_$monthKey';
    final generated = sp.state.billGenerated[billKey] ?? false;

    return Card(margin: const EdgeInsets.only(bottom: 12), child: Column(children: [
      // Card header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(card.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text('Bill ${card.billDate} · Due ${card.dueDate}',
              style: const TextStyle(fontSize: 12, color: kTextLight)),
          ])),
          GestureDetector(
            onTap: sp.isReadOnly ? null : () => sp.setBillGenerated(billKey, !generated),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: generated ? kAccent.withOpacity(0.1) : kBg,
                border: Border.all(color: generated ? kAccent : const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(generated ? '✓ Bill Generated' : 'Mark Bill',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: generated ? kAccent : kTextMid)),
            ),
          ),
          const SizedBox(width: 8),
          Text(formatINRFull(total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
      ),
      // Transactions
      if (txns.isEmpty)
        Padding(padding: const EdgeInsets.all(16),
          child: Text('No transactions', style: TextStyle(color: kTextLight.withOpacity(0.7), fontSize: 13)))
      else
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Column(children: [
          if (thisBillTxns.isNotEmpty) ...[
            _BillHeader('This Bill', thisBillTxns.fold(0.0, (s, t) => s + t.amount), kBlue),
            ...thisBillTxns.map((t) => _TxnRow(t: t, card: card, monthKey: monthKey, sp: sp)),
          ],
          if (nextBillTxns.isNotEmpty) ...[
            const SizedBox(height: 8),
            _BillHeader('Next Bill', nextBillTxns.fold(0.0, (s, t) => s + t.amount), kWarn),
            ...nextBillTxns.map((t) => _TxnRow(t: t, card: card, monthKey: monthKey, sp: sp)),
          ],
        ])),
      // Add txn button
      if (!sp.isReadOnly)
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Transaction'),
          onPressed: () => showModalBottomSheet(
            context: context, isScrollControlled: true,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => _AddTxnSheet(card: card, monthKey: monthKey, sp: sp)),
        ),
    ]));
  }

  Widget _BillHeader(String label, double total, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      const Spacer(),
      Text(formatINRFull(total), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

class _TxnRow extends StatelessWidget {
  final CardTxn t; final CreditCard card; final String monthKey; final StateProvider sp;
  const _TxnRow({required this.t, required this.card, required this.monthKey, required this.sp});
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(t.spentFor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
    subtitle: Text('${t.spentBy} · ${t.date}', style: const TextStyle(fontSize: 11, color: kTextLight)),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(formatINRFull(t.amount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      if (!sp.isReadOnly) PopupMenuButton(itemBuilder: (_) => [
        PopupMenuItem(value: 'toggle', child: Text(t.nextBill ? 'Move to This Bill' : 'Move to Next Bill')),
        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: kDanger))),
      ], onSelected: (v) {
        if (v == 'toggle') sp.toggleNextBill(card.id, monthKey, t.id);
        else sp.deleteCardTxn(card.id, monthKey, t.id);
      }),
    ]),
  );
}

class _AddTxnSheet extends StatefulWidget {
  final CreditCard card; final String monthKey; final StateProvider sp;
  const _AddTxnSheet({required this.card, required this.monthKey, required this.sp});
  @override
  State<_AddTxnSheet> createState() => _AddTxnSheetState();
}

class _AddTxnSheetState extends State<_AddTxnSheet> {
  final _forCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  String? _spentBy;
  bool _nextBill = false;

  @override
  void initState() {
    super.initState();
    _spentBy = widget.sp.state.people.isNotEmpty ? widget.sp.state.people.first : null;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Add Transaction — ${widget.card.name}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      TextField(controller: _forCtrl, decoration: const InputDecoration(labelText: 'Spent for')),
      const SizedBox(height: 12),
      TextField(controller: _amtCtrl, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹')),
      const SizedBox(height: 12),
      if (widget.sp.state.people.isNotEmpty)
        DropdownButtonFormField<String>(
          value: _spentBy,
          decoration: const InputDecoration(labelText: 'Spent by'),
          items: widget.sp.state.people.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setState(() => _spentBy = v),
        ),
      const SizedBox(height: 8),
      SwitchListTile(
        title: const Text('Next Bill', style: TextStyle(fontSize: 14)),
        value: _nextBill,
        onChanged: (v) => setState(() => _nextBill = v),
        contentPadding: EdgeInsets.zero,
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(_amtCtrl.text) ?? 0;
            if (_forCtrl.text.isEmpty || amt <= 0) return;
            widget.sp.addCardTxn(widget.card.id, widget.monthKey, CardTxn(
              id: genId(), spentFor: _forCtrl.text.trim(),
              spentBy: _spentBy ?? '', amount: amt,
              date: DateTime.now().toIso8601String().split('T')[0],
              nextBill: _nextBill,
            ));
            Navigator.pop(context);
          },
          child: const Text('Add'),
        )),
      ]),
    ])),
  );
}

class _CashSection extends StatelessWidget {
  final String monthKey;
  final List<CashTxn> cashTxns, allCash;
  final StateProvider sp;
  const _CashSection({required this.monthKey, required this.cashTxns,
    required this.allCash, required this.sp});
  @override
  Widget build(BuildContext context) {
    final total = allCash.fold(0.0, (s, t) => s + t.amount);
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Column(children: [
      ListTile(
        leading: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.account_balance_wallet, color: kAccent, size: 20)),
        title: const Text('Cash / Wallet', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Pluxee, Slice, etc.', style: TextStyle(fontSize: 12, color: kTextLight)),
        trailing: Text(formatINRFull(total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
      if (cashTxns.isNotEmpty) ...[
        const Divider(height: 1),
        ...cashTxns.map((t) => ListTile(dense: true,
          title: Text(t.spentFor, style: const TextStyle(fontSize: 14)),
          subtitle: Text('${t.spentBy} · ${t.source} · ${t.date}', style: const TextStyle(fontSize: 11, color: kTextLight)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(formatINRFull(t.amount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (!sp.isReadOnly) IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: kDanger),
              onPressed: () => sp.deleteCashTxn(monthKey, t.id)),
          ]),
        )),
      ],
      if (!sp.isReadOnly) TextButton.icon(
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Cash Payment'),
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _AddCashSheet(monthKey: monthKey, sp: sp)),
      ),
    ]));
  }
}

class _AddCashSheet extends StatefulWidget {
  final String monthKey; final StateProvider sp;
  const _AddCashSheet({required this.monthKey, required this.sp});
  @override
  State<_AddCashSheet> createState() => _AddCashSheetState();
}

class _AddCashSheetState extends State<_AddCashSheet> {
  final _forCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _srcCtrl = TextEditingController();
  String? _spentBy;

  @override
  void initState() {
    super.initState();
    _spentBy = widget.sp.state.people.isNotEmpty ? widget.sp.state.people.first : null;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Add Cash Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      TextField(controller: _forCtrl, decoration: const InputDecoration(labelText: 'Spent for')),
      const SizedBox(height: 12),
      TextField(controller: _amtCtrl, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹')),
      const SizedBox(height: 12),
      TextField(controller: _srcCtrl, decoration: const InputDecoration(labelText: 'Source (Pluxee, Slice, etc.)')),
      const SizedBox(height: 12),
      if (widget.sp.state.people.isNotEmpty)
        DropdownButtonFormField<String>(
          value: _spentBy,
          decoration: const InputDecoration(labelText: 'Spent by'),
          items: widget.sp.state.people.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setState(() => _spentBy = v),
        ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(_amtCtrl.text) ?? 0;
            if (_forCtrl.text.isEmpty || amt <= 0) return;
            final src = _srcCtrl.text.trim();
            if (src.isNotEmpty) widget.sp.addCashSource(src);
            widget.sp.addCashTxn(widget.monthKey, CashTxn(
              id: genId(), spentFor: _forCtrl.text.trim(),
              spentBy: _spentBy ?? '', source: src,
              date: DateTime.now().toIso8601String().split('T')[0], amount: amt,
            ));
            Navigator.pop(context);
          },
          child: const Text('Add'),
        )),
      ]),
    ])),
  );
}

class _ManageCardsSheet extends StatefulWidget {
  final StateProvider sp;
  const _ManageCardsSheet({required this.sp});
  @override
  State<_ManageCardsSheet> createState() => _ManageCardsSheetState();
}

class _ManageCardsSheetState extends State<_ManageCardsSheet> {
  final _nameCtrl = TextEditingController();
  final _billCtrl = TextEditingController(text: '1');
  final _dueCtrl  = TextEditingController(text: '15');
  String _color = '#2563eb';
  bool _adding = false;

  static const _colorOptions = [
    '#2563eb', '#7c3aed', '#dc2626', '#059669',
    '#d97706', '#0891b2', '#db2777', '#ea580c',
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Manage Cards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (widget.sp.state.cards.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No cards yet. Add one below.', style: TextStyle(color: kTextMid)))
        else
          ...widget.sp.state.cards.map((c) {
            Color cardColor;
            try { cardColor = Color(int.parse(c.color.replaceFirst('#', '0xFF'))); }
            catch (_) { cardColor = kPrimary; }
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 8, height: 40,
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(4))),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('Bill ${c.billDate} · Due ${c.dueDate}'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline, color: kDanger),
                onPressed: () {
                  widget.sp.deleteCard(c.id);
                  setState(() {});
                }),
            );
          }),
        const Divider(),
        if (_adding) ...[
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Card name', isDense: true)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _billCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bill date', isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _dueCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Due date', isDense: true))),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: _colorOptions.map((hex) {
            Color c;
            try { c = Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
            catch (_) { c = kPrimary; }
            return GestureDetector(
              onTap: () => setState(() => _color = hex),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: c, shape: BoxShape.circle,
                  border: Border.all(
                    color: _color == hex ? Colors.black54 : Colors.transparent, width: 2),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => setState(() => _adding = false),
              child: const Text('Cancel'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              onPressed: () {
                if (_nameCtrl.text.trim().isEmpty) return;
                widget.sp.addCard(CreditCard(
                  id: genId(), name: _nameCtrl.text.trim(),
                  color: _color,
                  billDate: int.tryParse(_billCtrl.text) ?? 1,
                  dueDate: int.tryParse(_dueCtrl.text) ?? 15,
                ));
                _nameCtrl.clear();
                setState(() => _adding = false);
              },
              child: const Text('Add Card'),
            )),
          ]),
        ] else
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Card'),
            onPressed: () => setState(() => _adding = true),
          ),
      ])),
  );
}
