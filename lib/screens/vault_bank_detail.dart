import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
  final Set<String> _selectedBankIds = {};
  bool _bankSelectMode = false;
  final _shareBanksKey = GlobalKey();

  static const _bankColors = [
    Color(0xFF1D4ED8), Color(0xFF15803D), Color(0xFFB45309),
    Color(0xFF7C3AED), Color(0xFFBE123C), Color(0xFF0D9488),
    Color(0xFF0891B2), Color(0xFFEA580C),
  ];
  Color _bankColor(int idx) => _bankColors[idx % _bankColors.length];

  void _enterBankSelect(String id) => setState(() { _bankSelectMode = true; _selectedBankIds.add(id); });
  void _toggleBankSelect(String id) => setState(() {
    if (_selectedBankIds.contains(id)) { _selectedBankIds.remove(id); if (_selectedBankIds.isEmpty) _bankSelectMode = false; }
    else _selectedBankIds.add(id);
  });
  void _cancelBankSelect() => setState(() { _selectedBankIds.clear(); _bankSelectMode = false; });

  void _shareBanks(VaultCategory cat) {
    final selected = cat.instances.where((i) => _selectedBankIds.contains(i.id));
    final text = selected.map((inst) {
      final lines = inst.fields.map((f) => '  ${f.label}: ${f.value ?? ''}').join('\n');
      return '--- ${inst.bankName} ---\n$lines';
    }).join('\n\n');
    final box = _shareBanksKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    Share.share(withBranding(text.isEmpty ? '(no data)' : text), sharePositionOrigin: origin);
    _cancelBankSelect();
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VaultProvider>();
    final cat = vp.categoriesForPerson(widget.cat.personId)
        .where((c) => c.id == widget.cat.id).firstOrNull ?? widget.cat;

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(children: [
        CustomScrollView(slivers: [
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
                    const Text('No banks added yet', style: TextStyle(fontSize: 16, color: kTextMid)),
                    const SizedBox(height: 6),
                    const Text('Tap "+ Add Bank" to get started', style: TextStyle(fontSize: 13, color: kTextLight)),
                  ]),
                )
              else
                ...cat.instances.asMap().entries.map((en) => _BankInstanceCard(
                      instance: en.value,
                      color: _bankColor(en.key),
                      isExpanded: _expandedId == en.value.id,
                      bankSelectMode: _bankSelectMode,
                      isSelected: _selectedBankIds.contains(en.value.id),
                      onToggle: () {
                        if (_bankSelectMode) { _toggleBankSelect(en.value.id); return; }
                        setState(() => _expandedId = _expandedId == en.value.id ? null : en.value.id);
                      },
                      onLongPress: () => _enterBankSelect(en.value.id),
                      onDelete: () => _confirmDeleteBank(context, vp, cat.id, en.value),
                      vp: vp,
                      catId: cat.id,
                    )),
            ])),
          ),
        ]),

        // Floating share bar for selected banks
        if (_bankSelectMode)
          Positioned(
            bottom: 90, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: kTextDark, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                Text('${_selectedBankIds.length} bank${_selectedBankIds.length == 1 ? '' : 's'} selected',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _cancelBankSelect,
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                  label: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  key: _shareBanksKey,
                  onPressed: () => _shareBanks(cat),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ]),
            ),
          ),
      ]),
      floatingActionButton: _bankSelectMode ? null : FloatingActionButton.extended(
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
                    style: const TextStyle(fontSize: 11, color: Colors.white60)),
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
              style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 16),
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
            child: const Text('Add Bank', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16)),
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
class _BankInstanceCard extends StatefulWidget {
  final VaultBankInstance instance;
  final Color color;
  final bool isExpanded;
  final bool bankSelectMode;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final VaultProvider vp;
  final String catId;

  const _BankInstanceCard({
    required this.instance, required this.color, required this.isExpanded,
    required this.bankSelectMode, required this.isSelected,
    required this.onToggle, required this.onLongPress,
    required this.onDelete, required this.vp, required this.catId,
  });

  @override
  State<_BankInstanceCard> createState() => _BankInstanceCardState();
}

