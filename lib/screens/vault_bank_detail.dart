import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/vault_provider.dart';
import '../models/vault_model.dart';
import '../utils/constants.dart';

class VaultBankDetailScreen extends StatefulWidget {
  final VaultCategory cat;
  const VaultBankDetailScreen({super.key, required this.cat});
  @override
  State<VaultBankDetailScreen> createState() => _VaultBankDetailScreenState();
}

class _VaultBankDetailScreenState extends State<VaultBankDetailScreen> {
  String? _expandedId;

  static const _bankColors = [
    Color(0xFF1D4ED8), Color(0xFF15803D), Color(0xFFB45309),
    Color(0xFF7C3AED), Color(0xFFBE123C), Color(0xFF0D9488),
    Color(0xFF0891B2), Color(0xFFEA580C),
  ];
  Color _bankColor(int idx) => _bankColors[idx % _bankColors.length];

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VaultProvider>();
    final cat = vp.categoriesForPerson(widget.cat.personId)
        .where((c) => c.id == widget.cat.id).firstOrNull ?? widget.cat;

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(slivers: [
        _buildAppBar(cat),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            if (cat.instances.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🏦', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 10),
                  const Text('No banks added yet', style: TextStyle(fontSize: 14, color: kTextMid)),
                  const SizedBox(height: 6),
                  const Text('Tap "+ Add Bank" to get started',
                      style: TextStyle(fontSize: 11, color: kTextLight)),
                ]),
              )
            else
              ...cat.instances.asMap().entries.map((en) => _BankInstanceCard(
                    instance: en.value,
                    color: _bankColor(en.key),
                    isExpanded: _expandedId == en.value.id,
                    onToggle: () => setState(() =>
                        _expandedId = _expandedId == en.value.id ? null : en.value.id),
                    onDelete: () => _confirmDeleteBank(context, vp, cat.id, en.value),
                    vp: vp,
                    catId: cat.id,
                  )),
          ])),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1e1b4b),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Bank', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
        onPressed: () => _addBank(context, vp, cat.id),
      ),
    );
  }

  SliverAppBar _buildAppBar(VaultCategory cat) {
    final totalCards = cat.instances.fold(0, (s, i) => s + i.cards.length);
    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      backgroundColor: const Color(0xFF1e1b4b),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF1e1b4b), Color(0xFF312e81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)),
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 42, 16, 12),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Center(child: Text('🏦', style: TextStyle(fontSize: 18)))),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                const Text('Bank Accounts',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('${cat.instances.length} bank${cat.instances.length == 1 ? '' : 's'} · $totalCards card${totalCards == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 10, color: Colors.white60)),
              ]),
            ]),
          )),
        ),
      ),
    );
  }

  Future<void> _addBank(BuildContext context, VaultProvider vp, String catId) async {
    final nameCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Bank Account',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Bank Name', hintText: 'e.g. HDFC, SBI, ICICI'),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e1b4b), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final instance = VaultBankInstance(
                id: genId(), bankName: nameCtrl.text.trim(),
                fields: buildBankInstanceFields());
              await vp.addBankInstance(catId, instance);
              if (mounted) setState(() => _expandedId = instance.id);
            },
            child: const Text('Add Bank', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
          )),
        ]),
      ),
    );
  }

  Future<void> _confirmDeleteBank(BuildContext context, VaultProvider vp, String catId, VaultBankInstance instance) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Bank Account?'),
      content: Text('Delete "${instance.bankName}"? All fields and cards will be removed permanently.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ));
    if (ok == true) await vp.deleteBankInstance(catId, instance.id);
  }
}

// ── Bank instance card ─────────────────────────────────────────────────────────
class _BankInstanceCard extends StatelessWidget {
  final VaultBankInstance instance;
  final Color color;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VaultProvider vp;
  final String catId;

