import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/state_provider.dart';
import '../utils/constants.dart';

class ShareAccessScreen extends StatefulWidget {
  const ShareAccessScreen({super.key});
  @override
  State<ShareAccessScreen> createState() => _ShareAccessScreenState();
}

class _ShareAccessScreenState extends State<ShareAccessScreen> {
  final _emailCtrl = TextEditingController();
  List<Map<String, dynamic>> _grantees = [];
  bool _loading = true;
  bool _submitting = false;

  static const _modules = [
    {'key': 'expenses', 'label': 'Month Expenses', 'icon': Icons.calendar_today_rounded},
    {'key': 'cards',    'label': 'Credit Cards',   'icon': Icons.credit_card_rounded},
    {'key': 'lb',       'label': 'LB (Lendings)',  'icon': Icons.handshake_rounded},
    {'key': 'bills',    'label': 'Recurring Bills', 'icon': Icons.receipt_long_rounded},
  ];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final sp = context.read<StateProvider>();
    if (sp.myUid == null) return;
    final list = await FirebaseService.getGrantedAccesses(sp.myUid!);
    setState(() { _grantees = list; _loading = false; });
  }

  Future<void> _pickModulesAndGrant() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    // Show module picker sheet
    final permissions = await showModalBottomSheet<Map<String, bool>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModulePickerSheet(email: email),
    );
    if (permissions == null || !mounted) return;
    if (!permissions.values.any((v) => v)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one module to share')));
      return;
    }

    final sp = context.read<StateProvider>();
    if (sp.myUid == null) return;
    setState(() => _submitting = true);
    try {
      await FirebaseService.grantAccess(sp.myUid!, email, permissions);
      _emailCtrl.clear();
      await sp.loadSharedWorkspaces();
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access granted to $email'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.read<StateProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Access Sharing')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kBlue.withValues(alpha: 0.08),
            border: Border.all(color: kBlue.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12)),
          child: const Text(
            'Grant read-only access to selected sections. The person must have signed in to MMM at least once.',
            style: TextStyle(fontSize: 13, color: kTextMid))),
        const SizedBox(height: 20),
        const Text('Grant Access', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
          )),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _submitting ? null : _pickModulesAndGrant,
            child: _submitting
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Next'),
          ),
        ]),
        const SizedBox(height: 24),
        const Text('Currently shared with', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (_loading) const CircularProgressIndicator()
        else if (_grantees.isEmpty)
          const Text('No one has access yet.', style: TextStyle(color: kTextMid))
        else ..._grantees.map((g) {
          final perms = g['permissions'] as Map? ?? {};
          final activeModules = _modules
              .where((m) => perms[m['key']] == true)
              .map((m) => m['label'] as String)
              .toList();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(child: Text((g['displayName'] ?? g['email'] ?? '?')[0].toUpperCase())),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g['displayName'] ?? g['email'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(g['email'] ?? '', style: const TextStyle(fontSize: 12, color: kTextMid)),
                  ])),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: kDanger),
                    onPressed: () async {
                      if (sp.myUid == null) return;
                      await FirebaseService.revokeAccess(sp.myUid!, g['uid']!);
                      await sp.loadSharedWorkspaces();
                      _load();
                    },
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  ...activeModules.map((label) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(label, style: const TextStyle(fontSize: 11, color: kAccent, fontWeight: FontWeight.w600)),
                  )),
                  if (activeModules.isEmpty)
                    const Text('No modules shared', style: TextStyle(fontSize: 11, color: kTextLight)),
                ]),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ── Module picker bottom sheet ────────────────────────────────────────────────

class _ModulePickerSheet extends StatefulWidget {
  final String email;
  const _ModulePickerSheet({required this.email});
  @override
  State<_ModulePickerSheet> createState() => _ModulePickerSheetState();
}

class _ModulePickerSheetState extends State<_ModulePickerSheet> {
  final Map<String, bool> _selected = {
    'expenses': true,
    'cards':    true,
    'lb':       true,
    'bills':    true,
  };

  static const _modules = [
    {'key': 'expenses', 'label': 'Month Expenses',  'icon': Icons.calendar_today_rounded,  'desc': 'Monthly expense tracker'},
    {'key': 'cards',    'label': 'Credit Cards',    'icon': Icons.credit_card_rounded,     'desc': 'Card spends & billing'},
    {'key': 'lb',       'label': 'LB (Lendings)',   'icon': Icons.handshake_rounded,       'desc': 'Lending & borrowing records'},
    {'key': 'bills',    'label': 'Recurring Bills', 'icon': Icons.receipt_long_rounded,    'desc': 'Monthly/quarterly/yearly bills'},
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 36, height: 4,
        decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 20),
      const Text('Choose what to share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextDark)),
      Text('Read-only access for ${widget.email}', style: const TextStyle(fontSize: 13, color: kTextMid)),
      const SizedBox(height: 16),
      ..._modules.map((m) {
        final key = m['key'] as String;
        return CheckboxListTile(
          value: _selected[key],
          onChanged: (v) => setState(() => _selected[key] = v ?? false),
          title: Text(m['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(m['desc'] as String, style: const TextStyle(fontSize: 12, color: kTextMid)),
          secondary: Icon(m['icon'] as IconData, color: kPrimary),
          activeColor: kPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: EdgeInsets.zero,
        );
      }),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary, foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => Navigator.pop(context, Map<String, bool>.from(_selected)),
          child: const Text('Grant Access', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      ),
    ]),
  );
}
