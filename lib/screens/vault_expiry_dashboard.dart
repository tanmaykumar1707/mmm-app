import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vault_provider.dart';
import '../models/vault_model.dart';
import '../utils/constants.dart';
import 'vault_category_detail.dart';
import 'vault_bank_detail.dart';

typedef _ExpiryItem = ({
  String catName,
  String catIcon,
  String colorHex,
  VaultField field,
  VaultCategory cat,
  int? days,
});

class VaultExpiryDashboard extends StatefulWidget {
  const VaultExpiryDashboard({super.key});
  @override
  State<VaultExpiryDashboard> createState() => _VaultExpiryDashboardState();
}

class _VaultExpiryDashboardState extends State<VaultExpiryDashboard> {
  String _filter = 'all';

  List<_ExpiryItem> _buildItems(List<VaultCategory> cats) {
    final items = <_ExpiryItem>[];
    for (final cat in cats) {
      for (final f in cat.fields) {
        if (!f.isExpiryField) continue;
        items.add((catName: cat.name, catIcon: cat.icon, colorHex: cat.colorHex, field: f, cat: cat, days: f.daysUntilExpiry));
      }
      for (final inst in cat.instances) {
        for (final f in inst.fields) {
          if (!f.isExpiryField) continue;
          items.add((catName: '${cat.name} · ${inst.bankName}', catIcon: cat.icon, colorHex: cat.colorHex, field: f, cat: cat, days: f.daysUntilExpiry));
        }
        for (final card in inst.cards) {
          for (final f in card.fields) {
            if (!f.isExpiryField) continue;
            final type = card.cardType.name[0].toUpperCase() + card.cardType.name.substring(1);
            items.add((catName: '${inst.bankName} · $type Card', catIcon: cat.icon, colorHex: cat.colorHex, field: f, cat: cat, days: f.daysUntilExpiry));
          }
        }
      }
    }
    items.sort((a, b) {
      final da = a.days, db = b.days;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return items;
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
    final vp = context.watch<VaultProvider>();
    final person = vp.activePersonId;
    final cats = person != null ? vp.categoriesForPerson(person) : <VaultCategory>[];
    final all = _buildItems(cats);

    final expired = all.where((e) => e.days != null && e.days! < 0).toList();
    final soon    = all.where((e) => e.days != null && e.days! >= 0 && e.days! <= 60).toList();
    final ok      = all.where((e) => e.days == null || e.days! > 60).toList();

    final visible = switch (_filter) {
      'expired' => expired,
      'soon'    => soon,
      'ok'      => ok,
      _         => all,
    };

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Expiry / Renewal',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18)),
          Text('${all.length} field${all.length == 1 ? '' : 's'} tracked',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65))),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterChip(label: 'All', active: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Expired', active: _filter == 'expired',
                  onTap: () => setState(() => _filter = 'expired')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Expiring Soon', active: _filter == 'soon',
                  onTap: () => setState(() => _filter = 'soon')),
                const SizedBox(width: 8),
                _FilterChip(label: 'All Good', active: _filter == 'ok',
                  onTap: () => setState(() => _filter = 'ok')),
              ]),
            ),
          ),
        ),
      ),
      body: all.isEmpty
          ? const _EmptyState()
          : CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _SummaryRow(
                expiredCount: expired.length,
                soonCount: soon.length,
                okCount: ok.length,
                onTap: (f) => setState(() => _filter = f),
              )),
              if (visible.isEmpty)
                const SliverFillRemaining(child: Center(
                  child: Text('No items in this filter',
                    style: TextStyle(color: kTextLight, fontSize: 14)),
                ))
              else if (_filter == 'all') ...[
                if (expired.isNotEmpty) ...[
                  _sectionHeader('Expired'),
                  _CardSliver(items: expired, onTap: (cat) => _openCat(context, cat)),
                ],
                if (soon.isNotEmpty) ...[
                  _sectionHeader('Expiring Soon'),
                  _CardSliver(items: soon, onTap: (cat) => _openCat(context, cat)),
                ],
                if (ok.isNotEmpty) ...[
                  _sectionHeader('All Good'),
                  _CardSliver(items: ok, onTap: (cat) => _openCat(context, cat)),
                ],
              ] else
                _CardSliver(items: visible, onTap: (cat) => _openCat(context, cat)),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ]),
    );
  }

  SliverToBoxAdapter _sectionHeader(String title) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Text(title.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 0.7, color: kTextLight)),
    ),
  );
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: active ? kPrimary : Colors.white.withValues(alpha: 0.9),
      )),
    ),
  );
}

// ── Summary tiles row ─────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final int expiredCount, soonCount, okCount;
  final void Function(String) onTap;
  const _SummaryRow({required this.expiredCount, required this.soonCount,
    required this.okCount, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(children: [
      Expanded(child: _SummaryTile(count: expiredCount, label: 'Expired',
        color: kDanger, onTap: () => onTap('expired'))),
      const SizedBox(width: 10),
      Expanded(child: _SummaryTile(count: soonCount, label: 'Expiring Soon',
        color: kWarn, onTap: () => onTap('soon'))),
      const SizedBox(width: 10),
      Expanded(child: _SummaryTile(count: okCount, label: 'All Good',
        color: kAccent, onTap: () => onTap('ok'))),
    ]),
  );
}

class _SummaryTile extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SummaryTile({required this.count, required this.label,
    required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Text('$count', style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w800, color: color, height: 1)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700,
          letterSpacing: 0.5, color: kTextLight)),
      ]),
    ),
  );
}

// ── Card list sliver ──────────────────────────────────────────────────────────

class _CardSliver extends StatelessWidget {
  final List<_ExpiryItem> items;
  final void Function(VaultCategory) onTap;
  const _CardSliver({required this.items, required this.onTap});
  @override
  Widget build(BuildContext context) => SliverList(
    delegate: SliverChildBuilderDelegate(
      (ctx, i) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16,
          bottom: i == items.length - 1 ? 0 : 8),
        child: _ExpiryCard(item: items[i], onTap: () => onTap(items[i].cat)),
      ),
      childCount: items.length,
    ),
  );
}

// ── Individual expiry card ────────────────────────────────────────────────────

class _ExpiryCard extends StatelessWidget {
  final _ExpiryItem item;
  final VoidCallback onTap;
  const _ExpiryCard({required this.item, required this.onTap});

  Color get _urgencyColor {
    final d = item.days;
    if (d == null) return kPrimary;
    if (d < 0)    return kDanger;
    if (d <= 30)  return Colors.orange;
    if (d <= 60)  return kWarn;
    return kAccent;
  }

  String get _badgeLabel {
    final d = item.days;
    if (d == null) return 'No date';
    if (d < 0)    return 'Expired';
    if (d == 0)   return 'Today';
    return '$d days';
  }

  @override
  Widget build(BuildContext context) {
    final c = _urgencyColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: c,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Text(item.catIcon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.catName.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        letterSpacing: 0.5, color: kTextLight)),
                    Text(item.field.label,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: kTextDark)),
                    Text(
                      item.field.value?.isNotEmpty == true ? item.field.value! : '—',
                      style: const TextStyle(fontSize: 12, color: kTextMid),
                    ),
                  ],
                )),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_badgeLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
                ),
              ]),
            )),
          ]),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.event_available_rounded, size: 56, color: kTextLight),
      SizedBox(height: 12),
      Text('No expiry / renewal fields yet',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextMid)),
      SizedBox(height: 6),
      Text('Toggle "Expiry / Renewal" on a vault field\nto track it here',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: kTextLight)),
    ]),
  );
}
