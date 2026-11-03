import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/state_provider.dart';
import '../models/lb_entry.dart';
import '../utils/constants.dart';

class LbTab extends StatefulWidget {
  const LbTab({super.key});
  @override
  State<LbTab> createState() => _LbTabState();
}

class _LbTabState extends State<LbTab> {
  String _filter = 'all'; // 'all' | 'pending' | 'settled'

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StateProvider>();
    final all = sp.state.lbEntries;
    final filtered = _filter == 'pending' ? all.where((e) => !e.isSettled).toList()
        : _filter == 'settled' ? all.where((e) => e.isSettled).toList()
        : all;

    final totalLent = all.where((e) => e.type == 'lent' && !e.isSettled)
        .fold(0.0, (s, e) => s + e.remaining);
    final totalBorrowed = all.where((e) => e.type == 'borrowed' && !e.isSettled)
        .fold(0.0, (s, e) => s + e.remaining);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Summary header
      Container(
        color: kPrimary,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Row(children: [
          _LbSumTile('You Lent', totalLent, kAccent),
          const SizedBox(width: 12),
          _LbSumTile('You Borrowed', totalBorrowed, kDanger),
        ]),
      ),
      // Filter bar
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          _FilterChip('All', _filter == 'all', () => setState(() => _filter = 'all')),
          const SizedBox(width: 8),
          _FilterChip('Pending', _filter == 'pending', () => setState(() => _filter = 'pending')),
          const SizedBox(width: 8),
          _FilterChip('Settled', _filter == 'settled', () => setState(() => _filter = 'settled')),
        ])),
      Expanded(child: filtered.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.handshake_outlined, size: 64, color: kTextLight.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('No LB entries', style: TextStyle(color: kTextMid)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _LbCard(entry: filtered[i], sp: sp),
          )),
      if (!sp.isReadOnly)
        Padding(padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_upward, size: 18),
              label: const Text('I Lent'),
              style: ElevatedButton.styleFrom(backgroundColor: kAccent),
              onPressed: () => _showAddLb(context, sp, 'lent'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_downward, size: 18),
              label: const Text('I Borrowed'),
              style: ElevatedButton.styleFrom(backgroundColor: kDanger),
              onPressed: () => _showAddLb(context, sp, 'borrowed'),
            )),
          ])),
    ]);
  }

  void _showAddLb(BuildContext context, StateProvider sp, String type) {
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddLbSheet(type: type, sp: sp));
  }

  Widget _LbSumTile(String label, double val, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      const SizedBox(height: 4),
      Text(formatINRFull(val), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
    ]),
  ));

  Widget _FilterChip(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: active ? kPrimary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? kPrimary : const Color(0xFFE5E7EB)),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
        color: active ? Colors.white : kTextMid)),
    ),
  );
}

class _LbCard extends StatelessWidget {
  final LbEntry entry; final StateProvider sp;
  const _LbCard({required this.entry, required this.sp});

  @override
  Widget build(BuildContext context) {
    final isLent = entry.type == 'lent';
    final color = isLent ? kAccent : kDanger;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(isLent ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.person, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            Text(entry.reason, style: const TextStyle(fontSize: 12, color: kTextMid)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatINRFull(entry.amount),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
            if (entry.repaid > 0)
              Text('Remaining: ${formatINRFull(entry.remaining)}',
                style: const TextStyle(fontSize: 11, color: kTextLight)),
          ]),
        ]),
        if (entry.isSettled) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: const Text('✓ Settled', style: TextStyle(fontSize: 12, color: kAccent, fontWeight: FontWeight.w600))),
        ] else if (entry.repaid > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: entry.repaid / entry.amount,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            )),
        ],
        if (!sp.isReadOnly) ...[
          const SizedBox(height: 10),
          Row(children: [
            TextButton(onPressed: () => _showRepayments(context), child: const Text('Repayments')),
            const Spacer(),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: kDanger),
              child: const Text('Delete'),
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete entry?'),
                  content: Text('Remove "${entry.person}" (${formatINRFull(entry.amount)})? All repayments will also be deleted.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: kDanger))),
                  ],
                ),
              ).then((ok) { if (ok == true) sp.deleteLbEntry(entry.id); }),
            ),
          ]),
        ],
      ]),
    ));
  }

  void _showRepayments(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RepaymentsSheet(entry: entry, sp: sp));
  }
}

