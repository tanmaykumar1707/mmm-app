import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
  final _shareCatKey = GlobalKey();
  final _shareSelKey = GlobalKey();

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
    _share(lines, _shareSelKey);
    _cancelSelect();
  }

  void _shareCategory() {
    final lines = _cat.fields
        .map((f) => '${f.label}: ${f.value ?? ''}')
        .join('\n');
    _share('--- ${_cat.name} ---\n$lines', _shareCatKey);
  }

  void _share(String text, GlobalKey key) {
    HapticFeedback.lightImpact();
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    Share.share(withBranding(text), sharePositionOrigin: origin);
  }

  void _copyField(VaultField f) {
    HapticFeedback.lightImpact();
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
                  key: _shareCatKey,
                  onPressed: _shareCategory,
                  icon: const Icon(Icons.ios_share_rounded, size: 22),
                  label: const Text('Share'),
                  style: TextButton.styleFrom(foregroundColor: _color, textStyle: const TextStyle(fontSize: 16)),
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
                Text('${_selected.length} selected', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _cancelSelect,
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white54),
                  label: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 15)),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  key: _shareSelKey,
                  onPressed: _shareSelected,
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  label: const Text('Share', style: TextStyle(fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
    List<VaultAlert> alerts = [];
    final existingLabels = _cat.fields.map((f) => f.label.trim().toLowerCase()).toSet();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String? errorMsg;
        return StatefulBuilder(builder: (ctx, setSt) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Field', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: labelCtrl,
              onChanged: (_) => setSt(() => errorMsg = null),
              decoration: const InputDecoration(labelText: 'Field Label', hintText: 'e.g. Card Number'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<VaultFieldType>(
              value: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: VaultFieldType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
              onChanged: (v) => setSt(() { type = v!; errorMsg = null; }),
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
              title: const Text('Expiry/Reminder Alert', style: TextStyle(fontSize: 13)),
              value: expiry, activeColor: _color,
              onChanged: (v) => setSt(() {
                expiry = v;
                errorMsg = null;
                if (v && alerts.isEmpty) alerts = [VaultAlert(id: genId(), daysBefore: 30)];
                if (!v) alerts = [];
              }),
            ),
            if (expiry) ...[
              ...alerts.asMap().entries.map((entry) => _AlertRow(
                alert: entry.value,
                index: entry.key,
                color: _color,
                onRemove: alerts.length > 1 ? () => setSt(() => alerts.removeAt(entry.key)) : null,
                onChanged: (a) => setSt(() => alerts[entry.key] = a),
              )),
              if (alerts.length < 3)
                TextButton.icon(
                  onPressed: () => setSt(() => alerts.add(VaultAlert(id: genId(), daysBefore: 7))),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Another Alert', style: TextStyle(fontSize: 12)),
                ),
            ],
            // Inline error — always visible, never behind the sheet
            if (errorMsg != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: kDanger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kDanger.withValues(alpha: 0.3))),
                child: Text(errorMsg!, style: const TextStyle(fontSize: 13, color: kDanger, fontWeight: FontWeight.w500)),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _color, foregroundColor: Colors.white),
              onPressed: () async {
                final label = labelCtrl.text.trim();
                if (label.isEmpty) { setSt(() => errorMsg = 'Field label cannot be empty'); return; }
                if (existingLabels.contains(label.toLowerCase())) {
                  setSt(() => errorMsg = 'A field named "$label" already exists');
                  return;
                }
                if (expiry && type != VaultFieldType.date) {
                  setSt(() => errorMsg = 'Expiry/Reminder alert requires Date type — change Type to "date"');
                  return;
                }
                HapticFeedback.lightImpact();
                Navigator.pop(ctx);
                final field = VaultField(
                  id: genId(), label: label, type: hidden ? VaultFieldType.hidden : type,
                  isExpiryField: expiry, alerts: alerts, sortOrder: _cat.fields.length);
                await vp.saveField(_cat.id, field);
              },
              child: const Text('Add Field'),
            )),
          ]),
        ));
      },
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

  Future<void> _saveField() async {
    HapticFeedback.lightImpact();
    widget.field.value = _ctrl.text;
    final cats = widget.vp.categoriesForPerson(widget.vp.activePersonId ?? '');
    final catId = cats.firstWhere((c) => c.fields.any((f) => f.id == widget.field.id)).id;
    await widget.vp.saveField(catId, widget.field);
    if (mounted) setState(() => _editing = false);
  }

  static TextInputType _keyboardType(VaultFieldType t) => switch (t) {
    VaultFieldType.number => TextInputType.number,
    VaultFieldType.date   => TextInputType.datetime,
    _                     => TextInputType.text,
  };

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
            Row(children: [
              Expanded(child: Text(widget.field.label.toUpperCase(), style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: widget.color))),
              if (widget.field.isExpiryField)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: 'Expiry/Reminder Alert set',
                    child: Icon(Icons.notifications_active_rounded, size: 14, color: Colors.orange.shade600),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            if (_editing)
              widget.field.type == VaultFieldType.date
                ? GestureDetector(
                    onTap: () async {
                      DateTime initial = DateTime.now();
                      if (_ctrl.text.isNotEmpty) {
                        final parts = _ctrl.text.split('/');
                        try {
                          if (parts.length == 3) initial = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                        } catch (_) {}
                      }
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        final formatted = '${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}';
                        _ctrl.text = formatted;
                        widget.field.value = formatted;
                        final catId = widget.vp.categoriesForPerson(widget.vp.activePersonId ?? '')
                            .firstWhere((c) => c.fields.any((f) => f.id == widget.field.id)).id;
                        await widget.vp.saveField(catId, widget.field);
                        if (mounted) setState(() => _editing = false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: widget.color.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Row(children: [
                        Expanded(child: Text(_ctrl.text.isEmpty ? 'Tap to pick date' : _ctrl.text,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                            color: _ctrl.text.isEmpty ? kTextLight : kTextDark))),
                        Icon(Icons.calendar_today_rounded, size: 20, color: widget.color),
                      ]),
                    ),
                  )
                : TextField(
                    controller: _ctrl,
                    autofocus: true,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kTextDark),
                    obscureText: _isHidden,
                    keyboardType: _keyboardType(widget.field.type),
                    inputFormatters: widget.field.type == VaultFieldType.number
                        ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                        : null,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: widget.color.withValues(alpha: 0.4))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: widget.color.withValues(alpha: 0.4))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: widget.color, width: 1.5)),
                      filled: true, fillColor: Colors.white,
                    ),
                    onSubmitted: (_) => _saveField(),
                  )
            else ...[
              Text(_displayValue, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kTextDark),
                overflow: TextOverflow.ellipsis),
              if (widget.field.isExpiryField && widget.field.alerts.isNotEmpty && widget.field.value != null && widget.field.value!.isNotEmpty) ...[
                const SizedBox(height: 4),
                _AlertPreview(field: widget.field),
              ],
            ],
          ])),
          if (!widget.selectMode) ...[
            if (_isHidden)
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); widget.onReveal(); },
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(widget.revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 26, color: kTextLight))),
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); widget.onCopy(); },
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                child: const Icon(Icons.copy_rounded, size: 24, color: kTextLight))),
            GestureDetector(
              onTap: _editing ? _saveField : () => setState(() => _editing = true),
              child: Padding(padding: const EdgeInsets.only(left: 6),
                child: Icon(_editing ? Icons.done_rounded : Icons.edit_rounded,
                  size: 24, color: _editing ? widget.color : kTextLight))),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 24, color: kTextLight),
              onSelected: (v) async {
                if (v == 'pin') widget.onPin(widget.vp);
                if (v == 'alerts') _showManageAlerts(context);
                if (v == 'delete') {
                  HapticFeedback.mediumImpact();
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Field?'),
                      content: Text('Delete "${widget.field.label}"? This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    final catId = widget.vp.categoriesForPerson(widget.vp.activePersonId ?? '')
                        .firstWhere((c) => c.fields.any((f) => f.id == widget.field.id)).id;
                    await widget.vp.deleteField(catId, widget.field.id);
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'pin', child: Row(children: [
                  Icon(Icons.push_pin_rounded, size: 18),
                  SizedBox(width: 6), Text('Pin to Quick Access', style: TextStyle(fontSize: 15)),
                ])),
                if (widget.field.isExpiryField)
                  const PopupMenuItem(value: 'alerts', child: Row(children: [
                    Icon(Icons.notifications_outlined, size: 18),
                    SizedBox(width: 6), Text('Manage Alerts', style: TextStyle(fontSize: 15)),
                  ])),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: kDanger),
                  SizedBox(width: 6), Text('Delete Field', style: TextStyle(fontSize: 15, color: kDanger)),
                ])),
              ],
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _showManageAlerts(BuildContext context) async {
    final catId = widget.vp.categoriesForPerson(widget.vp.activePersonId ?? '')
        .firstWhere((c) => c.fields.any((f) => f.id == widget.field.id)).id;
    List<VaultAlert> alerts = List.from(widget.field.alerts);
    if (alerts.isEmpty) alerts = [VaultAlert(id: genId(), daysBefore: 30)];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Alerts for ${widget.field.label}',
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (widget.field.value != null && widget.field.value!.isNotEmpty)
            Text('Expiry: ${widget.field.value}', style: const TextStyle(fontSize: 12, color: kTextMid)),
          const SizedBox(height: 14),
          ...alerts.asMap().entries.map((entry) => _AlertRow(
            alert: entry.value,
            index: entry.key,
            color: widget.color,
            onRemove: alerts.length > 1 ? () => setSt(() => alerts.removeAt(entry.key)) : null,
            onChanged: (a) => setSt(() => alerts[entry.key] = a),
          )),
          if (alerts.length < 3)
            TextButton.icon(
              onPressed: () => setSt(() => alerts.add(VaultAlert(id: genId(), daysBefore: 7))),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Alert', style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.color, foregroundColor: Colors.white),
            onPressed: () async {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx);
              await widget.vp.saveFieldAlerts(catId, widget.field.id, alerts);
            },
            child: const Text('Save Alerts'),
          )),
        ]),
      )),
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

