import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/vault_provider.dart';
import '../models/vault_model.dart';
import '../utils/constants.dart';

class VaultCategoryDetailScreen extends StatefulWidget {
  final VaultCategory cat;
  const VaultCategoryDetailScreen({super.key, required this.cat});
  @override
  State<VaultCategoryDetailScreen> createState() => _VaultCategoryDetailScreenState();
}

class _VaultCategoryDetailScreenState extends State<VaultCategoryDetailScreen> {
  final Set<String> _selected = {};
  bool _selectMode = false;
  final Map<String, bool> _revealed = {};
  bool _showNote = false;
  late VaultCategory _cat;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cat = widget.cat;
    _noteCtrl.text = _cat.note ?? '';
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onLongPress(String fieldId) {
    setState(() {
      _selectMode = true;
      _selected.add(fieldId);
    });
  }

  void _onTap(String fieldId) {
    if (_selectMode) {
      setState(() {
        if (_selected.contains(fieldId)) {
          _selected.remove(fieldId);
          if (_selected.isEmpty) _selectMode = false;
        } else {
          _selected.add(fieldId);
        }
      });
    }
  }

  void _cancelSelect() => setState(() { _selected.clear(); _selectMode = false; });

  void _shareSelected() {
    final lines = _cat.fields
        .where((f) => _selected.contains(f.id))
        .map((f) => '${f.label}: ${f.value ?? ''}')
        .join('\n');
    _share(lines);
    _cancelSelect();
  }

  void _shareCategory() {
    final lines = _cat.fields
        .map((f) => '${f.label}: ${f.value ?? ''}')
        .join('\n');
    _share('--- ${_cat.name} ---\n$lines');
  }

  void _share(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)));
  }

  void _copyField(VaultField f) {
    Clipboard.setData(ClipboardData(text: f.value ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${f.label} copied'), duration: const Duration(seconds: 1)));
  }

  Color get _color {
    try { return Color(int.parse(_cat.colorHex.replaceFirst('#', 'FF'), radix: 16)); }
    catch (_) { return kPrimary; }
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VaultProvider>();
    // Refresh cat from provider
    final updated = vp.categoriesForPerson(_cat.personId).where((c) => c.id == _cat.id).firstOrNull;
    if (updated != null) _cat = updated;

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(children: [
        CustomScrollView(slivers: [
          _buildAppBar(vp),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(delegate: SliverChildListDelegate([
              const SizedBox(height: 10),
              // Expiry warning
              if (_cat.nearestExpiryDays != null && _cat.nearestExpiryDays! <= 60)
                _ExpiryBanner(days: _cat.nearestExpiryDays!),

              // Category share button
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton.icon(
                  onPressed: _shareCategory,
                  icon: const Icon(Icons.ios_share_rounded, size: 15),
                  label: const Text('Share Category'),
                  style: TextButton.styleFrom(foregroundColor: _color, textStyle: const TextStyle(fontSize: 11)),
                ),
              ]),

              // Fields
              ...(_cat.fields.map((f) => _FieldCard(
                field: f,
                color: _color,
                isSelected: _selected.contains(f.id),
                selectMode: _selectMode,
                revealed: _revealed[f.id] ?? false,
                onLongPress: () => _onLongPress(f.id),
                onTap: () => _onTap(f.id),
                onReveal: () => setState(() => _revealed[f.id] = !(_revealed[f.id] ?? false)),
                onCopy: () => _copyField(f),
                onPin: (vp) => vp.pinField(_cat.id, f.id),
                vp: vp,
              ))),

              const SizedBox(height: 16),

              // Add field button
              OutlinedButton.icon(
                onPressed: () => _showAddField(context, vp),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Field'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _color,
                  side: BorderSide(color: _color.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 20),

              // Notes section
              GestureDetector(
                onTap: () => setState(() => _showNote = !_showNote),
                child: Row(children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 16, color: kTextLight),
                  const SizedBox(width: 6),
                  const Text('Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMid)),
                  const Spacer(),
                  Icon(_showNote ? Icons.expand_less : Icons.expand_more, size: 18, color: kTextLight),
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
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Write a private note…',
                      hintStyle: TextStyle(fontSize: 11, color: kTextLight),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _color, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11)),
                  onPressed: () => vp.updateCategoryNote(_cat.id, _noteCtrl.text),
                  child: const Text('Save Note'),
                )),
              ],
            ])),
          ),
        ]),

        // Floating share bar when in select mode
        if (_selectMode)
          Positioned(
            bottom: 24, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: kTextDark, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                Text('${_selected.length} selected', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _cancelSelect,
                  icon: const Icon(Icons.close_rounded, size: 15, color: Colors.white54),
                  label: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: _shareSelected,
                  icon: const Icon(Icons.ios_share_rounded, size: 14),
                  label: const Text('Share', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  SliverAppBar _buildAppBar(VaultProvider vp) => SliverAppBar(
    expandedHeight: 130,
    pinned: true,
    backgroundColor: _color,
    foregroundColor: Colors.white,
    flexibleSpace: FlexibleSpaceBar(
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_color, _color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
          child: Row(children: [
            Text(_cat.icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(_cat.name, style: const TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('${_cat.fieldCount} fields${_cat.isDefault ? ' · Default' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ])),
          ]),
        )),
      ),
    ),
    actions: [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: (v) {
          if (v == 'delete') {
            showDialog(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Delete Category?'),
              content: Text('Delete "${_cat.name}"? This cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kDanger),
                  onPressed: () { Navigator.pop(ctx); Navigator.pop(context); vp.deleteCategory(_cat.id); },
                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                ),
              ],
            ));
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'delete', child: Row(children: [
            Icon(Icons.delete_outline_rounded, color: kDanger, size: 16),
            SizedBox(width: 8), Text('Delete Category', style: TextStyle(color: kDanger)),
          ])),
        ],
      ),
    ],
  );

  Future<void> _showAddField(BuildContext context, VaultProvider vp) async {
    final labelCtrl = TextEditingController();
    VaultFieldType type = VaultFieldType.text;
    bool hidden = false;
    bool expiry = false;
    int alertDays = 30;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Field', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Field Label', hintText: 'e.g. Card Number')),
          const SizedBox(height: 10),
          DropdownButtonFormField<VaultFieldType>(
            value: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: VaultFieldType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
            onChanged: (v) => setSt(() => type = v!),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hidden (masked by default)', style: TextStyle(fontSize: 13)),
            value: hidden, activeColor: _color,
            onChanged: (v) => setSt(() => hidden = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Expiry Alert', style: TextStyle(fontSize: 13)),
            value: expiry, activeColor: _color,
            onChanged: (v) => setSt(() => expiry = v),
          ),
          if (expiry) ...[
            const Text('Alert days before expiry', style: TextStyle(fontSize: 11, color: kTextMid)),
            Wrap(spacing: 8, children: [30, 60, 90].map((d) => ChoiceChip(
              label: Text('$d days'),
              selected: alertDays == d,
              onSelected: (_) => setSt(() => alertDays = d),
              selectedColor: _color.withValues(alpha: 0.2),
            )).toList()),
          ],
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _color, foregroundColor: Colors.white),
            onPressed: () async {
              if (labelCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final field = VaultField(
                id: genId(), label: labelCtrl.text.trim(), type: hidden ? VaultFieldType.hidden : type,
                isExpiryField: expiry, alertDays: alertDays, sortOrder: _cat.fields.length);
              await vp.saveField(_cat.id, field);
            },
            child: const Text('Add Field'),
          )),
        ]),
      )),
    );
  }
}

