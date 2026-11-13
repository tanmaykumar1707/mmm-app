import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/state_provider.dart';
import 'services/firebase_service.dart';
import 'services/vault_provider.dart';
import 'services/vault_notification_service.dart';
import 'services/bill_provider.dart';
import 'services/bill_notification_service.dart';
import 'services/biometric_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/share_access_screen.dart';
import 'widgets/app_theme.dart';

String? _firebaseInitError;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    _firebaseInitError = e.toString();
    debugPrint('Firebase init error: $e');
  }
  await VaultNotificationService.instance.init();
  await VaultNotificationService.instance.requestPermissions();
  await BillNotificationService.instance.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StateProvider()),
        ChangeNotifierProvider(create: (_) => VaultProvider()),
        ChangeNotifierProvider(create: (_) => BillProvider()),
      ],
      child: const MmmApp(),
    ),
  );
}

class MmmApp extends StatelessWidget {
  const MmmApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Money Manager',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routes: {
        '/share-access': (_) => const ShareAccessScreen(),
      },
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _loading = true;
  bool _locked = false;
  String? _error;
  StreamSubscription? _authSub;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    if (_firebaseInitError != null) {
      _error = _firebaseInitError;
      _loading = false;
      return;
    }

    // Timeout: if auth stream doesn't fire in 10 s, proceed as logged-out.
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _loading) setState(() => _loading = false);
    });

    _authSub = FirebaseService.authStream.listen((user) async {
      if (!mounted) return;
      final sp = context.read<StateProvider>();
      try {
        if (user != null) {
          sp.setUser(user.uid, user.email ?? '', user.displayName ?? user.email ?? '');
          await FirebaseService.saveProfile(user.uid, user.email ?? '', user.displayName ?? '');
          await sp.loadSharedWorkspaces();
          if (mounted) sp.switchWorkspace(user.uid);
          if (mounted) context.read<VaultProvider>().init(user.uid);
          if (mounted) context.read<BillProvider>().init(user.uid);
        } else {
          if (mounted) sp.clearWorkspace();
          if (mounted) context.read<BillProvider>().clear();
        }
      } catch (e) {
        debugPrint('Auth/Firebase init error: $e');
        if (mounted) setState(() => _error = e.toString());
      }
      if (mounted) {
        bool locked = false;
        if (!kIsWeb && user != null) locked = await BiometricService.instance.isEnabled();
        setState(() { _loading = false; _locked = locked; });
      }
    }, onError: (e) {
      debugPrint('Auth stream error: $e');
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1B2559),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text('Starting MMM…',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1B2559),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                const Text('Firebase Error', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => setState(() { _loading = true; _error = null; }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = FirebaseService.currentUser;
    if (user == null) return const LoginScreen();
    if (_locked) return LockScreen(onUnlock: () => setState(() => _locked = false));
    return const HomeScreen();
  }
}
