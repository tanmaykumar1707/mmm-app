import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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

    // Exclude paid txns from all totals
    final grandTotal = allTxns.where((t) => !t.paid).fold(0.0, (s, t) => s + t.amount) +
        cashList.where((t) => !t.paid).fold(0.0, (s, t) => s + t.amount);
    final thisBill = allTxns.where((t) => !t.nextBill && !t.paid).fold(0.0, (s, t) => s + t.amount);
    final nextBill = allTxns.where((t) => t.nextBill && !t.paid).fold(0.0, (s, t) => s + t.amount);
    final cashTotal = cashList.where((t) => !t.paid).fold(0.0, (s, t) => s + t.amount);

    // Per-person totals across all cards + cash (exclude paid txns)
    final byPersonThis = <String, double>{};
    final byPersonNext = <String, double>{};
    final byPersonPaid = <String, double>{};
    final byPersonCashPaid = <String, double>{};
    final byPersonCash = <String, double>{};
    for (final card in cards) {
      for (final t in sp.cardTxns(card.id, _key)) {
        if (_filterPerson != null && t.spentBy != _filterPerson) continue;
        final p = t.spentBy.isEmpty ? 'Unknown' : t.spentBy;
        if (t.paid) {
          byPersonPaid[p] = (byPersonPaid[p] ?? 0) + t.amount;
        } else if (t.nextBill) {
          byPersonNext[p] = (byPersonNext[p] ?? 0) + t.amount;
        } else {
          byPersonThis[p] = (byPersonThis[p] ?? 0) + t.amount;
        }
      }
    }
    for (final t in filteredCash) {
      final p = t.spentBy.isEmpty ? 'Unknown' : t.spentBy;
      if (t.paid) {
        byPersonCashPaid[p] = (byPersonCashPaid[p] ?? 0) + t.amount;
      } else {
        byPersonCash[p] = (byPersonCash[p] ?? 0) + t.amount;
      }
    }
    // Merge paid maps
    final mergedPaid = <String, double>{};
    for (final e in [...byPersonPaid.entries, ...byPersonCashPaid.entries]) {
      mergedPaid[e.key] = (mergedPaid[e.key] ?? 0) + e.value;
    }
    final byPersonAll = <String, double>{};
    for (final e in [...byPersonThis.entries, ...byPersonCash.entries]) {
      byPersonAll[e.key] = (byPersonAll[e.key] ?? 0) + e.value;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Month nav header
      Container(
        color: kPrimary,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => setState(() { _month--; if (_month < 1) { _month = 12; _year--; } })),
          Text('${kMonths[_month - 1]} $_year',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          Row(children: [
            IconButton(icon: const Icon(Icons.share_rounded, color: Colors.white),
              tooltip: 'Share summary',
              onPressed: () => _shareCards(context, sp, cards, filteredCash, _filterPerson)),
            IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: () => setState(() { _month++; if (_month > 12) { _month = 1; _year++; } })),
          ]),
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
        // Per-person breakdown
        if (byPersonAll.isNotEmpty || mergedPaid.isNotEmpty) ...[
          _ByPersonBreakdown(
            byPersonThis: byPersonThis,
            byPersonNext: byPersonNext,
            byPersonCash: byPersonCash,
            byPersonAll: byPersonAll,
            byPersonPaid: mergedPaid,
            grandThis: thisBill,
            grandNext: nextBill,
            grandCash: cashTotal,
            grandTotal: grandTotal,
          ),
          const SizedBox(height: 8),
        ],
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
            Icon(Icons.credit_card_off_outlined, size: 56, color: kTextLight.withValues(alpha: 0.5)),
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

  void _shareCards(BuildContext context, StateProvider sp,
      List<CreditCard> cards, List<CashTxn> filteredCash, String? filterPerson) {
    final personLabel = filterPerson != null ? ' — $filterPerson' : '';
    final lines = <String>[];
    lines.add('💳 ${kMonths[_month - 1]} $_year — Cards$personLabel');
    lines.add('─' * 30);
    lines.add('');

    double thisBill = 0, nextBill = 0, cashTotal = 0, grandTotal = 0;

    for (final card in cards) {
      final txns = sp.cardTxns(card.id, _key)
          .where((t) => !t.paid && (filterPerson == null || t.spentBy == filterPerson))
          .toList();
      if (txns.isEmpty) continue;
      final cardTotal = txns.fold(0.0, (s, t) => s + t.amount);
      final thisB = txns.where((t) => !t.nextBill).toList();
      final nextB = txns.where((t) => t.nextBill).toList();
      thisBill += thisB.fold(0.0, (s, t) => s + t.amount);
      nextBill += nextB.fold(0.0, (s, t) => s + t.amount);
      lines.add('${card.name}  ${formatINRFull(cardTotal)}');
      if (thisB.isNotEmpty) {
        lines.add('  This Bill:');
        for (final t in thisB) {
          lines.add('    ${t.spentFor.padRight(18)} ${formatINRFull(t.amount)}  (${t.spentBy})');
        }
      }
      if (nextB.isNotEmpty) {
        lines.add('  Next Bill:');
        for (final t in nextB) {
          lines.add('    ${t.spentFor.padRight(18)} ${formatINRFull(t.amount)}  (${t.spentBy})');
        }
      }
      lines.add('');
    }
    final activeCash = filteredCash.where((t) => !t.paid).toList();
    cashTotal = activeCash.fold(0.0, (s, t) => s + t.amount);
    grandTotal = thisBill + nextBill + cashTotal;
    if (activeCash.isNotEmpty) {
      lines.add('Cash / Wallet  ${formatINRFull(cashTotal)}');
      for (final t in activeCash) {
        lines.add('  ${t.spentFor.padRight(18)} ${formatINRFull(t.amount)}  (${t.spentBy})');
      }
      lines.add('');
    }
    lines.add('─' * 30);
    lines.add('This Bill  ${formatINRFull(thisBill)}');
    lines.add('Next Bill  ${formatINRFull(nextBill)}');
    lines.add('Cash       ${formatINRFull(cashTotal)}');
    lines.add('Total      ${formatINRFull(grandTotal)}');
    final text = lines.join('\n');
    showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CardsShareSheet(text: text));
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
                color: generated ? kAccent.withValues(alpha: 0.1) : kBg,
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
          child: Text('No transactions', style: TextStyle(color: kTextLight.withValues(alpha: 0.7), fontSize: 13)))
      else
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Column(children: [
          if (thisBillTxns.isNotEmpty) ...[
            _BillHeader('This Bill', thisBillTxns.fold(0.0, (s, t) => s + t.amount), kBlue),
            ..._buildPersonGroupRows(thisBillTxns),
          ],
          if (nextBillTxns.isNotEmpty) ...[
            const SizedBox(height: 8),
            _BillHeader('Next Bill', nextBillTxns.fold(0.0, (s, t) => s + t.amount), kWarn),
            ..._buildPersonGroupRows(nextBillTxns),
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

  List<Widget> _buildPersonGroupRows(List<CardTxn> txns) {
    // Separate split groups from regular txns
    final splitGroups = <String, List<CardTxn>>{};
    final regularTxns = <CardTxn>[];
    for (final t in txns) {
      if (t.splitGroupId != null && t.splitGroupId!.isNotEmpty) {
        splitGroups.putIfAbsent(t.splitGroupId!, () => []).add(t);
      } else {
        regularTxns.add(t);
      }
    }

    final widgets = <Widget>[];

    // Split groups shown as collapsible rows
    for (final group in splitGroups.values) {
      widgets.add(_SplitGroupRow(txns: group, card: card, monthKey: monthKey, sp: sp));
    }

    // Regular txns grouped by person
    if (regularTxns.isNotEmpty) {
      final personGroups = <String, List<CardTxn>>{};
      for (final t in regularTxns) {
        final p = t.spentBy.isEmpty ? 'Unknown' : t.spentBy;
        personGroups.putIfAbsent(p, () => []).add(t);
      }
      final sorted = personGroups.entries.toList()
        ..sort((a, b) => b.value.fold(0.0, (s, t) => s + t.amount)
            .compareTo(a.value.fold(0.0, (s, t) => s + t.amount)));
      for (final group in sorted) {
        if (sorted.length > 1 || splitGroups.isNotEmpty) {
          final groupTotal = group.value.fold(0.0, (s, t) => s + t.amount);
          widgets.add(_PersonGroupHeader(group.key, groupTotal));
        }
        widgets.addAll(group.value.map((t) => _TxnRow(t: t, card: card, monthKey: monthKey, sp: sp)));
      }
    }

    return widgets;
  }

  Widget _PersonGroupHeader(String name, double total) => Container(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
    child: Row(children: [
      const Icon(Icons.person_outline, size: 13, color: kTextLight),
      const SizedBox(width: 4),
      Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMid)),
      const Spacer(),
      Text(formatINRFull(total), style: const TextStyle(fontSize: 12, color: kTextMid, fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _BillHeader(String label, double total, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      const Spacer(),
      Text(formatINRFull(total), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

class _SplitGroupRow extends StatefulWidget {
  final List<CardTxn> txns;
  final CreditCard card; final String monthKey; final StateProvider sp;
  const _SplitGroupRow({required this.txns, required this.card,
    required this.monthKey, required this.sp});
  @override
  State<_SplitGroupRow> createState() => _SplitGroupRowState();
}

class _SplitGroupRowState extends State<_SplitGroupRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final txns = widget.txns;
    final total = txns.fold(0.0, (s, t) => s + t.amount);
    final allPaid = txns.every((t) => t.paid);
    final label = txns.first.spentFor;
    final nPeople = txns.length;

    return Opacity(
      opacity: allPaid ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: kPrimary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
        ),
        child: Column(children: [
          // Header row — tap to expand
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                const Icon(Icons.call_split, size: 15, color: kPrimary),
                const SizedBox(width: 6),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500,
                    decoration: allPaid ? TextDecoration.lineThrough : null,
                  )),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Split · $nPeople people',
                      style: const TextStyle(fontSize: 10, color: kPrimary, fontWeight: FontWeight.w600)),
                  ),
                ])),
                Text(formatINRFull(total),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(width: 4),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: kTextLight),
              ]),
            ),
          ),
          // Expanded: per-person rows
          if (_expanded) ...[
            const Divider(height: 1, indent: 12, endIndent: 12),
            ...txns.map((t) => _TxnRow(t: t, card: widget.card,
                monthKey: widget.monthKey, sp: widget.sp, isSubRow: true)),
          ],
        ]),
      ),
    );
  }
}

