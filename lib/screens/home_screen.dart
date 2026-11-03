import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/state_provider.dart';
import '../services/firebase_service.dart';
import '../utils/constants.dart';
import 'month_tab.dart';
import 'cards_tab.dart';
import 'lb_tab.dart';
import 'defaults_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _tabs = [
    {'icon': Icons.calendar_today_rounded,    'label': 'This Month'},
    {'icon': Icons.credit_card_rounded,       'label': 'Cards'},
    {'icon': Icons.handshake_rounded,         'label': 'LB'},
    {'icon': Icons.settings_rounded,          'label': 'Defaults'},
  ];

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StateProvider>();
    // Show Firebase errors as snackbar
    if (sp.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sp.errorMessage!),
          backgroundColor: const Color(0xFFDC2626),
          action: SnackBarAction(label: 'Dismiss', textColor: Colors.white, onPressed: sp.clearError),
          duration: const Duration(seconds: 8),
        ));
        sp.clearError();
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('MMM'),
        actions: [
          if (sp.isReadOnly)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kWarn.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Read-only', style: TextStyle(color: kWarn, fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Switch workspace',
            onPressed: () => _showWorkspaceSheet(context, sp),
          ),
          GestureDetector(
            onTap: () => _showProfileMenu(context, sp),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: kAccent,
                child: Text(
                  (sp.myDisplayName ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [MonthTab(), CardsTab(), LbTab(), DefaultsTab()],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_tabs.length, (i) => _NavItem(
                    icon: _tabs[i]['icon'] as IconData,
                    label: _tabs[i]['label'] as String,
                    selected: i == _tab,
                    onTap: () => setState(() => _tab = i),
                  )),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWorkspaceSheet(BuildContext ctx, StateProvider sp) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _WorkspaceSheet(sp: sp),
    );
  }

  void _showProfileMenu(BuildContext ctx, StateProvider sp) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProfileSheet(sp: sp),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label,
    required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? kPrimary : kTextLight, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontFamily: 'Outfit', fontSize: 10,
            color: selected ? kPrimary : kTextLight,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          )),
        ]),
      ),
    );
  }
}

class _WorkspaceSheet extends StatelessWidget {
  final StateProvider sp;
  const _WorkspaceSheet({required this.sp});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Switch Workspace', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ListTile(
            leading: const CircleAvatar(backgroundColor: kPrimary, child: Icon(Icons.home, color: Colors.white, size: 18)),
            title: const Text('My Data'),
            trailing: sp.currentWorkspaceUid == sp.myUid ? const Icon(Icons.check, color: kAccent) : null,
            onTap: () {
              sp.switchWorkspace(sp.myUid!);
              Navigator.pop(context);
            },
          ),
          if (sp.sharedWorkspaces.isNotEmpty) ...[
            const Divider(),
            const Text('Shared with me', style: TextStyle(fontSize: 12, color: kTextLight, fontWeight: FontWeight.w600)),
            ...sp.sharedWorkspaces.map((ws) => ListTile(
              leading: CircleAvatar(child: Text((ws['displayName'] ?? '?')[0].toUpperCase())),
              title: Text(ws['displayName'] ?? ws['email'] ?? ''),
              subtitle: Text(ws['email'] ?? '', style: const TextStyle(fontSize: 11)),
              trailing: sp.currentWorkspaceUid == ws['uid'] ? const Icon(Icons.check, color: kAccent) : null,
              onTap: () {
                sp.switchWorkspace(ws['uid']!);
                Navigator.pop(context);
              },
            )),
          ],
          const Divider(),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFEEF1F6), child: Icon(Icons.share, color: kPrimary, size: 18)),
            title: const Text('Manage Access Sharing'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/share-access');
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileSheet extends StatelessWidget {
  final StateProvider sp;
  const _ProfileSheet({required this.sp});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 30, backgroundColor: kPrimary,
          child: Text((sp.myDisplayName ?? '?')[0].toUpperCase(),
            style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),
        Text(sp.myDisplayName ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Text(sp.myEmail ?? '', style: const TextStyle(fontSize: 13, color: kTextMid)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout, color: kDanger),
            label: const Text('Sign Out', style: TextStyle(color: kDanger)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kDanger),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseService.signOut();
            },
          ),
        ),
      ]),
    );
  }
}
