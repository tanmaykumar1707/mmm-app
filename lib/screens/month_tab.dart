import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/state_provider.dart';
import '../models/expense.dart';
import '../models/card_model.dart';
import '../utils/constants.dart';
import '../widgets/expense_form.dart';

class MonthTab extends StatefulWidget {
  const MonthTab({super.key});
  @override
  State<MonthTab> createState() => _MonthTabState();
}

class _MonthTabState extends State<MonthTab> {
  late int _year, _month;
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
    final expenses = sp.monthExpenses(_key);
    final total  = expenses.fold(0.0, (s, e) => s + e.amount);
    final paid   = expenses.where((e) => e.paid).fold(0.0, (s, e) => s + e.amount);
    final pending = total - paid;

    // Credit card expenses: txns spent by "me" (my display name) and not marked paid
    final myName = sp.myDisplayName ?? '';
    final ccThisBill = <CardTxn>[];
    final ccNextBill = <CardTxn>[];
    for (final card in sp.state.cards) {
      for (final t in sp.cardTxns(card.id, _key)) {
        if (t.paid) continue;
        if (myName.isNotEmpty && t.spentBy != myName) continue;
        if (t.nextBill) ccNextBill.add(t);
        else ccThisBill.add(t);
      }
    }
    final ccThisTotal = ccThisBill.fold(0.0, (s, t) => s + t.amount);
    final ccNextTotal = ccNextBill.fold(0.0, (s, t) => s + t.amount);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Month navigation
      Container(
        color: kPrimary,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () => setState(() { _month--; if (_month < 1) { _month = 12; _year--; } })),
            Text('${kMonths[_month - 1]} $_year',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            Row(children: [
              IconButton(icon: const Icon(Icons.share_rounded, color: Colors.white),
                tooltip: 'Share summary',
                onPressed: () => _shareMonth(context, sp, expenses, total, paid, pending)),
              IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () => setState(() { _month++; if (_month > 12) { _month = 1; _year++; } })),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _SumTile(label: 'Total', value: total, color: Colors.white),
            const SizedBox(width: 8),
            _SumTile(label: 'Paid', value: paid, color: kAccent),
            const SizedBox(width: 8),
            _SumTile(label: 'Pending', value: pending, color: kWarn),
          ]),
          const SizedBox(height: 10),
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? paid / total : 0,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(kAccent),
                minHeight: 6,
              ),
            ),
          ],
        ]),
      ),
      Expanded(
        child: Stack(children: [
          ListView(padding: const EdgeInsets.all(16), children: [
            if (expenses.isEmpty) ...[
              const SizedBox(height: 24),
              Center(child: Column(children: [
                Icon(Icons.inbox_rounded, size: 64, color: kTextLight.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text('No expenses for this month',
                  style: TextStyle(color: kTextMid, fontSize: 15)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Copy Defaults to Start'),
                  onPressed: sp.isReadOnly ? null : () => sp.createMonthFromDefaults(_key),
                ),
              ])),
            ] else ...[
              // Group by paid/unpaid
              _buildSection('Pending', expenses.where((e) => !e.paid).toList(), sp),
              if (expenses.any((e) => e.paid))
                _buildSection('Paid', expenses.where((e) => e.paid).toList(), sp),
            ],
            // Credit Card Expenses section
            if (ccThisBill.isNotEmpty || ccNextBill.isNotEmpty) ...[
              const SizedBox(height: 8),
              _CcSection(
                thisBill: ccThisBill, nextBill: ccNextBill,
                thisTotal: ccThisTotal, nextTotal: ccNextTotal,
              ),
            ],
            const SizedBox(height: 80),
          ]),
          if (!sp.isReadOnly)
            Positioned(
              right: 16, bottom: 16,
              child: FloatingActionButton(
                backgroundColor: kPrimary,
                onPressed: () => showModalBottomSheet(
                  context: context, isScrollControlled: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => ExpenseForm(monthKey: _key)),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
        ]),
      ),
    ]);
  }

  String _buildShareText(List<Expense> expenses, double total, double paid, double pending) {
    final heading = '💰 ${kMonths[_month - 1]} $_year — Expenses';
    final sep = '─' * 30;
    final lines = <String>[heading, sep, ''];

    final pending_ = expenses.where((e) => !e.paid).toList();
    final paid_ = expenses.where((e) => e.paid).toList();

    if (pending_.isNotEmpty) {
      lines.add('📋 PENDING');
      for (final e in pending_) {
        final name = e.name.padRight(20);
        lines.add('  $name ${formatINRFull(e.amount)}');
      }
      lines.add('');
    }
    if (paid_.isNotEmpty) {
      lines.add('✅ PAID');
      for (final e in paid_) {
        final name = e.name.padRight(20);
        lines.add('  $name ${formatINRFull(e.amount)} ✓');
      }
      lines.add('');
    }

    lines.add(sep);
    lines.add('Total    ${formatINRFull(total)}');
    lines.add('Paid     ${formatINRFull(paid)}');
    lines.add('Pending  ${formatINRFull(pending)}');
    return lines.join('\n');
  }

  void _shareMonth(BuildContext context, StateProvider sp, List<Expense> expenses,
      double total, double paid, double pending) {
    final text = _buildShareText(expenses, total, paid, pending);
    showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ShareSheet(text: text));
  }

  Widget _buildSection(String title, List<Expense> items, StateProvider sp) {
    if (items.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: kTextLight, letterSpacing: 0.5))),
      ...items.map((e) => _ExpenseCard(e: e, monthKey: _key, sp: sp)),
      const SizedBox(height: 12),
    ]);
  }
}