// ── Alert row (for add/manage alert sheets) ───────────────────────────────────
class _AlertRow extends StatefulWidget {
  final VaultAlert alert;
  final int index;
  final Color color;
  final VoidCallback? onRemove;
  final ValueChanged<VaultAlert> onChanged;

  const _AlertRow({required this.alert, required this.index, required this.color,
    this.onRemove, required this.onChanged});

  @override
  State<_AlertRow> createState() => _AlertRowState();
}

class _AlertRowState extends State<_AlertRow> {
  late TextEditingController _daysCtrl;

  @override
  void initState() {
    super.initState();
    _daysCtrl = TextEditingController(text: widget.alert.daysBefore.toString());
  }

  @override
  void dispose() { _daysCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text('Alert ${widget.index + 1}:', style: const TextStyle(fontSize: 13, color: kTextMid, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: TextField(
            controller: _daysCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'Days',
              suffixText: 'd',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              final days = int.tryParse(v) ?? widget.alert.daysBefore;
              widget.onChanged(VaultAlert(id: widget.alert.id, daysBefore: days, hour: widget.alert.hour, minute: widget.alert.minute));
            },
          ),
        ),
        const SizedBox(width: 8),
        const Text('days before at', style: TextStyle(fontSize: 12, color: kTextMid)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: widget.alert.hour, minute: widget.alert.minute),
              // Fix Android BoxConstraints error when switching to keyboard input mode
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                child: child!,
              ),
            );
            if (picked != null) {
              widget.onChanged(VaultAlert(id: widget.alert.id, daysBefore: widget.alert.daysBefore, hour: picked.hour, minute: picked.minute));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: widget.color.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(widget.alert.timeLabel, style: TextStyle(fontSize: 13, color: widget.color, fontWeight: FontWeight.w600)),
          ),
        ),
        const Spacer(),
        if (widget.onRemove != null)
          GestureDetector(
            onTap: widget.onRemove,
            child: const Icon(Icons.close_rounded, size: 18, color: kDanger),
          ),
      ]),
    );
  }
}

