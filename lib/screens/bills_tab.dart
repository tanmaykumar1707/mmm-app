import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/bill_model.dart';
import '../services/bill_provider.dart';
import '../utils/constants.dart';
import 'bill_detail_screen.dart';
import 'bill_add_edit_screen.dart';

class BillsTab extends StatelessWidget {
  const BillsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BillProvider>();
    if (bp.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final overdue = bp.overdue;
    final soon    = bp.dueSoon;
    final later   = bp.later;
    final total   = bp.bills.length;

    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        // ── Header band ──────────────────────────────────────────────────
        Container(
          color: kPrimary,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Recurring Bills',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Outfit')),
                Text('Sorted by next due date',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11)),
              ])),
              if (overdue.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: kDanger, borderRadius: BorderRadius.circular(20)),
                  child: Text('${overdue.length} overdue',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ]),
            const SizedBox(height: 12),
            // Summary row
            Row(children: [
              _SumCell(label: 'Total bills', value: '$total'),
              const SizedBox(width: 1),
              _SumCell(label: 'Overdue', value: '${overdue.length}', valueColor: overdue.isEmpty ? null : kDanger),
              const SizedBox(width: 1),
              _SumCell(label: 'Due soon', value: '${soon.length}', valueColor: soon.isEmpty ? null : kWarn),
            ]),
          ]),
        ),

        // ── List ─────────────────────────────────────────────────────────
        Expanded(
          child: total == 0
              ? _EmptyState(onAdd: () => _openAdd(context))
              : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
                  // Overdue always on top, outside month groups
                  if (overdue.isNotEmpty) ...[
                    _SectionLabel('Overdue · Act Now'),
                    ...overdue.map((b) => _BillCard(bill: b)),
                    const SizedBox(height: 8),
                  ],
                  // Upcoming bills grouped by month
                  ..._buildMonthGroups([...soon, ...later]),
                ]),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        onPressed: () => _openAdd(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _openAdd(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BillAddEditScreen()));
  }

  List<Widget> _buildMonthGroups(List<Bill> bills) {
    if (bills.isEmpty) return [];

    // Group by "YYYY-MM"
    final Map<String, List<Bill>> groups = {};
    for (final b in bills) {
      final d = b.nextDueParsed;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(b);
    }

    const months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final sortedKeys = groups.keys.toList()..sort();

    final widgets = <Widget>[];
    for (final key in sortedKeys) {
      final parts  = key.split('-');
      final year   = parts[0];
      final month  = months[int.parse(parts[1])];
      final group  = groups[key]!..sort((a, b) => a.nextDueParsed.compareTo(b.nextDueParsed));
      widgets.add(_MonthHeader(label: '$month  ·  $year'));
      widgets.addAll(group.map((b) => _BillCard(bill: b)));
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }
}

// ── Summary cell ──────────────────────────────────────────────────────────────

class _SumCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SumCell({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
          color: valueColor ?? Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.65))),
      ]),
    ),
  );
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
        letterSpacing: 0.7, color: kTextLight)),
  );
}

// ── Month header ─────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final String label;
  const _MonthHeader({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Row(children: [
      Container(width: 4, height: 16,
        decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
          letterSpacing: 0.8, color: kTextDark)),
    ]),
  );
}

// ── Bill card ─────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  final Bill bill;
  const _BillCard({required this.bill});

  String get _badgeLabel {
    final d = bill.daysUntilDue;
    if (d < 0)  return '${d.abs()} day${d.abs() == 1 ? '' : 's'} overdue';
    if (d == 0) return 'Due today';
    return '$d day${d == 1 ? '' : 's'} left';
  }

  @override
  Widget build(BuildContext context) {
    final c = bill.statusColor;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(bill: bill)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: c,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
              ),
            ),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Text(bill.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${bill.type.toUpperCase()} · ${bill.cycleLabel.toUpperCase()}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: kTextLight)),
                  Text(bill.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextDark)),
                  Text('Due ${_fmtDate(bill.nextDueParsed)}',
                    style: const TextStyle(fontSize: 11, color: kTextMid)),
                ])),
                const SizedBox(width: 10),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(formatINRFull(bill.amount),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextDark)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(_badgeLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                  ),
                ]),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.receipt_long_rounded, size: 56, color: kTextLight),
      const SizedBox(height: 12),
      const Text('No recurring bills yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextMid)),
      const SizedBox(height: 6),
      const Text('Track rent, electricity, EMIs and more', style: TextStyle(fontSize: 13, color: kTextLight)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add First Bill'),
      ),
    ]),
  );
}
