import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vault_provider.dart';
import '../models/vault_model.dart';
import '../utils/constants.dart';
import 'vault_category_detail.dart';
import 'vault_bank_detail.dart';

class VaultAlertsScreen extends StatelessWidget {
  const VaultAlertsScreen({super.key});

  DateTime? _parseDate(String value) {
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

  Color _hexColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16)); }
    catch (_) { return kPrimary; }
  }

  String _fmtAlertTime(DateTime trigger) {
    final h = trigger.hour;
    final m = trigger.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${trigger.day} ${months[trigger.month - 1]} ${trigger.year} at $h12:$m $ampm';
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

    final items = <({String catName, String catIcon, Color color, VaultField field, VaultCategory cat})>[];
    for (final cat in cats) {
      final c = _hexColor(cat.colorHex);
      for (final f in cat.fields) {
        if (f.isExpiryField) items.add((catName: cat.name, catIcon: cat.icon, color: c, field: f, cat: cat));
      }
      for (final inst in cat.instances) {
        for (final f in inst.fields) {
          if (f.isExpiryField) items.add((catName: '${cat.name} — ${inst.bankName}', catIcon: cat.icon, color: c, field: f, cat: cat));
        }
      }
    }

    items.sort((a, b) {
      final da = a.field.daysUntilExpiry;
      final db = b.field.daysUntilExpiry;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Expiry / Reminder Alerts', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
      body: items.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.notifications_none_rounded, size: 56, color: kTextLight),
              const SizedBox(height: 12),
              const Text('No expiry/reminder alerts set', style: TextStyle(fontSize: 16, color: kTextMid)),
              const SizedBox(height: 6),
              const Text('Add fields with Expiry/Reminder Alert enabled', style: TextStyle(fontSize: 13, color: kTextLight)),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = items[i];
                final days = item.field.daysUntilExpiry;
                final expiry = item.field.value ?? '—';
                final expiryDate = _parseDate(expiry);

                Color statusColor = kPrimary;
                String statusLabel = '';
                if (days != null) {
                  if (days < 0) { statusColor = kDanger; statusLabel = 'Expired'; }
                  else if (days <= 7) { statusColor = kDanger; statusLabel = '$days days left'; }
                  else if (days <= 30) { statusColor = Colors.orange; statusLabel = '$days days left'; }
                  else { statusColor = Colors.green; statusLabel = '$days days left'; }
                }

                return GestureDetector(
                  onTap: () => _openCat(context, item.cat),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kTextLight.withValues(alpha: 0.15)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(item.catIcon, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.catName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark))),
                        if (statusLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6)),
                            child: Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w700)),
                          ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: kTextLight),
                      ]),
                      const SizedBox(height: 6),
                      Text(item.field.label.toUpperCase(),
                        style: TextStyle(fontSize: 11, letterSpacing: 0.5, color: item.color, fontWeight: FontWeight.w700)),
                      Text('Expires: $expiry', style: const TextStyle(fontSize: 14, color: kTextDark)),
                      if (item.field.alerts.isNotEmpty && expiryDate != null) ...[
                        const SizedBox(height: 6),
                        ...item.field.alerts.map((a) {
                          final trigger = a.triggerDate(expiryDate);
                          final isPast = trigger.isBefore(DateTime.now());
                          return Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(children: [
                              Icon(isPast ? Icons.notifications_off_outlined : Icons.notifications_active_rounded,
                                size: 14, color: isPast ? kTextLight : Colors.orange),
                              const SizedBox(width: 5),
                              Expanded(child: Text(
                                isPast
                                  ? 'Alert passed: ${_fmtAlertTime(trigger)}'
                                  : 'You will be alerted on ${_fmtAlertTime(trigger)}',
                                style: TextStyle(fontSize: 12,
                                  color: isPast ? kTextLight : kTextMid, fontWeight: FontWeight.w500),
                              )),
                            ]),
                          );
                        }),
                      ],
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