  const _BankInstanceCard({
    required this.instance, required this.color, required this.isExpanded,
    required this.onToggle, required this.onDelete, required this.vp, required this.catId,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        InkWell(
          onTap: onToggle,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(
                  instance.bankName.isNotEmpty ? instance.bankName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(instance.bankName,
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark)),
                Text('${instance.fields.length} field${instance.fields.length == 1 ? '' : 's'} · ${instance.cards.length} card${instance.cards.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 10, color: kTextLight)),
              ])),
              Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: kTextLight, size: 20),
            ]),
          ),
        ),

        if (isExpanded) ...[
          const Divider(height: 1, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Account fields (key-value, editable keys) ──
              ...instance.fields.map((f) => _BankFieldCard(
                    field: f,
                    onSaveValue: (v) {
                      f.value = v;
                      vp.saveBankField(catId, instance.id, f);
                    },
                    onSaveLabel: (lbl) {
                      f.label = lbl;
                      vp.saveBankField(catId, instance.id, f);
                    },
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: f.value ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${f.label} copied'),
                          duration: const Duration(seconds: 1)));
                    },
                  )),

              // Add Field
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _addField(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: kTextLight.withValues(alpha: 0.5), style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_rounded, size: 13, color: kTextLight),
                    SizedBox(width: 4),
                    Text('Add Field', style: TextStyle(fontSize: 10, color: kTextLight, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),

              // ── Cards section ──
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Row(children: [
                  const Text('💳  Cards',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: kTextMid, letterSpacing: 0.4)),
                  if (instance.cards.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
                      child: Text('${instance.cards.length}',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kTextMid)),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _addCard(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: const Text('＋ Add Card',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimary)),
                    ),
                  ),
                ]),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),

              if (instance.cards.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: kTextLight.withValues(alpha: 0.3), style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(children: [
                    Text('💳', style: TextStyle(fontSize: 24)),
                    SizedBox(height: 4),
                    Text('No cards yet', style: TextStyle(fontSize: 10, color: kTextLight)),
                    Text('Tap "+ Add Card" to add Debit, Credit or other card',
                        style: TextStyle(fontSize: 9, color: kTextLight)),
                  ]),
                )
              else
                ...instance.cards.map((card) => _CardBlock(
                      card: card,
                      catId: catId,
                      instanceId: instance.id,
                      vp: vp,
                      onDelete: () => _confirmDeleteCard(context, card),
                      onCopyField: (f) {
                        Clipboard.setData(ClipboardData(text: f.value ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('${f.label} copied'),
                            duration: const Duration(seconds: 1)));
                      },
                    )),

              // Delete bank
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: kDanger.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.delete_outline_rounded, size: 13, color: kDanger),
                    SizedBox(width: 4),
                    Text('Delete This Bank', style: TextStyle(fontSize: 10, color: kDanger, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Future<void> _addField(BuildContext context) async {
    final labelCtrl = TextEditingController();
    var fieldType = VaultFieldType.text;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Field',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: labelCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Field Name')),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final t in VaultFieldType.values)
              ChoiceChip(
                label: Text(t.name, style: const TextStyle(fontSize: 11)),
                selected: fieldType == t,
                onSelected: (_) => setS(() => fieldType = t),
                selectedColor: kPrimary.withValues(alpha: 0.15),
              ),
          ]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () async {
              if (labelCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final newField = VaultField(
                id: genId(), label: labelCtrl.text.trim(), type: fieldType,
                sortOrder: instance.fields.length);
              instance.fields.add(newField);
              await vp.saveBankField(catId, instance.id, newField);
            },
            child: const Text('Add'),
          )),
        ]),
      )),
    );
  }

  Future<void> _addCard(BuildContext context) async {
    var cardType = VaultCardType.debit;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Card',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          const Text('Card Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextMid)),
          const SizedBox(height: 10),
          Row(children: [
            for (final t in VaultCardType.values) ...[
              Expanded(child: GestureDetector(
                onTap: () => setS(() => cardType = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: cardType == t ? _cardColor(t) : kBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardType == t ? _cardColor(t) : kTextLight.withValues(alpha: 0.3)),
                  ),
                  child: Center(child: Text(_cardLabel(t),
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: cardType == t ? Colors.white : kTextMid))),
                ),
              )),
              if (t != VaultCardType.values.last) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 20),
          const Text('Card fields (Card Number, CVV, Expiry) will be added automatically.',
              style: TextStyle(fontSize: 10, color: kTextLight)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _cardColor(cardType), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              final card = VaultBankCard(id: genId(), cardType: cardType, fields: buildBankCardFields());
              await vp.addBankCard(catId, instance.id, card);
            },
            child: Text('Add ${_cardLabel(cardType)} Card',
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
          )),
        ]),
      )),
    );
  }

  Future<void> _confirmDeleteCard(BuildContext context, VaultBankCard card) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Card?'),
      content: Text('Remove this ${_cardLabel(card.cardType)} card permanently?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ));
    if (ok == true) await vp.deleteBankCard(catId, instance.id, card.id);
  }

  static Color _cardColor(VaultCardType t) => switch (t) {
    VaultCardType.debit  => const Color(0xFF1D4ED8),
    VaultCardType.credit => const Color(0xFF7C3AED),
    VaultCardType.other  => const Color(0xFF374151),
  };

  static String _cardLabel(VaultCardType t) => switch (t) {
    VaultCardType.debit  => 'Debit',
    VaultCardType.credit => 'Credit',
    VaultCardType.other  => 'Other',
  };
}