class _ByPersonBreakdown extends StatelessWidget {
  final Map<String, double> byPersonThis, byPersonNext, byPersonCash, byPersonAll, byPersonPaid;
  final double grandThis, grandNext, grandCash, grandTotal;
  const _ByPersonBreakdown({
    required this.byPersonThis, required this.byPersonNext,
    required this.byPersonCash, required this.byPersonAll,
    required this.byPersonPaid,
    required this.grandThis, required this.grandNext,
    required this.grandCash, required this.grandTotal,
  });

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('By Person', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextMid)),
      const SizedBox(height: 12),
      if (byPersonThis.isNotEmpty) ...[
        _label('This Bill', kBlue),
        ..._rows(byPersonThis, grandThis, kBlue),
        const SizedBox(height: 10),
      ],
      if (byPersonCash.isNotEmpty) ...[
        _label('Cash / Wallet', kAccent),
        ..._rows(byPersonCash, grandCash, kAccent),
        const SizedBox(height: 10),
      ],
      if (byPersonAll.isNotEmpty) ...[
        _label('Total (All)', kTextDark),
        ..._rows(byPersonAll, grandTotal, kTextDark),
        const SizedBox(height: 10),
      ],
      if (byPersonNext.isNotEmpty) ...[
        _label('Next Bill', kWarn),
        ..._rows(byPersonNext, grandNext, kWarn),
        const SizedBox(height: 10),
      ],
      if (byPersonPaid.isNotEmpty) ...[
        _label('Paid by Person', kAccent),
        ..._rows(byPersonPaid, byPersonPaid.values.fold(0.0, (s, v) => s + v), kAccent),
      ],
    ])));

  Widget _label(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
      color: color, letterSpacing: 0.3)));

  List<Widget> _rows(Map<String, double> map, double total, Color color) {
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) {
      final pct = total > 0 ? (e.value / total).clamp(0.0, 1.0) : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 80, child: Text(e.key,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.6)),
              minHeight: 6,
            ))),
          const SizedBox(width: 8),
          Text(formatINRFull(e.value),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          SizedBox(width: 36, child: Text('${(pct * 100).round()}%',
            style: const TextStyle(fontSize: 11, color: kTextLight),
            textAlign: TextAlign.right)),
        ]),
      );
    }).toList();
  }
}