class _SumTile extends StatelessWidget {
  final String label; final double value; final Color color;
  const _SumTile({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 4),
      Text(formatINRFull(value), style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
    ]),
  ));
}

class _ExpenseCard extends StatelessWidget {
  final Expense e; final String monthKey; final StateProvider sp;
  const _ExpenseCard({required this.e, required this.monthKey, required this.sp});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: sp.isReadOnly ? null : () => sp.toggleExpensePaid(monthKey, e.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: e.paid ? kAccent : Colors.transparent,
            border: Border.all(color: e.paid ? kAccent : kTextLight, width: 2),
          ),
          child: e.paid ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
        ),
      ),
      title: Text(e.name, style: TextStyle(
        fontWeight: FontWeight.w500, fontSize: 14,
        decoration: e.paid ? TextDecoration.lineThrough : null,
        color: e.paid ? kTextLight : kTextDark,
      )),
      subtitle: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(20)),
          child: Text(e.category, style: const TextStyle(fontSize: 11, color: kTextMid))),
        if (e.dueDate != null) ...[
          const SizedBox(width: 6),
          Text('Due ${e.dueDate}', style: const TextStyle(fontSize: 11, color: kTextLight)),
        ],
      ]),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(formatINRFull(e.amount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        if (!sp.isReadOnly) PopupMenuButton(itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: kDanger))),
        ], onSelected: (v) {
          if (v == 'edit') {
            showModalBottomSheet(context: context, isScrollControlled: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => ExpenseForm(expense: e, monthKey: monthKey));
          } else {
            showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete expense?'),
                content: Text('Remove "${e.name}"? This cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete', style: TextStyle(color: kDanger))),
                ],
              ),
            ).then((ok) { if (ok == true) sp.deleteExpense(monthKey, e.id); });
          }
        }),
      ]),
    ),
  );
}

class _ShareSheet extends StatefulWidget {
  final String text;
  const _ShareSheet({required this.text});
  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _shareKey = GlobalKey();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Share Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
        child: Text(widget.text, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: kTextDark)),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.text));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)));
          },
        )),
        const SizedBox(width: 12),
        Expanded(key: _shareKey, child: ElevatedButton.icon(
          icon: const Icon(Icons.share_rounded, size: 16),
          label: const Text('Share'),
          onPressed: () {
            final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
            final origin = box == null ? null
                : box.localToGlobal(Offset.zero) & box.size;
            Navigator.pop(context);
            Share.share(widget.text, sharePositionOrigin: origin);
          },
        )),
      ]),
    ]),
  );
}

class _CcSection extends StatelessWidget {
  final List<CardTxn> thisBill, nextBill;
  final double thisTotal, nextTotal;
  const _CcSection({required this.thisBill, required this.nextBill,
    required this.thisTotal, required this.nextTotal});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(children: [
        const Icon(Icons.credit_card, size: 14, color: kTextLight),
        const SizedBox(width: 6),
        const Text('Credit Card Expenses', style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: kTextLight, letterSpacing: 0.5)),
        const Spacer(),
        Text(formatINRFull(thisTotal), style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: kBlue)),
      ])),
    if (thisBill.isNotEmpty) ...[
      ...thisBill.map((t) => _CcTxnRow(t: t, label: 'This Bill')),
    ],
    if (nextBill.isNotEmpty) ...[
      const SizedBox(height: 6),
      Padding(padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          const Text('Next Bill', style: TextStyle(fontSize: 11, color: kWarn, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(formatINRFull(nextTotal), style: const TextStyle(fontSize: 11, color: kWarn)),
        ])),
      ...nextBill.map((t) => _CcTxnRow(t: t, label: 'Next')),
    ],
    const SizedBox(height: 8),
    Container(height: 1, color: const Color(0xFFE5E7EB)),
  ]);
}

class _CcTxnRow extends StatelessWidget {
  final CardTxn t; final String label;
  const _CcTxnRow({required this.t, required this.label});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: kBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: const Icon(Icons.credit_card, size: 14, color: kBlue)),
      title: Text(t.spentFor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text('${t.spentBy} · ${t.date}', style: const TextStyle(fontSize: 11, color: kTextLight)),
      trailing: Text(formatINRFull(t.amount),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlue)),
    ),
  );
}
