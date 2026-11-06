import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/vault_provider.dart';
import '../models/vault_model.dart';
import '../utils/constants.dart';
import 'vault_setup_screen.dart';
import 'vault_category_detail.dart';
import 'vault_bank_detail.dart';
import 'vault_create_category.dart';
import 'vault_alerts_screen.dart';

class VaultTab extends StatefulWidget {
  const VaultTab({super.key});
  @override
  State<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends State<VaultTab> {
  String _search = '';
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedCats = {};
  bool _catSelectMode = false;
  final _shareKey = GlobalKey();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _enterCatSelect(String catId) {
    setState(() { _catSelectMode = true; _selectedCats.add(catId); });
  }

  void _toggleCatSelect(String catId) {
    setState(() {
      if (_selectedCats.contains(catId)) {
        _selectedCats.remove(catId);
        if (_selectedCats.isEmpty) _catSelectMode = false;
      } else {
        _selectedCats.add(catId);
      }
    });
  }

  void _cancelCatSelect() => setState(() { _selectedCats.clear(); _catSelectMode = false; });

  void _shareCats(VaultProvider vp) {
    final activePerson = vp.activePersonId;
    if (activePerson == null) return;
    final cats = vp.categoriesForPerson(activePerson).where((c) => _selectedCats.contains(c.id));
    final lines = cats.map((cat) {
      final fieldLines = cat.fields.map((f) => '  ${f.label}: ${f.value ?? ''}').join('\n');
      return '--- ${cat.name} ---\n$fieldLines';
    }).join('\n\n');
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    Share.share(withBranding(lines.isEmpty ? '(no fields)' : lines), sharePositionOrigin: origin);
    _cancelCatSelect();
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VaultProvider>();

    if (vp.status == VaultStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vp.status == VaultStatus.needsSetup) {
      return const VaultSetupScreen(isNewSetup: true);
    }
    if (vp.status == VaultStatus.needsToken) {
      return const VaultSetupScreen(isNewSetup: false);
    }

    final activePerson = vp.activePersonId;
    final allCats = activePerson != null ? vp.categoriesForPerson(activePerson) : <VaultCategory>[];
    final allFolders = vp.folders.where((f) => f.personId == activePerson).toList();

    // Search filter
    final query = _search.trim().toLowerCase();
    final filtered = query.isEmpty
        ? allCats
        : allCats.where((cat) {
            if (cat.name.toLowerCase().contains(query)) return true;
            for (final f in cat.fields) {
              if (f.label.toLowerCase().contains(query)) return true;
              if ((f.value ?? '').toLowerCase().contains(query)) return true;
            }
            return false;
          }).toList();

    // Exclude categories that are inside a folder from the main lists
    final defaults = filtered.where((c) => c.isDefault && c.folderId == null).toList();
    final custom = filtered.where((c) => !c.isDefault && c.folderId == null).toList();
    final pinned = vp.pinnedFields;

    return Stack(children: [
      Column(children: [
      _buildHeader(vp),
      _buildPersonPills(vp),
      _buildSearchBar(),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 80), children: [
        // Quick access
        if (pinned.isNotEmpty && query.isEmpty) ...[
          _sectionHead('⚡ Quick Access', hint: 'Long-press field to pin'),
          _buildQuickAccess(pinned, vp),
        ],

        // Default categories
        if (defaults.isNotEmpty) ...[
          _sectionHead('Default Categories'),
          // Bank card (full width, special)
          ...defaults.where((c) => c.isMultiInstance).map((cat) => _BankCard(cat: cat, onTap: () => _openCat(context, cat))),
          // 2-col grid for the rest
          _buildGrid(defaults.where((c) => !c.isMultiInstance).toList(), context),
        ],

        // Folders
        if (allFolders.isNotEmpty && query.isEmpty) ...[
          _sectionHead('📁 Folders', onAdd: () => _createFolder(context, vp, activePerson!)),
          ...allFolders.map((folder) => _FolderCard(
            folder: folder, allCats: allCats, vp: vp,
            onTap: () {},
          )),
        ] else if (query.isEmpty)
          _sectionHead('📁 Folders', onAdd: () => _createFolder(context, vp, activePerson!)),

        // My categories
        _sectionHead('My Categories', onAdd: () => _createCategory(context, vp, activePerson!)),
        if (custom.isNotEmpty)
          _buildGrid(custom, context)
        else if (query.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('No custom categories yet',
              style: TextStyle(color: kTextLight, fontSize: 13))),
          ),
      ])),
      ]),
      // Floating share bar when categories are selected
      if (_catSelectMode)
        Positioned(
          bottom: 24, left: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kTextDark, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Row(children: [
              Text('${_selectedCats.length} selected', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
              const Spacer(),
              TextButton.icon(
                onPressed: _cancelCatSelect,
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                label: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                key: _shareKey,
                onPressed: () => _shareCats(vp),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Share', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(VaultProvider vp) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [kPrimary, Color(0xFF7C3AED)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('My Vault 🔐', style: TextStyle(
              fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('Viewing: ${vp.persons.where((p) => p.id == vp.activePersonId).firstOrNull?.name ?? "Me"} · ${vp.persons.length} members',
              style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ])),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(Icons.lock_rounded, size: 11, color: Colors.white),
                SizedBox(width: 4),
                Text('Secured', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultAlertsScreen())),
              tooltip: 'Expiry/Reminder Alerts',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
              onSelected: (v) { if (v == 'wipe') _confirmWipeVault(context, vp); },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'wipe', child: Row(children: [
                  Icon(Icons.delete_forever_rounded, color: kDanger, size: 18),
                  SizedBox(width: 10),
                  Text('Delete My Vault', style: TextStyle(color: kDanger, fontWeight: FontWeight.w600)),
                ])),
              ],
            ),
          ]),
        ]),
      ]),
    );
  }

  // ── Person pills ───────────────────────────────────────────────────────────
  Widget _buildPersonPills(VaultProvider vp) => Container(
    color: kBg,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        ...vp.persons.map((p) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => vp.setActivePerson(p.id),
            onLongPress: p.isDefault ? null : () => _confirmDeletePerson(context, vp, p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: vp.activePersonId == p.id ? kPrimary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: vp.activePersonId == p.id ? kPrimary : kTextLight.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 18, height: 18, decoration: BoxDecoration(
                    color: vp.activePersonId == p.id
                        ? Colors.white.withValues(alpha: 0.3)
                        : _hexColor(p.colorHex),
                    shape: BoxShape.circle),
                  child: Center(child: Text(p.initial, style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w800,
                    color: vp.activePersonId == p.id ? Colors.white : Colors.white))),
                ),
                const SizedBox(width: 5),
                Text(p.name, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: vp.activePersonId == p.id ? Colors.white : kTextMid)),
              ]),
            ),
          ),
        )),
        // Add person pill
        GestureDetector(
          onTap: () => _addPerson(context, vp),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: kTextLight.withValues(alpha: 0.3), style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('＋', style: TextStyle(fontSize: 12, color: kTextLight)),
              const SizedBox(width: 3),
              const Text('Add', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: kTextLight)),
            ]),
          ),
        ),
      ]),
    ),
  );

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
    child: TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _search = v),
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: 'Search Aadhaar, PAN, account no…',
        hintStyle: const TextStyle(fontSize: 11, color: kTextLight),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kTextLight),
        suffixIcon: _search.isNotEmpty
            ? IconButton(icon: const Icon(Icons.close_rounded, size: 16), onPressed: () {
                _searchCtrl.clear(); setState(() => _search = '');
              })
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kTextLight.withValues(alpha: 0.3))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kTextLight.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary)),
        filled: true, fillColor: Colors.white,
      ),
    ),
  );

  // ── Quick access ───────────────────────────────────────────────────────────
  Widget _buildQuickAccess(List<({VaultCategory cat, VaultField field, String? instanceId})> pinned, VaultProvider vp) {
    return SizedBox(
      height: 90,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        ...pinned.map((p) {
          final color = _hexColor(p.cat.colorHex);
          final display = p.field.type == VaultFieldType.hidden
              ? '${(p.field.value ?? '').isNotEmpty ? ('•' * 4 + ' ' + (p.field.value!.length > 4 ? p.field.value!.substring(p.field.value!.length - 4) : p.field.value!)) : '—'}'
              : (p.field.value ?? '—');
          return GestureDetector(
            onLongPress: () => vp.unpinField(vp.pinnedRefs.firstWhere(
              (r) => r.fieldId == p.field.id).id),
            child: Container(
              width: 120, margin: const EdgeInsets.only(right: 8, bottom: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
                border: Border(top: BorderSide(color: color, width: 3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.field.label.toUpperCase(), style: TextStyle(
                  fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: color)),
                const SizedBox(height: 4),
                Text(display, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextDark),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${p.cat.name} · Tap to copy', style: const TextStyle(fontSize: 7, color: kTextLight)),
              ]),
            ),
          );
        }),
        Container(
          width: 80, margin: const EdgeInsets.only(right: 8, bottom: 4),
          decoration: BoxDecoration(
            border: Border.all(color: kTextLight.withValues(alpha: 0.3), style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.push_pin_outlined, size: 20, color: kTextLight),
            SizedBox(height: 4),
            Text('Pin field', style: TextStyle(fontSize: 9, color: kTextLight)),
          ]),
        ),
      ]),
    );
  }

  // ── 2-col grid ─────────────────────────────────────────────────────────────
  Widget _buildGrid(List<VaultCategory> cats, BuildContext context) {
    if (cats.isEmpty) return const SizedBox();
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.4),
      itemCount: cats.length,
      itemBuilder: (_, i) => _CatCard(
        cat: cats[i],
        onTap: () {
          if (_catSelectMode) {
            _toggleCatSelect(cats[i].id);
          } else {
            _openCat(context, cats[i]);
          }
        },
        onLongPress: () => _enterCatSelect(cats[i].id),
        isSelected: _selectedCats.contains(cats[i].id),
        selectMode: _catSelectMode,
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionHead(String title, {String? hint, VoidCallback? onAdd}) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
    child: Row(children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
        letterSpacing: 0.5, color: kTextLight)),
      if (hint != null) ...[
        const SizedBox(width: 6),
        Text(hint, style: const TextStyle(fontSize: 11, color: kTextLight)),
      ],
      const Spacer(),
      if (onAdd != null)
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: const Text('＋ Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPrimary)),
          ),
        ),
    ]),
  );

  Future<void> _confirmDeletePerson(BuildContext context, VaultProvider vp, VaultPerson person) async {
    final cats = vp.categoriesForPerson(person.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${person.name}"?'),
        content: Text(
          'This will permanently delete ${person.name} and all their vault data '
          '(${cats.length} categories). This cannot be undone.'),
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
    if (confirmed == true) await vp.deletePerson(person.id);
  }

  Future<void> _confirmWipeVault(BuildContext context, VaultProvider vp) async {
    // Two-step confirmation for destructive action
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete My Vault?'),
        content: const Text(
          'This will:\n'
          '• Delete ALL vault data for ALL persons from Firebase\n'
          '• Remove your security token from this device\n'
          '• Require you to set up the vault again from scratch\n\n'
          'This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (step1 != true || !context.mounted) return;

    // Second confirmation
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDanger.withValues(alpha: 0.05),
        title: const Row(children: [
          Icon(Icons.warning_rounded, color: kDanger),
          SizedBox(width: 8),
          Text('Are you sure?', style: TextStyle(color: kDanger)),
        ]),
        content: const Text('All vault data will be permanently erased. There is no way to recover it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Delete Everything'),
          ),
        ],
      ),
    );
    if (step2 == true) await vp.wipeVault();
  }

  void _openCat(BuildContext context, VaultCategory cat) {
    if (cat.isMultiInstance) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VaultBankDetailScreen(cat: cat)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VaultCategoryDetailScreen(cat: cat)));
    }
  }

  void _createCategory(BuildContext context, VaultProvider vp, String personId) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => VaultCreateCategoryScreen(personId: personId)));
  }

  Future<void> _createFolder(BuildContext context, VaultProvider vp, String personId) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Folder name')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Create')),
          ],
        );
      });
    if (name != null && name.isNotEmpty) {
      final folder = VaultFolder(id: genId(), personId: personId, name: name);
      await vp.saveFolder(folder);
    }
  }

  Future<void> _addPerson(BuildContext context, VaultProvider vp) async {
    final colors = ['#4F46E5', '#DB2777', '#059669', '#D97706', '#0891B2', '#7C3AED'];
    String selectedColor = colors[0];
    final ctrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Person', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name (e.g. Wife, Father, Mother)')),
          const SizedBox(height: 14),
          const Text('Color', style: TextStyle(fontSize: 12, color: kTextMid)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, children: colors.map((c) => GestureDetector(
            onTap: () => setSt(() => selectedColor = c),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _hexColor(c), shape: BoxShape.circle,
                border: Border.all(color: selectedColor == c ? kTextDark : Colors.transparent, width: 2.5),
              ),
            ),
          )).toList()),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                await vp.addPerson(ctrl.text.trim(), selectedColor);
              }
            },
            child: const Text('Add'),
          )),
        ]),
      )),
    );
  }

  static Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return kPrimary;
    }
  }
}