class _TxnRow extends StatelessWidget {
  final CardTxn t; final CreditCard card; final String monthKey;
  final StateProvider sp; final bool isSubRow;
  const _TxnRow({required this.t, required this.card, required this.monthKey,
    required this.sp, this.isSubRow = false});
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: t.paid ? 0.5 : 1.0,
    child: ListTile(
      dense: true,
      contentPadding: isSubRow
          ? const EdgeInsets.only(left: 16, right: 0)
          : EdgeInsets.zero,
      title: Row(children: [
        if (isSubRow) ...[
          const Icon(Icons.person_outline, size: 13, color: kTextLight),
          const SizedBox(width: 4),
          Text(t.spentBy.isEmpty ? 'Unknown' : t.spentBy,
            style: const TextStyle(fontSize: 13, color: kTextMid)),
          const Spacer(),
        ] else
          Expanded(child: Text(t.spentFor, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500,
            decoration: t.paid ? TextDecoration.lineThrough : null))),
        if (!isSubRow && t.paid) Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: const Text('Paid', style: TextStyle(fontSize: 10, color: kAccent, fontWeight: FontWeight.w600)),
        ),
      ]),
      subtitle: isSubRow ? null
          : Text('${t.spentBy} · ${t.date}', style: const TextStyle(fontSize: 11, color: kTextLight)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(formatINRFull(t.amount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        if (!sp.isReadOnly) PopupMenuButton(itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'paid', child: Text(t.paid ? 'Mark Unpaid' : 'Mark Paid',
            style: TextStyle(color: t.paid ? kTextMid : kAccent))),
          PopupMenuItem(value: 'toggle', child: Text(t.nextBill ? 'Move to This Bill' : 'Move to Next Bill')),
          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: kDanger))),
        ], onSelected: (v) {
          if (v == 'edit') {
            showModalBottomSheet(context: context, isScrollControlled: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => _AddTxnSheet(card: card, monthKey: monthKey, sp: sp, existing: t));
          } else if (v == 'paid') {
            sp.toggleCardTxnPaid(card.id, monthKey, t.id);
          } else if (v == 'toggle') {
            sp.toggleNextBill(card.id, monthKey, t.id);
          } else {
            showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete transaction?'),
                content: Text('Remove "${t.spentFor}"? This cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete', style: TextStyle(color: kDanger))),
                ],
              ),
            ).then((ok) { if (ok == true) sp.deleteCardTxn(card.id, monthKey, t.id); });
          }
        }),
      ]),
    ),
  );
}