// ── Alert preview (shows next alert dates on a field card) ────────────────────
class _AlertPreview extends StatelessWidget {
  final VaultField field;
  const _AlertPreview({required this.field});

  DateTime? _parseExpiry(String value) {
    try {
      final parts = value.split('/');
      if (parts.length == 2) {
        final m = int.parse(parts[0]);
        final y = int.parse(parts[1]);
        return DateTime(y < 100 ? 2000 + y : y, m + 1, 0);
      } else if (parts.length == 3) {
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  String _fmtAlertTime(DateTime trigger) {
    final h = trigger.hour;
    final m = trigger.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${trigger.day} ${months[trigger.month - 1]} ${trigger.year} at $h12:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final expiry = _parseExpiry(field.value ?? '');
    if (expiry == null) return const SizedBox.shrink();
    final rows = field.alerts.map((a) {
      final trigger = a.triggerDate(expiry);
      final isPast = trigger.isBefore(DateTime.now());
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          Icon(isPast ? Icons.notifications_off_outlined : Icons.notifications_active_rounded,
            size: 13, color: isPast ? kTextLight : Colors.orange),
          const SizedBox(width: 5),
          Expanded(child: Text(
            isPast
              ? 'Alert passed: ${_fmtAlertTime(trigger)}'
              : 'You will be alerted on ${_fmtAlertTime(trigger)}',
            style: TextStyle(fontSize: 11, color: isPast ? kTextLight : kTextMid, fontWeight: FontWeight.w500),
          )),
        ]),
      );
    }).whereType<Widget>().toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}