// ── Category card ─────────────────────────────────────────────────────────────
class _CatCard extends StatelessWidget {
  final VaultCategory cat;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool selectMode;
  const _CatCard({
    required this.cat,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.selectMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(cat.colorHex);
    final expiry = cat.nearestExpiryDays;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected ? [] : [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
          border: isSelected
              ? Border.all(color: color, width: 2)
              : (expiry != null && expiry <= 60 ? Border.all(color: kWarn.withValues(alpha: 0.5)) : null),
        ),
        child: Stack(children: [
          Positioned(top: 0, left: 0, right: 0, child: Container(height: 3,
            decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(14))))),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 14, 11, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(cat.icon, style: const TextStyle(fontSize: 20)))),
              const SizedBox(height: 7),
              Text(cat.name, style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700, color: kTextDark),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(expiry != null && expiry <= 60
                  ? 'Expires in ${expiry}d'
                  : '${cat.fieldCount} fields',
                style: TextStyle(fontSize: 12, color: expiry != null && expiry <= 60 ? kWarn : kTextLight,
                  fontWeight: expiry != null && expiry <= 60 ? FontWeight.w600 : FontWeight.w400)),
            ]),
          ),
          // Selection indicator
          if (selectMode)
            Positioned(top: 8, left: 8, child: Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 20, color: isSelected ? color : kTextLight)),
          if (!selectMode && cat.isDefault && (expiry == null || expiry > 60))
            Positioned(top: 10, right: 8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(5)),
              child: const Text('DEFAULT', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: kTextLight)),
            )),
          if (expiry != null && expiry <= 60)
            Positioned(top: 10, right: 8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: kWarn.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5)),
              child: Text('⚠ ${expiry}d', style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: kWarn)),
            )),
          // Drag handle — tap-and-drag this icon to drop into a folder
          if (!selectMode)
            Positioned(bottom: 6, right: 6,
              child: Draggable<VaultCategory>(
                data: cat,
                feedback: Material(
                  color: Colors.transparent,
                  child: Opacity(opacity: 0.85, child: Container(
                    width: 150, height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12)],
                      border: Border(top: BorderSide(color: color, width: 3)),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cat.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(cat.name, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  )),
                ),
                childWhenDragging: const Icon(Icons.drag_indicator_rounded, size: 24, color: kPrimary),
                child: const Icon(Icons.drag_indicator_rounded, size: 24, color: kTextLight),
              )),
        ]),
      ),
    );
  }
  static Color _hexColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16)); } catch (_) { return kPrimary; }
  }
}

