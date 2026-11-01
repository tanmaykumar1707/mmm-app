import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/state_provider.dart';
import '../models/expense.dart';
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

    return Column(children: [
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
            IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: () => setState(() { _month++; if (_month > 12) { _month = 1; _year++; } })),
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
                Icon(Icons.inbox_rounded, size: 64, color: kTextLight.withOpacity(0.5)),
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
      color: Colors.white.withOpacity(0.12),
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
            sp.deleteExpense(monthKey, e.id);
          }
        }),
      ]),
    ),
  );
}