// ── Bank field card (key editable, value reveal/copy/edit) ──────────────────────
class _BankFieldCard extends StatefulWidget {
  final VaultField field;
  final Function(String) onSaveValue;
  final Function(String) onSaveLabel;
  final VoidCallback onCopy;

  const _BankFieldCard({
    required this.field, required this.onSaveValue,
    required this.onSaveLabel, required this.onCopy,
  });
  @override
  State<_BankFieldCard> createState() => _BankFieldCardState();
}

class _BankFieldCardState extends State<_BankFieldCard> {
  bool _revealed = false;
  bool _editingValue = false;
  late TextEditingController _valCtrl;

  @override
  void initState() {
    super.initState();
    _valCtrl = TextEditingController(text: widget.field.value ?? '');
  }

  @override
  void dispose() {
    _valCtrl.dispose();
    super.dispose();
  }

  bool get _isHidden => widget.field.type == VaultFieldType.hidden;

  String get _display {
    final val = widget.field.value ?? '';
    if (_isHidden && !_revealed) {
      if (val.isEmpty) return '—';
      return val.length >= 4 ? '•••• ${val.substring(val.length - 4)}' : '••••';
    }
    return val.isNotEmpty ? val : '—';
  }

  void _editLabel() async {
    final ctrl = TextEditingController(text: widget.field.label);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Field Name', style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Field name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) widget.onSaveLabel(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label row with pencil
        Row(children: [
          Expanded(child: Text(widget.field.label,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                  letterSpacing: 0.6, color: kTextLight),
              overflow: TextOverflow.ellipsis)),
          GestureDetector(
            onTap: _editLabel,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.edit_rounded, size: 11, color: kPrimary.withValues(alpha: 0.65)),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        // Value row — edit mode shows full-width styled TextField
        if (_editingValue)
          TextField(
            controller: _valCtrl,
            autofocus: true,
            obscureText: _isHidden,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kPrimary.withValues(alpha: 0.4))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kPrimary.withValues(alpha: 0.4))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kPrimary, width: 1.5)),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: GestureDetector(
                onTap: () {
                  widget.onSaveValue(_valCtrl.text);
                  setState(() => _editingValue = false);
                },
                child: const Icon(Icons.done_rounded, color: kPrimary, size: 18),
              ),
            ),
            onSubmitted: (v) {
              widget.onSaveValue(v);
              setState(() => _editingValue = false);
            },
          )
        else
          Row(children: [
            Expanded(child: Text(_display,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: _isHidden && !_revealed ? kTextMid : kTextDark,
                    letterSpacing: _isHidden && !_revealed ? 1.5 : 0),
                overflow: TextOverflow.ellipsis)),
            if (_isHidden) GestureDetector(
              onTap: () => setState(() => _revealed = !_revealed),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(_revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 14, color: kTextLight)),
            ),
            GestureDetector(
              onTap: widget.onCopy,
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.copy_rounded, size: 14, color: kTextLight)),
            ),
            GestureDetector(
              onTap: () => setState(() => _editingValue = true),
              child: const Padding(padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.edit_note_rounded, size: 14, color: kTextLight)),
            ),
          ]),
      ]),
    );
  }
}

// ── Card block: gradient visual + field rows ──────────────────────────────────
class _CardBlock extends StatelessWidget {
  final VaultBankCard card;
  final String catId;
  final String instanceId;
  final VaultProvider vp;
  final VoidCallback onDelete;
  final Function(VaultField) onCopyField;

  const _CardBlock({
    required this.card, required this.catId, required this.instanceId,
    required this.vp, required this.onDelete, required this.onCopyField,
  });

  static Color _cardColor(VaultCardType t) => switch (t) {
    VaultCardType.debit  => const Color(0xFF1D4ED8),
    VaultCardType.credit => const Color(0xFF7C3AED),
    VaultCardType.other  => const Color(0xFF374151),
  };

  static Color _cardColorEnd(VaultCardType t) => switch (t) {
    VaultCardType.debit  => const Color(0xFF2563EB),
    VaultCardType.credit => const Color(0xFF9333EA),
    VaultCardType.other  => const Color(0xFF4B5563),
  };

  static String _cardLabel(VaultCardType t) => switch (t) {
    VaultCardType.debit  => 'DEBIT',
    VaultCardType.credit => 'CREDIT',
    VaultCardType.other  => 'OTHER',
  };