class _AddTxnSheet extends StatefulWidget {
  final CreditCard card; final String monthKey; final StateProvider sp;
  final CardTxn? existing;
  const _AddTxnSheet({required this.card, required this.monthKey, required this.sp, this.existing});
  @override
  State<_AddTxnSheet> createState() => _AddTxnSheetState();
}

class _SplitRow {
  final String person;
  final TextEditingController ctrl;
  bool included;
  _SplitRow(this.person) : ctrl = TextEditingController(), included = true;
}

class _AddTxnSheetState extends State<_AddTxnSheet> {
  final _forCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  String? _spentBy;
  bool _nextBill = false;
  late DateTime _date;
  bool _splitMode = false;
  List<_SplitRow> _splits = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _forCtrl.text = e.spentFor;
      _amtCtrl.text = e.amount.toStringAsFixed(0);
      _spentBy = e.spentBy.isNotEmpty ? e.spentBy : null;
      _nextBill = e.nextBill;
      _date = DateTime.tryParse(e.date) ?? DateTime.now();
    } else {
      _spentBy = widget.sp.state.people.isNotEmpty ? widget.sp.state.people.first : null;
      _date = DateTime.now();
      _splits = widget.sp.state.people.map((p) => _SplitRow(p)).toList();
    }
  }

  @override
  void dispose() {
    _forCtrl.dispose(); _amtCtrl.dispose();
    for (final s in _splits) s.ctrl.dispose();
    super.dispose();
  }

  void _equalSplit() {
    final total = double.tryParse(_amtCtrl.text) ?? 0;
    final active = _splits.where((s) => s.included).toList();
    if (active.isEmpty || total <= 0) return;
    final share = (total / active.length);
    final shareStr = share % 1 == 0 ? share.toStringAsFixed(0) : share.toStringAsFixed(2);
    setState(() {
      for (final s in _splits) {
        s.ctrl.text = s.included ? shareStr : '';
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (_forCtrl.text.isEmpty) return;
    final dateStr = '${_date.year}-${_date.month.toString().padLeft(2,'0')}-${_date.day.toString().padLeft(2,'0')}';

    if (_splitMode && !_isEdit) {
      final entries = _splits.where((s) => s.included).map((s) {
        final amt = double.tryParse(s.ctrl.text) ?? 0;
        return (person: s.person, amt: amt);
      }).where((e) => e.amt > 0).toList();
      if (entries.isEmpty) return;
      final groupId = genId();
      for (final e in entries) {
        widget.sp.addCardTxn(widget.card.id, widget.monthKey, CardTxn(
          id: genId(), spentFor: _forCtrl.text.trim(),
          spentBy: e.person, amount: e.amt, date: dateStr, nextBill: _nextBill,
          splitGroupId: groupId,
        ));
      }
    } else {
      final amt = double.tryParse(_amtCtrl.text) ?? 0;
      if (amt <= 0) return;
      if (_isEdit) {
        widget.sp.updateCardTxn(widget.card.id, widget.monthKey, CardTxn(
          id: widget.existing!.id, spentFor: _forCtrl.text.trim(),
          spentBy: _spentBy ?? '', amount: amt, date: dateStr,
          nextBill: _nextBill, paid: widget.existing!.paid,
        ));
      } else {
        widget.sp.addCardTxn(widget.card.id, widget.monthKey, CardTxn(
          id: genId(), spentFor: _forCtrl.text.trim(),
          spentBy: _spentBy ?? '', amount: amt, date: dateStr, nextBill: _nextBill,
        ));
      }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_isEdit ? 'Edit Transaction — ${widget.card.name}' : 'Add Transaction — ${widget.card.name}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      TextField(controller: _forCtrl, decoration: const InputDecoration(labelText: 'Spent for')),
      const SizedBox(height: 12),
      // Split toggle (only for new txns with multiple people)
      if (!_isEdit && widget.sp.state.people.length > 1) ...[
        Row(children: [
          const Text('Split between people', style: TextStyle(fontSize: 14)),
          const Spacer(),
          Switch(
            value: _splitMode,
            onChanged: (v) => setState(() => _splitMode = v),
          ),
        ]),
        const SizedBox(height: 4),
      ],
      if (!_splitMode) ...[
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
        const SizedBox(height: 12),
      ] else ...[
        // Total amount + equal split button
        Row(children: [
          Expanded(child: TextField(controller: _amtCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Total amount', prefixText: '₹'))),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _equalSplit,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            child: const Text('Equal\nSplit', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 12),
        // Per-person amount rows
        ..._splits.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Checkbox(
              value: s.included,
              onChanged: (v) => setState(() { s.included = v ?? true; if (!s.included) s.ctrl.clear(); }),
            ),
            Expanded(child: Text(s.person, style: const TextStyle(fontSize: 14))),
            SizedBox(width: 110, child: TextField(
              controller: s.ctrl,
              keyboardType: TextInputType.number,
              enabled: s.included,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                prefixText: '₹', isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            )),
          ]),
        )),
        const SizedBox(height: 4),
        // Running total
        ValueListenableBuilder(
          valueListenable: _amtCtrl,
          builder: (_, __, ___) {
            final splitSum = _splits.where((s) => s.included)
                .fold(0.0, (sum, s) => sum + (double.tryParse(s.ctrl.text) ?? 0));
            final total = double.tryParse(_amtCtrl.text) ?? 0;
            final diff = (total - splitSum).abs();
            final balanced = diff < 0.01;
            return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(
                balanced ? '✓ Balanced' : 'Diff: ₹${diff.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12,
                  color: balanced ? kAccent : kDanger,
                  fontWeight: FontWeight.w600),
              ),
            ]);
          },
        ),
        const SizedBox(height: 8),
      ],
      // Date picker
      GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 16, color: kTextMid),
            const SizedBox(width: 8),
            Text('${_date.day}/${_date.month}/${_date.year}',
              style: const TextStyle(fontSize: 14, color: kTextDark)),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: kTextLight),
          ]),
        ),
      ),
      const SizedBox(height: 4),
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
          onPressed: _save,
          child: Text(_isEdit ? 'Save' : (_splitMode ? 'Add Split' : 'Add')),
        )),
      ]),
    ]))),
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
          decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.account_balance_wallet, color: kAccent, size: 20)),
        title: const Text('Cash / Wallet', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Pluxee, Slice, etc.', style: TextStyle(fontSize: 12, color: kTextLight)),
        trailing: Text(formatINRFull(total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
      if (cashTxns.isNotEmpty) ...[
        const Divider(height: 1),
        ...cashTxns.map((t) => Opacity(
          opacity: t.paid ? 0.5 : 1.0,
          child: ListTile(dense: true,
            title: Row(children: [
              Expanded(child: Text(t.spentFor, style: TextStyle(
                fontSize: 14,
                decoration: t.paid ? TextDecoration.lineThrough : null))),
              if (t.paid) Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Text('Paid', style: TextStyle(fontSize: 10, color: kAccent, fontWeight: FontWeight.w600)),
              ),
            ]),
            subtitle: Text('${t.spentBy} · ${t.source} · ${t.date}', style: const TextStyle(fontSize: 11, color: kTextLight)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(formatINRFull(t.amount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (!sp.isReadOnly) PopupMenuButton(itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'paid', child: Text(t.paid ? 'Mark Unpaid' : 'Mark Paid',
                  style: TextStyle(color: t.paid ? kTextMid : kAccent))),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: kDanger))),
              ], onSelected: (v) {
                if (v == 'edit') {
                  showModalBottomSheet(context: context, isScrollControlled: true,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => _AddCashSheet(monthKey: monthKey, sp: sp, existing: t));
                } else if (v == 'paid') {
                  sp.toggleCashTxnPaid(monthKey, t.id);
                } else {
                  showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete payment?'),
                      content: Text('Remove "${t.spentFor}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete', style: TextStyle(color: kDanger))),
                      ],
                    ),
                  ).then((ok) { if (ok == true) sp.deleteCashTxn(monthKey, t.id); });
                }
              }),
            ]),
          ),
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
  final CashTxn? existing;
  const _AddCashSheet({required this.monthKey, required this.sp, this.existing});
  @override
  State<_AddCashSheet> createState() => _AddCashSheetState();
}