class _BankInstanceCardState extends State<_BankInstanceCard> {
  final Set<String> _selectedFields = {};
  bool _fieldSelectMode = false;
  bool _showNote = false;
  late TextEditingController _noteCtrl;
  final _shareFieldsKey = GlobalKey();
  final _shareCardsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.instance.note ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _enterFieldSelect(String id) => setState(() { _fieldSelectMode = true; _selectedFields.add(id); });
  void _toggleField(String id) => setState(() {
    if (_selectedFields.contains(id)) { _selectedFields.remove(id); if (_selectedFields.isEmpty) _fieldSelectMode = false; }
    else _selectedFields.add(id);
  });
  void _cancelFieldSelect() => setState(() { _selectedFields.clear(); _fieldSelectMode = false; });

  void _shareFields() {
    final lines = widget.instance.fields
        .where((f) => _selectedFields.contains(f.id))
        .map((f) => '${f.label}: ${f.value ?? ''}')
        .join('\n');
    final box = _shareFieldsKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    Share.share(withBranding('--- ${widget.instance.bankName} ---\n$lines'), sharePositionOrigin: origin);
    _cancelFieldSelect();
  }

  void _shareCards() {
    final lines = widget.instance.cards.map((card) {
      final cardNum = card.fields.where((f) => f.label == 'Card Number').firstOrNull;
      final expiry  = card.fields.where((f) => f.label == 'Expiry').firstOrNull;
      final type    = card.cardType.name.toUpperCase();
      return '$type Card\n  Card No: ${cardNum?.value ?? '—'}\n  Expiry: ${expiry?.value ?? '—'}';
    }).join('\n\n');
    final box = _shareCardsKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    Share.share(withBranding(lines.isEmpty ? '(no cards)' : '--- ${widget.instance.bankName} Cards ---\n$lines'), sharePositionOrigin: origin);
  }

