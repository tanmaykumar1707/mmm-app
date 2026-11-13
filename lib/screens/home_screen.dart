import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/state_provider.dart';
import '../services/firebase_service.dart';
import '../utils/constants.dart';
import 'month_tab.dart';
import 'cards_tab.dart';
import 'lb_tab.dart';
import 'defaults_tab.dart' show DefaultsScreen;
import 'vault_tab.dart';
import 'vault_expiry_dashboard.dart';
import 'bills_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;


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
      drawer: _AppDrawer(sp: sp),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: kPrimary),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('My Money Manager',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: kPrimary, fontFamily: 'Outfit')),
          if (sp.isReadOnly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: kWarn.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Read-only', style: TextStyle(color: kWarn, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
        ]),
        actions: [
          GestureDetector(
            onTap: () => _showProfileMenu(context, sp),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: kPrimary,
                child: Text(
                  (sp.myDisplayName ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        // Build visible tabs based on permissions
        final allTabs = [
          {'icon': Icons.calendar_today_rounded, 'label': 'This Month', 'module': 'expenses', 'widget': const MonthTab()},
          {'icon': Icons.credit_card_rounded,    'label': 'Cards',      'module': 'cards',    'widget': const CardsTab()},
          {'icon': Icons.receipt_long_rounded,   'label': 'Bills',      'module': 'bills',    'widget': const BillsTab()},
          {'icon': Icons.handshake_rounded,      'label': 'LB',         'module': 'lb',       'widget': const LbTab()},
          {'icon': Icons.lock_rounded,           'label': 'Vault',      'module': null,       'widget': const VaultTab()},
        ];
        final visibleTabs = allTabs.where((t) {
          final module = t['module'] as String?;
          return module == null ? !sp.isReadOnly : sp.canView(module);
        }).toList();
        final safeTab = _tab.clamp(0, (visibleTabs.length - 1).clamp(0, 99));

        return Column(children: [
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: IndexedStack(
              index: safeTab,
              children: visibleTabs.map((t) => t['widget'] as Widget).toList(),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(visibleTabs.length, (i) => _NavItem(
                    icon: visibleTabs[i]['icon'] as IconData,
                    label: visibleTabs[i]['label'] as String,
                    selected: i == safeTab,
                    onTap: () => setState(() => _tab = i),
                  )),
                ),
              ),
            ),
          ),
        ]);
      }),
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: selected
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 7)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kPrimary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? kPrimary : kTextLight, size: 20),
          if (selected) ...[
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(
              fontFamily: 'Outfit', fontSize: 11,
              color: kPrimary, fontWeight: FontWeight.w700,
            )),
          ],
        ]),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final StateProvider sp;
  const _AppDrawer({required this.sp});
  @override
  Widget build(BuildContext context) {
    final name = sp.myDisplayName ?? '?';
    final email = sp.myEmail ?? '';
    return Drawer(
      child: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20, right: 20, bottom: 20,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kPrimary, Color(0xFF7C3AED)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 28, backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(name[0].toUpperCase(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white))),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(email, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
          ]),
        ),
        // Menu items
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
          _DrawerItem(icon: Icons.person_outline_rounded, label: 'Profile',
            onTap: () { Navigator.pop(context); _showProfile(context); }),
          _DrawerItem(icon: Icons.swap_horiz_rounded, label: 'Switch Workspace',
            onTap: () { Navigator.pop(context); _showWorkspace(context); }),
          _DrawerItem(icon: Icons.people_outline_rounded, label: 'People & Access',
            onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/share-access'); }),
          _DrawerItem(icon: Icons.settings_rounded, label: 'Settings',
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const DefaultsScreen())); }),
          _DrawerItem(icon: Icons.notifications_none_rounded, label: 'Alerts'),
          _DrawerItem(icon: Icons.calendar_month_rounded, label: 'Expiry / Renewal',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultExpiryDashboard()));
            }),
          _DrawerItem(icon: Icons.info_outline_rounded, label: 'About',
            onTap: () { Navigator.pop(context); _showAbout(context); }),
        ])),
        // Logout
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: kDanger),
          title: const Text('Logout', style: TextStyle(color: kDanger, fontWeight: FontWeight.w600)),
          onTap: () async {
            Navigator.pop(context);
            await FirebaseService.signOut();
          },
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ]),
    );
  }

  void _showProfile(BuildContext context) {
    showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProfileSheet(sp: sp));
  }

  void _showWorkspace(BuildContext context) {
    showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _WorkspaceSheet(sp: sp));
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _AboutSheet());
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _DrawerItem({required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: kPrimary, size: 22),
    title: Text(label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500)),
    onTap: onTap ?? () => Navigator.pop(context),
  );
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
                final perms = ws['permissions'] as Map<String, bool>?;
                sp.switchWorkspace(ws['uid']! as String, permissions: perms);
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

class _AboutSheet extends StatefulWidget {
  const _AboutSheet();
  @override
  State<_AboutSheet> createState() => _AboutSheetState();
}

class _AboutSheetState extends State<_AboutSheet> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kPrimary, Color(0xFF7C3AED)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 14),
        const Text('MY LS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Outfit', color: kPrimary)),
        const Text('My Money Manager', style: TextStyle(fontSize: 13, color: kTextMid, fontFamily: 'Outfit')),
        const SizedBox(height: 6),
        if (_version.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('v$_version', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kPrimary, fontFamily: 'Outfit')),
          ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        const Row(children: [
          Icon(Icons.person_rounded, size: 16, color: kTextLight),
          SizedBox(width: 8),
          Text('Developer', style: TextStyle(fontSize: 12, color: kTextLight, fontFamily: 'Outfit')),
          Spacer(),
          Text('Tanmay Kumar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
        ]),
        const SizedBox(height: 10),
        const Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: kTextLight),
          SizedBox(width: 8),
          Text('Tagline', style: TextStyle(fontSize: 12, color: kTextLight, fontFamily: 'Outfit')),
          Spacer(),
          Text('Make Your Life Simple', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
        ]),
        const SizedBox(height: 20),
      ]),
    );
  }
}