class _AddLbSheet extends StatefulWidget {
  final String type; final StateProvider sp;
  const _AddLbSheet({required this.type, required this.sp});
  @override
  State<_AddLbSheet> createState() => _AddLbSheetState();
}

class _AddLbSheetState extends State<_AddLbSheet> {
  final _personCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _amtCtrl    = TextEditingController();
  final _dueCtrl    = TextEditingController();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.type == 'lent' ? 'I Lent Money' : 'I Borrowed Money',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      TextField(controller: _personCtrl, decoration: const InputDecoration(labelText: 'Person name')),
      const SizedBox(height: 12),
      TextField(controller: _reasonCtrl, decoration: const InputDecoration(labelText: 'Reason')),
      const SizedBox(height: 12),
      TextField(controller: _amtCtrl, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹')),
      const SizedBox(height: 12),
      TextField(controller: _dueCtrl, decoration: const InputDecoration(labelText: 'Due date (YYYY-MM-DD, optional)')),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(_amtCtrl.text) ?? 0;
            if (_personCtrl.text.isEmpty || amt <= 0) return;
            widget.sp.addLbEntry(LbEntry(
              id: genId(), type: widget.type,
              person: _personCtrl.text.trim(), reason: _reasonCtrl.text.trim(),
              date: DateTime.now().toIso8601String().split('T')[0],
              amount: amt, dueDate: _dueCtrl.text.trim().isNotEmpty ? _dueCtrl.text.trim() : null,
            ));
            Navigator.pop(context);
          },
          child: const Text('Save'),
        )),
      ]),
    ])),
  );
}

class _RepaymentsSheet extends StatefulWidget {
  final LbEntry entry; final StateProvider sp;
  const _RepaymentsSheet({required this.entry, required this.sp});
  @override
  State<_RepaymentsSheet> createState() => _RepaymentsSheetState();
}

class _RepaymentsSheetState extends State<_RepaymentsSheet> {
  final _amtCtrl  = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: Text('Repayments — ${widget.entry.person}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        Text('Remaining: ${formatINRFull(widget.entry.remaining)}',
          style: const TextStyle(fontSize: 13, color: kTextMid)),
      ]),
      const SizedBox(height: 12),
      if (widget.entry.repayments.isNotEmpty) ...[
        ...widget.entry.repayments.map((r) => ListTile(dense: true,
          title: Text(r.note.isEmpty ? 'Payment' : r.note, style: const TextStyle(fontSize: 14)),
          subtitle: Text(r.date, style: const TextStyle(fontSize: 11, color: kTextLight)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(formatINRFull(r.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
            if (!widget.sp.isReadOnly)
              IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: kDanger),
                onPressed: () { widget.sp.deleteRepayment(widget.entry.id, r.id); setState(() {}); }),
          ]),
        )),
        const Divider(),
      ],
      if (!widget.sp.isReadOnly && !widget.entry.isSettled) ...[
        TextField(controller: _amtCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Repayment amount', prefixText: '₹')),
        const SizedBox(height: 8),
        TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(_amtCtrl.text) ?? 0;
            if (amt <= 0) return;
            widget.sp.addRepayment(widget.entry.id, Repayment(
              id: genId(), note: _noteCtrl.text.trim(),
              date: DateTime.now().toIso8601String().split('T')[0], amount: amt));
            _amtCtrl.clear(); _noteCtrl.clear();
            setState(() {});
          },
          child: const Text('Add Repayment'),
        )),
      ],
    ])),
  );
}
