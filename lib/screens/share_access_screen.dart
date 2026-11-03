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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = context.read<StateProvider>();
    if (sp.myUid == null) return;
    final list = await FirebaseService.getGrantedAccesses(sp.myUid!);
    setState(() { _grantees = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.read<StateProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Access Sharing')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kBlue.withValues(alpha: 0.08),
            border: Border.all(color: kBlue.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
          child: const Text(
            'Grant read-only access to your data. The person must have signed in to MMM at least once.',
            style: TextStyle(fontSize: 13, color: kTextMid))),
        const SizedBox(height: 20),
        const Text('Grant Access', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'))),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _submitting ? null : () async {
              final email = _emailCtrl.text.trim();
              if (email.isEmpty || sp.myUid == null) return;
              setState(() => _submitting = true);
              try {
                await FirebaseService.grantAccess(sp.myUid!, email);
                _emailCtrl.clear();
                await sp.loadSharedWorkspaces();
                _load();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Access granted to $email'),
                    backgroundColor: Colors.green));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$e'), backgroundColor: Colors.red));
              } finally {
                if (mounted) setState(() => _submitting = false);
              }
            },
            child: _submitting
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Grant'),
          ),
        ]),
        const SizedBox(height: 24),
        const Text('Currently shared with', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (_loading) const CircularProgressIndicator()
        else if (_grantees.isEmpty)
          const Text('No one has access yet.', style: TextStyle(color: kTextMid))
        else ..._grantees.map((g) => Card(margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(child: Text((g['displayName'] ?? g['email'] ?? '?')[0].toUpperCase())),
            title: Text(g['displayName'] ?? g['email'] ?? ''),
            subtitle: Text(g['email'] ?? ''),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: const Text('read-only', style: TextStyle(fontSize: 11, color: kAccent))),
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
          ))),
      ]),
    );
  }
}
