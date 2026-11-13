import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback + input formatters
import 'package:provider/provider.dart';
import '../models/bill_model.dart';
import '../services/bill_provider.dart';
import '../services/bill_notification_service.dart';
import '../utils/constants.dart';

class BillAddEditScreen extends StatefulWidget {
  final Bill? bill; // null = adding new
  const BillAddEditScreen({super.key, this.bill});

  @override
  State<BillAddEditScreen> createState() => _BillAddEditScreenState();
}

class _BillAddEditScreenState extends State<BillAddEditScreen> {
  final _nameCtrl   = TextEditingController();
  final _amtCtrl    = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  late BillTypeInfo _selType;
  late BillCycle    _cycle;
  bool _isIrregular = false;
  int  _dueDay   = 1;
  int? _dueMonth;      // for quarterly start-month
  DateTime? _dueDate;  // for yearly / irregular first due date

  List<BillAlert> _alerts = [
    const BillAlert(id: 'a1', daysBefore: 3, hour: 9, minute: 0),
  ];

  bool _saving = false;

  bool get _isEdit => widget.bill != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final b = widget.bill!;
      _nameCtrl.text  = b.name;
      _amtCtrl.text   = formatAmountInput(b.amount);
      _selType      = billTypeInfo(b.type);
      _cycle        = b.cycle;
      _isIrregular  = b.isIrregular;
      _dueDay       = b.dueDay;
      _dueMonth = b.dueMonth;
      if (b.nextDueDate.isNotEmpty) {
        try { _dueDate = DateTime.parse(b.nextDueDate); } catch (_) {}
      }
      _alerts = List.from(b.alerts);
    } else {
      _selType      = kBillTypes.first;
      _cycle        = BillCycle.monthly;
      _isIrregular  = false;
      _dueDay       = DateTime.now().day;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _computeNextDueDate() {
    final today = DateTime.now();
    if (_isIrregular) {
      return _dueDate != null ? Bill.fmtDate(_dueDate!) : Bill.fmtDate(today.add(const Duration(days: 30)));
    }
    switch (_cycle) {
      case BillCycle.monthly:
        final d = DateTime(today.year, today.month, _dueDay);
        return Bill.fmtDate(d.isBefore(today) ? DateTime(today.year, today.month + 1, _dueDay) : d);
      case BillCycle.quarterly:
        final startM = _dueMonth ?? today.month;
        DateTime d = DateTime(today.year, startM, _dueDay);
        while (d.isBefore(today)) { d = DateTime(d.year, d.month + 3, _dueDay); }
        return Bill.fmtDate(d);
      case BillCycle.yearly:
        if (_dueDate != null) {
          DateTime d = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
          while (d.isBefore(today)) { d = DateTime(d.year + 1, d.month, d.day); }
          return Bill.fmtDate(d);
        }
        return Bill.fmtDate(DateTime(today.year + 1, today.month, _dueDay));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final bp = context.read<BillProvider>();
    final amount = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    final typeInfo = _selType;

    final nextDue = _computeNextDueDate();

    final bill = Bill(
      id:          _isEdit ? widget.bill!.id : genId(),
      name:        _nameCtrl.text.trim().isEmpty ? typeInfo.label : _nameCtrl.text.trim(),
      type:        typeInfo.type,
      icon:        typeInfo.icon,
      cycle:       _cycle,
      amount:      amount,
      colorHex:    typeInfo.colorHex,
      dueDay:      _dueDay,
      dueMonth:    _dueMonth,
      nextDueDate: nextDue,
      isIrregular: _isIrregular,
      alerts:      _alerts,
      createdAt:   _isEdit ? widget.bill!.createdAt : DateTime.now().millisecondsSinceEpoch,
    );

    if (_isEdit) {
      await bp.updateBill(bill);
    } else {
      await bp.addBill(bill);
    }
    await BillNotificationService.instance.scheduleBillAlerts(bill);
    if (mounted) Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_isEdit ? 'Edit Bill' : 'Add Recurring Bill',
          style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // ── Type picker ─────────────────────────────────────────────────
          _Section(title: 'Bill Type', child: _TypeGrid(
            selected: _selType,
            onSelect: (t) => setState(() {
              _selType = t;
              if (_nameCtrl.text.isEmpty || kBillTypes.any((x) => x.label == _nameCtrl.text)) {
                _nameCtrl.text = t.label;
              }
            }),
          )),
          const SizedBox(height: 16),

          // ── Name & Amount ───────────────────────────────────────────────
          _Section(title: 'Details', child: Column(children: [
            _Field(
              controller: _nameCtrl,
              label: 'Bill name',
              hint: _selType.label,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 10),
            _Field(
              controller: _amtCtrl,
              label: 'Amount (₹)',
              hint: '0',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [kAmountInputFormatter],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                if ((double.tryParse(v) ?? 0) <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
          ])),
          const SizedBox(height: 16),

          // ── Cycle ───────────────────────────────────────────────────────
          _Section(title: 'Billing Cycle', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Regular / Irregular toggle
            Row(children: [
              Expanded(child: _Chip(
                label: 'Regular',
                selected: !_isIrregular,
                onTap: () => setState(() => _isIrregular = false),
              )),
              const SizedBox(width: 10),
              Expanded(child: _Chip(
                label: 'Irregular',
                selected: _isIrregular,
                onTap: () => setState(() => _isIrregular = true),
              )),
            ]),
            const SizedBox(height: 14),
            if (_isIrregular) ...[
              const Text('No fixed cycle — you set the next due date each time you pay.',
                style: TextStyle(fontSize: 12, color: kTextLight)),
              const SizedBox(height: 10),
              const Text('First due date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMid)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2040),
                  );
                  if (d != null) setState(() => _dueDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: kPrimary),
                    const SizedBox(width: 10),
                    Text(
                      _dueDate != null
                        ? '${_dueDate!.day} ${kMonths[_dueDate!.month - 1]} ${_dueDate!.year}'
                        : 'Pick due date',
                      style: TextStyle(fontSize: 14,
                        color: _dueDate != null ? kTextDark : kTextLight),
                    ),
                  ]),
                ),
              ),
            ] else ...[
              Row(children: BillCycle.values.map((c) => Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _Chip(
                  label: c == BillCycle.monthly ? 'Monthly' : c == BillCycle.quarterly ? 'Quarterly' : 'Yearly',
                  selected: _cycle == c,
                  onTap: () => setState(() => _cycle = c),
                ),
              ))).toList()),
              const SizedBox(height: 14),
              _buildDueDatePicker(),
            ],
          ])),
          const SizedBox(height: 16),

          // ── Reminders ───────────────────────────────────────────────────
          _Section(title: 'Reminders', child: _AlertsEditor(
            alerts: _alerts,
            onChange: (a) => setState(() => _alerts = a),
          )),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ── Due date picker by cycle ──────────────────────────────────────────────

  Widget _buildDueDatePicker() {
    switch (_cycle) {
      case BillCycle.monthly:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Due on day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMid)),
          const SizedBox(height: 8),
          _DayPicker(value: _dueDay, onChanged: (d) => setState(() => _dueDay = d)),
        ]);

      case BillCycle.quarterly:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Start month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMid)),
          const SizedBox(height: 4),
          const Text('Bill repeats every 3 months from this month', style: TextStyle(fontSize: 11, color: kTextLight)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: List.generate(12, (i) {
            final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
            final sel = (_dueMonth ?? 1) == i + 1;
            return GestureDetector(
              onTap: () => setState(() => _dueMonth = i + 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? kPrimary : const Color(0xFFE5E7EB)),
                ),
                child: Text(months[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : kTextDark)),
              ),
            );
          })),
          const SizedBox(height: 10),
          const Text('Due on day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMid)),
          const SizedBox(height: 8),
          _DayPicker(value: _dueDay, onChanged: (d) => setState(() => _dueDay = d)),
        ]);

      case BillCycle.yearly:
        final dateLabel = _dueDate != null
            ? '${_dueDate!.day} ${kMonths[_dueDate!.month - 1]} ${_dueDate!.year}'
            : 'Pick due date';
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Annual due date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMid)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2040),
              );
              if (picked != null) setState(() {
                _dueDate = picked;
                _dueDay  = picked.day;
                _dueMonth = picked.month;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: kPrimary),
                const SizedBox(width: 10),
                Text(dateLabel, style: TextStyle(fontSize: 14,
                  color: _dueDate != null ? kTextDark : kTextLight)),
              ]),
            ),
          ),
        ]);
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
        letterSpacing: 0.6, color: kTextLight)),
      const SizedBox(height: 12),
      child,
    ]),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  const _Field({required this.controller, required this.label, required this.hint,
    this.keyboardType, this.inputFormatters, this.validator});
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    validator: validator,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextDark),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
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
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? kPrimary : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? kPrimary : const Color(0xFFE5E7EB)),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: selected ? Colors.white : kTextDark,
      )),
    ),
  );
}