// ── Field card ────────────────────────────────────────────────────────────────
class _FieldCard extends StatefulWidget {
  final VaultField field;
  final Color color;
  final bool isSelected;
  final bool selectMode;
  final bool revealed;
  final VoidCallback onLongPress;
  final VoidCallback onTap;
  final VoidCallback onReveal;
  final VoidCallback onCopy;
  final Function(VaultProvider) onPin;
  final VaultProvider vp;

  const _FieldCard({
    required this.field, required this.color, required this.isSelected,
    required this.selectMode, required this.revealed, required this.onLongPress,
    required this.onTap, required this.onReveal, required this.onCopy,
    required this.onPin, required this.vp,
  });

  @override
  State<_FieldCard> createState() => _FieldCardState();
}

class _FieldCardState extends State<_FieldCard> {
  late final TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.field.value ?? '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  bool get _isHidden => widget.field.type == VaultFieldType.hidden;

  String get _displayValue {
    final v = widget.field.value ?? '';
    if (v.isEmpty) return '—';
    if (_isHidden && !widget.revealed) return '•' * 8;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      onTap: widget.selectMode ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isSelected ? widget.color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isSelected ? widget.color : kTextLight.withValues(alpha: 0.15),
            width: widget.isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          if (widget.selectMode)
            Padding(padding: const EdgeInsets.only(right: 8),
              child: Icon(widget.isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: widget.isSelected ? widget.color : kTextLight, size: 20)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.field.label.toUpperCase(), style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: widget.color)),
            const SizedBox(height: 4),
            if (_editing)
              TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                obscureText: _isHidden,
                decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                onSubmitted: (v) async {
                  widget.field.value = v;
                  await widget.vp.saveField(
                    // VaultCategory id passed via vp — we save the field directly
                    widget.vp.categoriesForPerson(widget.vp.activePersonId ?? '').firstWhere((c) => c.fields.any((f) => f.id == widget.field.id)).id,
                    widget.field,
                  );
                  if (mounted) setState(() => _editing = false);
                },
              )
            else
              Text(_displayValue, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark),
                overflow: TextOverflow.ellipsis),
          ])),
          if (!widget.selectMode) ...[
            if (_isHidden)
              GestureDetector(
                onTap: widget.onReveal,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(widget.revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 18, color: kTextLight))),
            GestureDetector(
              onTap: widget.onCopy,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                child: const Icon(Icons.copy_rounded, size: 16, color: kTextLight))),
            GestureDetector(
              onTap: () => setState(() => _editing = !_editing),
              child: Padding(padding: const EdgeInsets.only(left: 6),
                child: Icon(_editing ? Icons.done_rounded : Icons.edit_rounded, size: 16, color: kTextLight))),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16, color: kTextLight),
              onSelected: (v) {
                if (v == 'pin') widget.onPin(widget.vp);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'pin', child: Row(children: [
                  Icon(Icons.push_pin_rounded, size: 14),
                  SizedBox(width: 6), Text('Pin to Quick Access', style: TextStyle(fontSize: 12)),
                ])),
              ],
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Expiry banner ─────────────────────────────────────────────────────────────
class _ExpiryBanner extends StatelessWidget {
  final int days;
  const _ExpiryBanner({required this.days});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: kWarn.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kWarn.withValues(alpha: 0.4)),
    ),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, size: 16, color: kWarn),
      const SizedBox(width: 8),
      Expanded(child: Text('Document expires in $days days',
        style: const TextStyle(fontSize: 11, color: kTextMid, fontWeight: FontWeight.w500))),
    ]),
  );
}
