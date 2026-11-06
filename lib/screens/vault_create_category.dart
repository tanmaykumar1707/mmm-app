import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vault_provider.dart';
import '../models/vault_model.dart';
import '../utils/constants.dart';

class VaultCreateCategoryScreen extends StatefulWidget {
  final String personId;
  const VaultCreateCategoryScreen({super.key, required this.personId});
  @override
  State<VaultCreateCategoryScreen> createState() => _VaultCreateCategoryScreenState();
}

class _VaultCreateCategoryScreenState extends State<VaultCreateCategoryScreen> {
  final _nameCtrl = TextEditingController();
  String _icon = '📄';
  String _colorHex = '#4F46E5';
  final List<_FieldDraft> _fields = [];
  bool _saving = false;

  static const _icons = [
    '📄','🪪','📋','🚗','🛂','🏦','👷','⚡','🔥','🚙','💳','🏠','📱','💊','🎓','✈️','🔑','📞','🛡️','⚙️'
  ];
  static const _colors = [
    '#4F46E5','#0891B2','#059669','#7C3AED','#DB2777','#D97706','#CA8A04','#DC2626','#0D9488','#1D4ED8',
  ];

  Color get _accent {
    try { return Color(int.parse(_colorHex.replaceFirst('#', 'FF'), radix: 16)); }
    catch (_) { return kPrimary; }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final d in _fields) d.ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.read<VaultProvider>();
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        title: const Text('New Category', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: _accent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 13),
              ),
              onPressed: _saving ? null : () => _save(context, vp),
              child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            )),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Name
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Category name…',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.label_outline_rounded, color: kTextLight),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Icon picker
        _SectionLabel('Choose Icon'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Wrap(spacing: 8, runSpacing: 8, children: _icons.map((ic) => GestureDetector(
            onTap: () => setState(() => _icon = ic),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: ic == _icon ? _accent.withValues(alpha: 0.15) : kBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ic == _icon ? _accent : Colors.transparent, width: 2),
              ),
              child: Center(child: Text(ic, style: const TextStyle(fontSize: 20))),
            ),
          )).toList()),
        ),
        const SizedBox(height: 14),

        // Color picker
        _SectionLabel('Color'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Wrap(spacing: 10, runSpacing: 8, children: _colors.map((c) {
            final color = Color(int.parse(c.replaceFirst('#', 'FF'), radix: 16));
            return GestureDetector(
              onTap: () => setState(() => _colorHex = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle,
                  border: Border.all(color: c == _colorHex ? kTextDark : Colors.transparent, width: 2.5),
                ),
                child: c == _colorHex
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 20),

        // Fields builder
        Row(children: [
          _SectionLabel('Fields'),
          const Spacer(),
          GestureDetector(
            onTap: _addField,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('＋ Add Field', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _accent)),
            ),
          ),
        ]),
        const SizedBox(height: 8),

        if (_fields.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('No fields yet — tap "Add Field" to start',
              style: const TextStyle(fontSize: 11, color: kTextLight))),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx--;
                final item = _fields.removeAt(oldIdx);
                _fields.insert(newIdx, item);
              });
            },
            children: _fields.asMap().entries.map((en) => _FieldDraftCard(
              key: ValueKey(en.value.id),
              draft: en.value,
              color: _accent,
              onRemove: () => setState(() { en.value.ctrl.dispose(); _fields.removeAt(en.key); }),
              onChanged: () => setState(() {}),
            )).toList(),
          ),

        const SizedBox(height: 40),
      ]),
    );
  }

  void _addField() => setState(() => _fields.add(_FieldDraft()));

  Future<void> _save(BuildContext context, VaultProvider vp) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')));
      return;
    }
    setState(() => _saving = true);
    final fields = _fields.asMap().entries.map((en) {
      final d = en.value;
      return VaultField(
        id: genId(), label: d.ctrl.text.trim().isEmpty ? 'Field ${en.key + 1}' : d.ctrl.text.trim(),
        type: d.hidden ? VaultFieldType.hidden : d.type,
        isExpiryField: d.expiry,
        alerts: d.expiry ? [VaultAlert(id: genId(), daysBefore: d.alertDays)] : [],
        sortOrder: en.key,
      );
    }).toList();

    final cat = VaultCategory(
      id: genId(), personId: widget.personId,
      name: name, icon: _icon, colorHex: _colorHex,
      fields: fields,
    );
    await vp.saveCategory(cat);
    if (mounted) Navigator.pop(context);
  }
}

// ── Field draft ───────────────────────────────────────────────────────────────
class _FieldDraft {
  final String id = genId();
  final TextEditingController ctrl = TextEditingController();
  VaultFieldType type = VaultFieldType.text;
  bool hidden = false;
  bool expiry = false;
  int alertDays = 30;
}

class _FieldDraftCard extends StatefulWidget {
  final _FieldDraft draft;
  final Color color;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _FieldDraftCard({required super.key, required this.draft, required this.color,
    required this.onRemove, required this.onChanged});
  @override
  State<_FieldDraftCard> createState() => _FieldDraftCardState();
}

class _FieldDraftCardState extends State<_FieldDraftCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kTextLight.withValues(alpha: 0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Padding(padding: EdgeInsets.only(left: 10),
            child: Icon(Icons.drag_handle_rounded, size: 18, color: kTextLight)),
          Expanded(child: TextField(
            controller: widget.draft.ctrl,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Field label',
              hintStyle: TextStyle(fontSize: 11, color: kTextLight),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
          )),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(_expanded ? Icons.expand_less : Icons.tune_rounded, size: 16, color: kTextLight))),
          GestureDetector(
            onTap: widget.onRemove,
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.close_rounded, size: 16, color: kTextLight))),
        ]),
        if (_expanded) ...[
          const Divider(height: 1, indent: 12, endIndent: 12),
          Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Type
            Row(children: [
              const Text('Type: ', style: TextStyle(fontSize: 10, color: kTextLight)),
              ...VaultFieldType.values.map((t) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () { setState(() { widget.draft.type = t; widget.onChanged(); }); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.draft.type == t ? widget.color.withValues(alpha: 0.15) : kBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: widget.draft.type == t ? widget.color : kTextLight.withValues(alpha: 0.3)),
                    ),
                    child: Text(t.name, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                      color: widget.draft.type == t ? widget.color : kTextMid)),
                  ),
                ),
              )),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Text('Hidden: ', style: TextStyle(fontSize: 10, color: kTextLight)),
              Switch(
                value: widget.draft.hidden, activeColor: widget.color,
                onChanged: (v) { setState(() { widget.draft.hidden = v; widget.onChanged(); }); },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 10),
              const Text('Expiry/Reminder Alert: ', style: TextStyle(fontSize: 10, color: kTextLight)),
              Switch(
                value: widget.draft.expiry, activeColor: widget.color,
                onChanged: (v) { setState(() { widget.draft.expiry = v; widget.onChanged(); }); },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ]),
            if (widget.draft.expiry) ...[
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [30, 60, 90].map((d) => GestureDetector(
                onTap: () { setState(() { widget.draft.alertDays = d; widget.onChanged(); }); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.draft.alertDays == d ? widget.color.withValues(alpha: 0.15) : kBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: widget.draft.alertDays == d ? widget.color : kTextLight.withValues(alpha: 0.3)),
                  ),
                  child: Text('$d days', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                    color: widget.draft.alertDays == d ? widget.color : kTextMid)),
                ),
              )).toList()),
            ],
          ])),
        ],
      ]),
    );
  }
}

Widget _SectionLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
    letterSpacing: 0.6, color: kTextLight)),
);