class _AddCashSheetState extends State<_AddCashSheet> {
  final _forCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _srcCtrl = TextEditingController();
  String? _spentBy;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _forCtrl.text = e.spentFor;
      _amtCtrl.text = e.amount.toStringAsFixed(0);
      _srcCtrl.text = e.source;
      _spentBy = e.spentBy.isNotEmpty ? e.spentBy : null;
    } else {
      _spentBy = widget.sp.state.people.isNotEmpty ? widget.sp.state.people.first : null;
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_isEdit ? 'Edit Cash Payment' : 'Add Cash Payment',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
            if (_isEdit) {
              widget.sp.updateCashTxn(widget.monthKey, CashTxn(
                id: widget.existing!.id, spentFor: _forCtrl.text.trim(),
                spentBy: _spentBy ?? '', source: src,
                date: widget.existing!.date, amount: amt,
                paid: widget.existing!.paid,
              ));
            } else {
              widget.sp.addCashTxn(widget.monthKey, CashTxn(
                id: genId(), spentFor: _forCtrl.text.trim(),
                spentBy: _spentBy ?? '', source: src,
                date: DateTime.now().toIso8601String().split('T')[0], amount: amt,
              ));
            }
            Navigator.pop(context);
          },
          child: Text(_isEdit ? 'Save' : 'Add'),
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
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete card?'),
                    content: Text('Remove "${c.name}" and all its transactions? This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete', style: TextStyle(color: kDanger))),
                    ],
                  ),
                ).then((ok) { if (ok == true) { widget.sp.deleteCard(c.id); setState(() {}); } })),
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

class _CardsShareSheet extends StatefulWidget {
  final String text;
  const _CardsShareSheet({required this.text});
  @override
  State<_CardsShareSheet> createState() => _CardsShareSheetState();
}

class _CardsShareSheetState extends State<_CardsShareSheet> {
  final _shareKey = GlobalKey();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Share Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Container(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
          child: Text(widget.text, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: kTextDark)),
        )),
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