// ── Bank card (full width) ────────────────────────────────────────────────────
class _BankCard extends StatelessWidget {
  final VaultCategory cat;
  final VoidCallback onTap;
  const _BankCard({required this.cat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1e1b4b), Color(0xFF312e81)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('🏦', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bank Accounts', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('${cat.instances.length} bank${cat.instances.length != 1 ? 's' : ''} · AC, Debit & Credit cards',
                style: const TextStyle(fontSize: 9, color: Colors.white60)),
            ])),
            // Bank initials stacked
            SizedBox(
              width: 60, height: 24,
              child: Stack(children: [
                ...cat.instances.take(3).toList().asMap().entries.map((en) {
                  final colors = [const Color(0xFF1D4ED8), const Color(0xFF15803D), const Color(0xFFB45309)];
                  final initial = en.value.bankName.isNotEmpty ? en.value.bankName[0].toUpperCase() : '?';
                  return Positioned(
                    left: en.key * 14.0,
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: colors[en.key % colors.length], shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF312e81), width: 1.5)),
                      child: Center(child: Text(initial, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white))),
                    ),
                  );
                }),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 4, children: [
            ...cat.instances.map((i) => _chip(i.bankName)),
            _chip('＋ Add bank', dashed: true),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(String label, {bool dashed = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: dashed ? Colors.transparent : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(7),
      border: dashed ? Border.all(color: Colors.white.withValues(alpha: 0.3)) : null,
    ),
    child: Text(label, style: TextStyle(fontSize: 9, color: dashed ? Colors.white54 : Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500)),
  );
}