  Future<void> _addField(BuildContext context) async {
    final labelCtrl = TextEditingController();
    var fieldType = VaultFieldType.text;
    bool hidden = false;

    final existingLabels = widget.instance.fields.map((f) => f.label.trim().toLowerCase()).toSet();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Field', style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: labelCtrl,
            autofocus: true,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(labelText: 'Field Name'),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final t in VaultFieldType.values)
              ChoiceChip(
                label: Text(t.name, style: const TextStyle(fontSize: 13)),
                selected: fieldType == t,
                onSelected: (_) => setS(() { fieldType = t; if (t == VaultFieldType.hidden) hidden = true; }),
                selectedColor: kPrimary.withValues(alpha: 0.15),
              ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mask value (hidden by default)', style: TextStyle(fontSize: 14)),
            value: hidden,
            activeColor: kPrimary,
            onChanged: (v) => setS(() => hidden = v),
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () async {
              final label = labelCtrl.text.trim();
              if (label.isEmpty) return;
              if (existingLabels.contains(label.toLowerCase())) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('A field named "$label" already exists'), backgroundColor: kDanger));
                return;
              }
              Navigator.pop(ctx);
              final newField = VaultField(
                id: genId(), label: label,
                type: hidden ? VaultFieldType.hidden : fieldType,
                sortOrder: widget.instance.fields.length);
              widget.instance.fields.add(newField);
              await widget.vp.saveBankField(widget.catId, widget.instance.id, newField);
            },
            child: const Text('Add', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
          const Text('Add Card', style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          const Text('Card Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextMid)),
          const SizedBox(height: 10),
          Row(children: [
            for (final t in VaultCardType.values) ...[
              Expanded(child: GestureDetector(
                onTap: () => setS(() => cardType = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: cardType == t ? _cardColor(t) : kBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardType == t ? _cardColor(t) : kTextLight.withValues(alpha: 0.3)),
                  ),
                  child: Center(child: Text(_cardLabel(t),
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: cardType == t ? Colors.white : kTextMid))),
                ),
              )),
              if (t != VaultCardType.values.last) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 14),
          const Text('Card Number, CVV and Expiry fields are added automatically.',
              style: TextStyle(fontSize: 12, color: kTextLight)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _cardColor(cardType), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              final card = VaultBankCard(id: genId(), cardType: cardType, fields: buildBankCardFields());
              await widget.vp.addBankCard(widget.catId, widget.instance.id, card);
            },
            child: Text('Add ${_cardLabel(cardType)} Card',
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16)),
          )),
        ]),
      )),
    );
  }

  Future<void> _deleteField(BuildContext context, VaultField field) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Field?'),
      content: Text('Delete "${field.label}"? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ));
    if (ok == true) {
      await widget.vp.deleteBankField(widget.catId, widget.instance.id, field.id);
    }
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
    if (ok == true) await widget.vp.deleteBankCard(widget.catId, widget.instance.id, card.id);
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

  @override
  Widget build(BuildContext context) {
    final instance = widget.instance;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.isSelected ? widget.color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: widget.isSelected
            ? Border.all(color: widget.color, width: 2)
            : Border(left: BorderSide(color: widget.color, width: 4)),
        boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        GestureDetector(
          onTap: widget.onToggle,
          onLongPress: widget.onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              // Selection indicator when in bank select mode
              if (widget.bankSelectMode)
                Padding(padding: const EdgeInsets.only(right: 10),
                  child: Icon(widget.isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 22, color: widget.isSelected ? widget.color : kTextLight)),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(
                  instance.bankName.isNotEmpty ? instance.bankName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(instance.bankName,
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700, color: kTextDark)),
                Text('${instance.fields.length} field${instance.fields.length == 1 ? '' : 's'} · ${instance.cards.length} card${instance.cards.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: kTextLight)),
              ])),
              Icon(widget.isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: kTextLight, size: 24),
            ]),
          ),
        ),

        if (widget.isExpanded) ...[
          const Divider(height: 1, indent: 14, endIndent: 14),
          Stack(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Account fields ──
                ...instance.fields.map((f) => _BankFieldCard(
                      field: f,
                      isSelected: _selectedFields.contains(f.id),
                      selectMode: _fieldSelectMode,
                      onSaveValue: (v) {
                        f.value = v;
                        widget.vp.saveBankField(widget.catId, instance.id, f);
                      },
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: f.value ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('${f.label} copied'),
                            duration: const Duration(seconds: 1)));
                      },
                      onLongPress: () => _enterFieldSelect(f.id),
                      onTap: () => _fieldSelectMode ? _toggleField(f.id) : null,
                      onDelete: () => _deleteField(context, f),
                    )),

                // Add Field
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => _addField(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Field', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary,
                    side: BorderSide(color: kPrimary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(double.infinity, 42),
                  ),
                ),

                // ── Cards section ──
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: Row(children: [
                    const Text('💳  Cards',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMid, letterSpacing: 0.4)),
                    if (instance.cards.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
                        child: Text('${instance.cards.length}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextMid)),
                      ),
                    ],
                    const Spacer(),
                    // Share cards
                    if (instance.cards.isNotEmpty)
                      GestureDetector(
                        key: _shareCardsKey,
                        onTap: _shareCards,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Icon(Icons.ios_share_rounded, size: 20, color: kTextLight),
                        ),
                      ),
                    // Add card
                    GestureDetector(
                      onTap: () => _addCard(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: const Text('＋ Add Card',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
                      ),
                    ),
                  ]),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),

                if (instance.cards.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: kTextLight.withValues(alpha: 0.3), style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Column(children: [
                      Text('💳', style: TextStyle(fontSize: 28)),
                      SizedBox(height: 6),
                      Text('No cards yet', style: TextStyle(fontSize: 13, color: kTextLight)),
                      Text('Tap "+ Add Card" to add Debit, Credit or other card',
                          style: TextStyle(fontSize: 12, color: kTextLight)),
                    ]),
                  )
                else
                  ...instance.cards.map((card) => _CardBlock(
                        card: card,
                        catId: widget.catId,
                        instanceId: instance.id,
                        vp: widget.vp,
                        onDelete: () => _confirmDeleteCard(context, card),
                        onCopyField: (f) {
                          Clipboard.setData(ClipboardData(text: f.value ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('${f.label} copied'),
                              duration: const Duration(seconds: 1)));
                        },
                      )),

                // ── Notes section ──
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _showNote = !_showNote),
                  child: Row(children: [
                    const Icon(Icons.sticky_note_2_outlined, size: 18, color: kTextLight),
                    const SizedBox(width: 6),
                    const Text('Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextMid)),
                    const Spacer(),
                    Icon(_showNote ? Icons.expand_less : Icons.expand_more, size: 20, color: kTextLight),
                  ]),
                ),
                if (_showNote) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kTextLight.withValues(alpha: 0.2)),
                    ),
                    child: TextField(
                      controller: _noteCtrl,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Write a private note for this bank…',
                        hintStyle: TextStyle(fontSize: 13, color: kTextLight),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerRight, child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13)),
                    onPressed: () => widget.vp.saveBankInstanceNote(widget.catId, widget.instance.id, _noteCtrl.text),
                    child: const Text('Save Note'),
                  )),
                ],
                const SizedBox(height: 4),

                // Delete bank
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kDanger),
                  label: const Text('Delete This Bank', style: TextStyle(fontSize: 14, color: kDanger, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kDanger,
                    side: BorderSide(color: kDanger.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(double.infinity, 42),
                  ),
                ),
              ]),
            ),

            // Field multi-select share bar
            if (_fieldSelectMode)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: kTextDark,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                  ),
                  child: Row(children: [
                    Text('${_selectedFields.length} field${_selectedFields.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _cancelFieldSelect,
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                      label: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                    ElevatedButton.icon(
                      key: _shareFieldsKey,
                      onPressed: _shareFields,
                      icon: const Icon(Icons.ios_share_rounded, size: 16),
                      label: const Text('Share', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ]),
                ),
              ),
          ]),
        ],
      ]),
    );
  }
}

