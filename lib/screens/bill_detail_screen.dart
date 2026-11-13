import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/bill_model.dart';
import '../services/bill_provider.dart';
import '../services/state_provider.dart';
import '../services/bill_notification_service.dart';
import '../utils/constants.dart';
import 'bill_add_edit_screen.dart';

class BillDetailScreen extends StatefulWidget {
  final Bill bill;
  const BillDetailScreen({super.key, required this.bill});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  List<BillPayment>? _payments;
  bool _loadingPayments = true;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    try {
      final bp = context.read<BillProvider>();
      final p  = await bp.loadPayments(widget.bill.id)
          .timeout(const Duration(seconds: 10));
      if (mounted) setState(() { _payments = p; _loadingPayments = false; });
    } catch (e) {
      debugPrint('loadPayments error: $e');
      if (mounted) setState(() { _payments = []; _loadingPayments = false; });
    }
  }

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  void _showMarkPaid(BuildContext context) {
    HapticFeedback.mediumImpact();
    final bill = widget.bill;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MarkPaidSheet(
        bill: bill,
        onPaid: () async {
          await _fetchPayments();
        },
      ),
    );
  }

  void _deleteBill() async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Bill'),
        content: Text('Remove "${widget.bill.name}" and all its payment history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kDanger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<BillProvider>().deleteBill(widget.bill.id);
    await BillNotificationService.instance.cancelBillAlerts(widget.bill.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Get live bill from provider if available
    final bp       = context.watch<BillProvider>();
    final readOnly = context.watch<StateProvider>().isReadOnly;
    final bill     = bp.bills.firstWhere((b) => b.id == widget.bill.id, orElse: () => widget.bill);
    final c    = bill.statusColor;
    final d    = bill.daysUntilDue;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(bill.name, style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
        actions: readOnly ? [] : [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => BillAddEditScreen(bill: bill))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteBill,
          ),
        ],
      ),
      body: Column(children: [
        // ── Status hero ───────────────────────────────────────────────────
        Container(
          color: kPrimary,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Text(bill.icon, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${bill.cycleLabel} · ${bill.type.toUpperCase()}',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                Text(formatINRFull(bill.amount),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                Text('Due ${_fmtDate(bill.nextDueParsed)}',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  d < 0 ? '${d.abs()}d overdue' : d == 0 ? 'Today' : '${d}d left',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ]),
          ),
        ),

        // ── List ──────────────────────────────────────────────────────────
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          // Alerts info
          if (bill.alerts.isNotEmpty)
            _InfoCard(children: bill.alerts.map<Widget>((a) => Row(children: [
              const Icon(Icons.notifications_outlined, size: 16, color: kPrimary),
              const SizedBox(width: 8),
              Expanded(child: Text(a.daysBefore == 0 ? 'Reminder on due date at ${a.timeLabel}'
                : 'Reminder ${a.daysBefore} day${a.daysBefore == 1 ? '' : 's'} before at ${a.timeLabel}',
                style: const TextStyle(fontSize: 13, color: kTextDark))),
            ])).toList()),
          const SizedBox(height: 16),

          // Payment history
          Text('PAYMENT HISTORY', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 0.6, color: kTextLight)),
          const SizedBox(height: 8),
          if (_loadingPayments)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_payments == null || _payments!.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Center(
                child: Text('No payments recorded yet', style: TextStyle(color: kTextLight, fontSize: 13)),
              ),
            )
          else
            ..._payments!.map((p) => _PaymentTile(payment: p)),
          const SizedBox(height: 80),
        ])),
      ]),
      bottomNavigationBar: readOnly ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text('Mark as Paid for ${_fmtDate(bill.nextDueParsed)}'),
            onPressed: () => _showMarkPaid(context),
          ),
        ),
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.expand((w) => [w, const SizedBox(height: 8)]).toList()
        ..removeLast(),
    ),
  );
}

// ── Payment tile ──────────────────────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  final BillPayment payment;
  const _PaymentTile({required this.payment});

  String _fmtDate(String s) {
    try {
      final d = DateTime.parse(s);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return s; }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: payment.daysLate > 0 ? kDanger.withValues(alpha: 0.1) : kAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          payment.daysLate > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
          size: 20,
          color: payment.daysLate > 0 ? kDanger : kAccent,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Paid on ${_fmtDate(payment.paidOn)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark)),
        Text('For: ${_fmtDate(payment.dueDate)}${payment.daysLate > 0 ? ' · ${payment.daysLate}d late' : ' · On time'}',
          style: const TextStyle(fontSize: 11, color: kTextMid)),
      ])),
      Text(formatINRFull(payment.amount),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextDark)),
    ]),
  );
}

// ── Mark paid sheet ───────────────────────────────────────────────────────────