  VaultField? _field(String label) =>
      card.fields.where((f) => f.label == label).firstOrNull;

  String _last4(String? v) {
    final val = v ?? '';
    if (val.isEmpty) return '•••• •••• •••• ••••';
    final digits = val.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) return '•••• •••• •••• ${digits.substring(digits.length - 4)}';
    return '•••• •••• •••• ••••';
  }

  @override
  Widget build(BuildContext context) {
    final cardNum = _field('Card Number');
    final expiry = _field('Expiry');
    final c1 = _cardColor(card.cardType);
    final c2 = _cardColorEnd(card.cardType);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kTextLight.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: c1.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Mini card gradient visual
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c1, c2],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_cardLabel(card.cardType),
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                      color: Colors.white60, letterSpacing: 1.2)),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Remove', style: TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(_last4(cardNum?.value),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: 2)),
            const SizedBox(height: 8),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('EXPIRY', style: TextStyle(fontSize: 6, color: Colors.white54, letterSpacing: 0.8)),
                Text(expiry?.value?.isNotEmpty == true ? expiry!.value! : '––/––',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
              const SizedBox(width: 20),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CVV', style: TextStyle(fontSize: 6, color: Colors.white54, letterSpacing: 0.8)),
                const Text('•••', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ]),
          ]),
        ),

        // Field rows below the card visual
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(children: card.fields.map((f) => _CardFieldRow(
            field: f,
            cardId: card.id,
            catId: catId,
            instanceId: instanceId,
            vp: vp,
            onCopy: () => onCopyField(f),
          )).toList()),
        ),
      ]),
    );
  }
}

// ── Individual field row inside a card ─────────────────────────────────────────
class _CardFieldRow extends StatefulWidget {
  final VaultField field;
  final String cardId;
  final String catId;
  final String instanceId;
  final VaultProvider vp;
  final VoidCallback onCopy;

  const _CardFieldRow({
    required this.field, required this.cardId, required this.catId,
    required this.instanceId, required this.vp, required this.onCopy,
  });
  @override
  State<_CardFieldRow> createState() => _CardFieldRowState();
}

class _CardFieldRowState extends State<_CardFieldRow> {
  bool _revealed = false;
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.field.value ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isHidden => widget.field.type == VaultFieldType.hidden;

  String get _display {
    final val = widget.field.value ?? '';
    if (_isHidden && !_revealed) {
      if (val.isEmpty) return '—';
      if (widget.field.label == 'Card Number') return _last4(val);
      return val.length >= 1 ? '•••' : '—';
    }
    return val.isNotEmpty ? val : '—';
  }

  String _last4(String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) return '•••• •••• •••• ${digits.substring(digits.length - 4)}';
    return '•••• •••• •••• ••••';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.field.label,
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                letterSpacing: 0.6, color: kTextLight)),
        const SizedBox(height: 3),
        if (_editing)
          TextField(
            controller: _ctrl,
            autofocus: true,
            obscureText: _isHidden,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kPrimary.withValues(alpha: 0.4))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kPrimary.withValues(alpha: 0.4))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kPrimary, width: 1.5)),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: GestureDetector(
                onTap: () {
                  widget.field.value = _ctrl.text;
                  widget.vp.saveBankCardField(widget.catId, widget.instanceId, widget.cardId, widget.field);
                  setState(() => _editing = false);
                },
                child: const Icon(Icons.done_rounded, color: kPrimary, size: 18),
              ),
            ),
            onSubmitted: (v) {
              widget.field.value = v;
              _ctrl.text = v;
              widget.vp.saveBankCardField(widget.catId, widget.instanceId, widget.cardId, widget.field);
              setState(() => _editing = false);
            },
          )
        else
          Row(children: [
            Expanded(child: Text(_display,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: _isHidden && !_revealed ? kTextMid : kTextDark,
                    letterSpacing: _isHidden && !_revealed ? 1.2 : 0),
                overflow: TextOverflow.ellipsis)),
            if (_isHidden) GestureDetector(
              onTap: () => setState(() => _revealed = !_revealed),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(_revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 13, color: kTextLight)),
            ),
            GestureDetector(
              onTap: widget.onCopy,
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 3),
                child: Icon(Icons.copy_rounded, size: 13, color: kTextLight)),
            ),
            GestureDetector(
              onTap: () => setState(() => _editing = true),
              child: const Padding(padding: EdgeInsets.only(left: 3),
                child: Icon(Icons.edit_note_rounded, size: 13, color: kTextLight)),
            ),
          ]),
      ]),
    );
  }
}