// ── Folder card ───────────────────────────────────────────────────────────────
class _FolderCard extends StatefulWidget {
  final VaultFolder folder;
  final List<VaultCategory> allCats;
  final VaultProvider vp;
  final VoidCallback onTap;
  const _FolderCard({required this.folder, required this.allCats, required this.vp, required this.onTap});

  @override
  State<_FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<_FolderCard> {
  bool _expanded = false;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete folder "${widget.folder.name}"?'),
        content: const Text('Categories inside will be moved back to the main list.'),
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
    if (ok == true) await widget.vp.deleteFolder(widget.folder.id);
  }

  void _openCat(BuildContext context, VaultCategory cat) {
    if (cat.isMultiInstance) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VaultBankDetailScreen(cat: cat)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VaultCategoryDetailScreen(cat: cat)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.allCats.where((c) => widget.folder.categoryIds.contains(c.id)).toList();
    return DragTarget<VaultCategory>(
      onAcceptWithDetails: (details) => widget.vp.moveCategoryToFolder(details.data.id, widget.folder.id),
      builder: (ctx, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty ? kPrimary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: candidates.isNotEmpty ? kPrimary : kPrimary.withValues(alpha: 0.2),
            width: candidates.isNotEmpty ? 2 : 1.5,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Folder header — tap to expand/collapse
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(children: [
              const Text('📁', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.folder.name,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700))),
              Text('${cats.length} categories', style: const TextStyle(fontSize: 12, color: kTextLight)),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 20, color: kTextLight),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: const Icon(Icons.delete_outline_rounded, size: 20, color: kDanger),
              ),
            ]),
          ),
          // Collapsed: show category chips as preview
          if (!_expanded && cats.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 5, runSpacing: 4, children: cats.map((c) => GestureDetector(
              onTap: () => _openCat(context, c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: kTextLight.withValues(alpha: 0.2))),
                child: Text('${c.icon} ${c.name}', style: const TextStyle(fontSize: 12, color: kTextMid, fontWeight: FontWeight.w500)),
              ),
            )).toList()),
          ],
          // Expanded: show full category list with open arrows
          if (_expanded) ...[
            const SizedBox(height: 8),
            if (cats.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 4),
                child: Text(candidates.isNotEmpty ? 'Drop category here' : 'Drag categories here',
                  style: TextStyle(fontSize: 12, color: candidates.isNotEmpty ? kPrimary : kTextLight)))
            else
              ...cats.map((c) => GestureDetector(
                onTap: () => _openCat(context, c),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: kBg, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kTextLight.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    Text(c.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
                      Text(c.fieldCount == 0 ? 'No fields' : '${c.fieldCount} fields',
                        style: const TextStyle(fontSize: 11, color: kTextLight)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: kTextLight),
                  ]),
                ),
              )),
          ],
          // Drop target hint when dragging
          if (candidates.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8),
              child: Text('Drop to add to folder', style: TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}