// ── Type grid ─────────────────────────────────────────────────────────────────

class _TypeGrid extends StatelessWidget {
  final BillTypeInfo selected;
  final ValueChanged<BillTypeInfo> onSelect;
  const _TypeGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.0),
    itemCount: kBillTypes.length,
    itemBuilder: (_, i) {
      final t = kBillTypes[i];
      final sel = t.type == selected.type;
      final c = Color(int.parse(t.colorHex.replaceFirst('#', 'FF'), radix: 16));
      return GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onSelect(t); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: sel ? c.withValues(alpha: 0.15) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? c : const Color(0xFFE5E7EB), width: sel ? 2 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(t.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(t.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: sel ? c : kTextMid), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
    },
  );
}

// ── Day picker (1-31 scroll) ──────────────────────────────────────────────────

class _DayPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _DayPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 31,
      itemBuilder: (_, i) {
        final d = i + 1;
        final sel = d == value;
        return GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); onChanged(d); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 36, height: 36,
            margin: const EdgeInsets.only(right: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? kPrimary : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$d', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: sel ? Colors.white : kTextDark)),
          ),
        );
      },
    ),
  );
}

// ── Alerts editor ─────────────────────────────────────────────────────────────

class _AlertsEditor extends StatelessWidget {
  final List<BillAlert> alerts;
  final ValueChanged<List<BillAlert>> onChange;
  const _AlertsEditor({required this.alerts, required this.onChange});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    ...alerts.asMap().entries.map((entry) {
      final i = entry.key;
      final a = entry.value;
      return _AlertRow(
        alert: a,
        onRemove: alerts.length > 1 ? () {
          final upd = List<BillAlert>.from(alerts)..removeAt(i);
          onChange(upd);
        } : null,
        onDaysChanged: (d) {
          final upd = List<BillAlert>.from(alerts);
          upd[i] = BillAlert(id: a.id, daysBefore: d, hour: a.hour, minute: a.minute);
          onChange(upd);
        },
      );
    }),
    const SizedBox(height: 10),
    if (alerts.length < 3)
      GestureDetector(
        onTap: () {
          final id = 'a${DateTime.now().millisecondsSinceEpoch}';
          onChange([...alerts, BillAlert(id: id, daysBefore: 1, hour: 9)]);
        },
        child: Row(children: const [
          Icon(Icons.add_circle_outline_rounded, size: 18, color: kPrimary),
          SizedBox(width: 6),
          Text('Add another reminder', style: TextStyle(fontSize: 13, color: kPrimary, fontWeight: FontWeight.w600)),
        ]),
      ),
  ]);
}

class _AlertRow extends StatelessWidget {
  final BillAlert alert;
  final VoidCallback? onRemove;
  final ValueChanged<int> onDaysChanged;
  const _AlertRow({required this.alert, this.onRemove, required this.onDaysChanged});

  @override
  Widget build(BuildContext context) {
    const opts = [0, 1, 2, 3, 5, 7, 14];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        const Icon(Icons.notifications_outlined, size: 18, color: kPrimary),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<int>(
          value: opts.contains(alert.daysBefore) ? alert.daysBefore : 3,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          items: opts.map((d) => DropdownMenuItem(value: d,
            child: Text(d == 0 ? 'On due date' : '$d day${d == 1 ? '' : 's'} before',
              style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) { if (v != null) onDaysChanged(v); },
        )),
        if (onRemove != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: kDanger),
          ),
        ],
      ]),
    );
  }
}