// ── Bank field card ────────────────────────────────────────────────────────────
class _BankFieldCard extends StatefulWidget {
  final VaultField field;
  final bool isSelected;
  final bool selectMode;
  final Function(String) onSaveValue;
  final VoidCallback onCopy;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  const _BankFieldCard({
    required this.field, required this.isSelected, required this.selectMode,
    required this.onSaveValue, required this.onCopy,
    required this.onLongPress, required this.onTap, required this.onDelete,
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.selectMode ? null : widget.onLongPress,
      onTap: widget.selectMode ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isSelected ? kPrimary.withValues(alpha: 0.08) : kBg,
          borderRadius: BorderRadius.circular(10),
          border: widget.isSelected ? Border.all(color: kPrimary, width: 1.5) : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Label row (no editable pencil)
          Row(children: [
            if (widget.selectMode)
              Padding(padding: const EdgeInsets.only(right: 8),
                child: Icon(widget.isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 20, color: widget.isSelected ? kPrimary : kTextLight)),
            Expanded(child: Text(widget.field.label.toUpperCase(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    letterSpacing: 0.6, color: kTextLight),
                overflow: TextOverflow.ellipsis)),
            if (!widget.selectMode)
              GestureDetector(
                onTap: widget.onDelete,
                child: Padding(padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.delete_outline_rounded, size: 18, color: kDanger.withValues(alpha: 0.6))),
              ),
          ]),
          const SizedBox(height: 6),
          // Value row
          if (_editingValue)
            TextField(
              controller: _valCtrl,
              autofocus: true,
              obscureText: _isHidden,
              keyboardType: _keyboardType(widget.field.type),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kTextDark),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: kPrimary.withValues(alpha: 0.4))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: kPrimary.withValues(alpha: 0.4))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: kPrimary, width: 1.5)),
                filled: true, fillColor: Colors.white,
                suffixIcon: GestureDetector(
                  onTap: () { widget.onSaveValue(_valCtrl.text); setState(() => _editingValue = false); },
                  child: const Icon(Icons.done_rounded, color: kPrimary, size: 24),
                ),
              ),
              onSubmitted: (v) { widget.onSaveValue(v); setState(() => _editingValue = false); },
            )
          else
            Row(children: [
              Expanded(child: Text(_display,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600,
                      color: _isHidden && !_revealed ? kTextMid : kTextDark,
                      letterSpacing: _isHidden && !_revealed ? 1.5 : 0),
                  overflow: TextOverflow.ellipsis)),
              if (!widget.selectMode) ...[
                if (_isHidden) GestureDetector(
                  onTap: () => setState(() => _revealed = !_revealed),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(_revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 22, color: kTextLight)),
                ),
                GestureDetector(
                  onTap: widget.onCopy,
                  child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.copy_rounded, size: 22, color: kTextLight)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _editingValue = true),
                  child: const Padding(padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.edit_note_rounded, size: 22, color: kTextLight)),
                ),
              ],
            ]),
        ]),
      ),
    );
  }

  static TextInputType _keyboardType(VaultFieldType t) => switch (t) {
    VaultFieldType.number => TextInputType.number,
    VaultFieldType.date   => TextInputType.datetime,
    _                     => TextInputType.text,
  };
}