class _MarkPaidSheet extends StatefulWidget {
  final Bill bill;
  final VoidCallback onPaid;
  const _MarkPaidSheet({required this.bill, required this.onPaid});
  @override
  State<_MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends State<_MarkPaidSheet> {
  final _amtCtrl  = TextEditingController();
  final _daysCtrl = TextEditingController();
  DateTime _paidOn = DateTime.now();
  late DateTime _nextDue;
  bool _usePickDate = true; // for irregular: true=pick date, false=enter days
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amtCtrl.text = formatAmountInput(widget.bill.amount);
    if (widget.bill.isIrregular) {
      _nextDue = DateTime.now().add(const Duration(days: 30));
      _daysCtrl.text = '30';
    } else {
      try { _nextDue = DateTime.parse(widget.bill.advanceNextDueDate()); }
      catch (_) { _nextDue = DateTime.now().add(const Duration(days: 30)); }
    }
  }

  @override
  @override
  void dispose() { _amtCtrl.dispose(); _daysCtrl.dispose(); super.dispose(); }

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _confirm() async {
    HapticFeedback.mediumImpact();
    final amount = double.tryParse(_amtCtrl.text.trim()) ?? widget.bill.amount;
    final paidOnStr  = Bill.fmtDate(_paidOn);
    final dueStr     = widget.bill.nextDueDate;
    final daysLate   = _paidOn.difference(widget.bill.nextDueParsed).inDays.clamp(0, 9999);
    final nextDue    = Bill.fmtDate(_nextDue);

    setState(() => _saving = true);
    final bp = context.read<BillProvider>();
    await bp.markPaid(
      billId:      widget.bill.id,
      amount:      amount,
      paidOn:      paidOnStr,
      dueDate:     dueStr,
      daysLate:    daysLate,
      nextDueDate: nextDue,
    );
    final updated = widget.bill.copyWith(nextDueDate: nextDue);
    await BillNotificationService.instance.scheduleBillAlerts(updated);
    HapticFeedback.heavyImpact();
    widget.onPaid();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 36, height: 4,
        decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 20),
      const Text('Mark as Paid', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextDark)),
      Text('${widget.bill.name} · ${widget.bill.cycleLabel}',
        style: const TextStyle(fontSize: 13, color: kTextMid)),
      const SizedBox(height: 20),

      // Amount
      const Text('Amount Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMid)),
      const SizedBox(height: 6),
      TextFormField(
        controller: _amtCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [kAmountInputFormatter],
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextDark),
        decoration: InputDecoration(
          prefixText: '₹ ',
          prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kTextMid),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kPrimary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      const SizedBox(height: 16),

      // Paid on date
      const Text('Paid On', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMid)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _paidOn,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (d != null) setState(() => _paidOn = d);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: kPrimary),
            const SizedBox(width: 10),
            Text(_fmtDate(_paidOn), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextDark)),
          ]),
        ),
      ),
      const SizedBox(height: 8),

      // Next due date
      const Text('Next Due Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMid)),
      const SizedBox(height: 6),
      if (widget.bill.isIrregular) ...[
        // Toggle: Pick date / Enter days
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _usePickDate = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _usePickDate ? kPrimary : const Color(0xFFF3F4F6),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              ),
              child: Text('Pick date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: _usePickDate ? Colors.white : kTextDark)),
            ),
          )),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _usePickDate = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: !_usePickDate ? kPrimary : const Color(0xFFF3F4F6),
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
              ),
              child: Text('Enter days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: !_usePickDate ? Colors.white : kTextDark)),
            ),
          )),
        ]),
        const SizedBox(height: 10),
        if (_usePickDate)
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context, initialDate: _nextDue,
                firstDate: DateTime.now(), lastDate: DateTime(2040),
              );
              if (d != null) setState(() => _nextDue = d);
            },
            child: _NextDueTile(label: _fmtDate(_nextDue)),
          )
        else
          TextField(
            controller: _daysCtrl,
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final days = int.tryParse(v);
              if (days != null && days > 0) setState(() => _nextDue = DateTime.now().add(Duration(days: days)));
            },
            decoration: InputDecoration(
              hintText: 'e.g. 45',
              suffixText: 'days from today',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kPrimary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
      ] else
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context, initialDate: _nextDue,
              firstDate: DateTime.now(), lastDate: DateTime(2040),
            );
            if (d != null) setState(() => _nextDue = d);
          },
          child: _NextDueTile(label: _fmtDate(_nextDue)),
        ),
      const SizedBox(height: 20),

      SizedBox(width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _saving ? null : _confirm,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      ),
    ]),
  );
}

class _NextDueTile extends StatelessWidget {
  final String label;
  const _NextDueTile({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: kPrimary.withValues(alpha: 0.06),
      border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      const Icon(Icons.event_rounded, size: 18, color: kPrimary),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kPrimary)),
      const Spacer(),
      const Text('tap to change', style: TextStyle(fontSize: 11, color: kTextLight)),
    ]),
  );
}