// ── Card block ────────────────────────────────────────────────────────────────
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

  VaultField? _field(String label) => card.fields.where((f) => f.label == label).firstOrNull;

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
    final expiry  = _field('Expiry');
    final c1 = _cardColor(card.cardType);
    final c2 = _cardColorEnd(card.cardType);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c1, c2],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_cardLabel(card.cardType),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.white60, letterSpacing: 1.2)),
              const Spacer(),
              // Share this card
              GestureDetector(
                onTap: () {
                  final lines = card.fields.map((f) => '${f.label}: ${f.value ?? ''}').join('\n');
                  final box = context.findRenderObject() as RenderBox?;
                  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
                  Share.share(withBranding('${_cardLabel(card.cardType)} Card\n$lines'), sharePositionOrigin: origin);
                },
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.ios_share_rounded, size: 18, color: Colors.white70),
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Remove', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(_last4(cardNum?.value),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: 2)),
            const SizedBox(height: 10),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('EXPIRY', style: TextStyle(fontSize: 9, color: Colors.white54, letterSpacing: 0.8)),
                Text(expiry?.value?.isNotEmpty == true ? expiry!.value! : '––/––',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
              const SizedBox(width: 24),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CVV', style: TextStyle(fontSize: 9, color: Colors.white54, letterSpacing: 0.8)),
                const Text('•••', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ]),
          ]),
        ),
        // Field rows
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

// ── Card field row ─────────────────────────────────────────────────────────────
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
  void initState() { super.initState(); _ctrl = TextEditingController(text: widget.field.value ?? ''); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  bool get _isHidden => widget.field.type == VaultFieldType.hidden;

  String get _display {
    final val = widget.field.value ?? '';
    if (_isHidden && !_revealed) {
      if (val.isEmpty) return '—';
      if (widget.field.label == 'Card Number') return _last4(val);
      return '•••';
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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.field.label.toUpperCase(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                letterSpacing: 0.6, color: kTextLight)),
        const SizedBox(height: 4),
        if (_editing)
          TextField(
            controller: _ctrl,
            autofocus: true,
            obscureText: _isHidden,
            keyboardType: widget.field.type == VaultFieldType.number ? TextInputType.number : TextInputType.text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kTextDark),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kPrimary.withValues(alpha: 0.4))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kPrimary.withValues(alpha: 0.4))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kPrimary, width: 1.5)),
              filled: true, fillColor: Colors.white,
              suffixIcon: GestureDetector(
                onTap: () {
                  widget.field.value = _ctrl.text;
                  widget.vp.saveBankCardField(widget.catId, widget.instanceId, widget.cardId, widget.field);
                  setState(() => _editing = false);
                },
                child: const Icon(Icons.done_rounded, color: kPrimary, size: 24),
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
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: _isHidden && !_revealed ? kTextMid : kTextDark,
                    letterSpacing: _isHidden && !_revealed ? 1.2 : 0),
                overflow: TextOverflow.ellipsis)),
            if (_isHidden) GestureDetector(
              onTap: () => setState(() => _revealed = !_revealed),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(_revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 22, color: kTextLight)),
            ),
            GestureDetector(
              onTap: widget.onCopy,
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.copy_rounded, size: 22, color: kTextLight)),
            ),
            GestureDetector(
              onTap: () => setState(() => _editing = true),
              child: const Padding(padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.edit_note_rounded, size: 22, color: kTextLight)),
            ),
          ]),
      ]),
    );
  }
}
