import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'services/state_provider.dart';
import 'services/firebase_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/share_access_screen.dart';
import 'widgets/app_theme.dart';

// TODO: Replace with your actual Firebase options
// Run: flutterfire configure
// to generate firebase_options.dart automatically
const firebaseOptions = FirebaseOptions(
  apiKey: 'YOUR_API_KEY',
  appId: 'YOUR_APP_ID',
  messagingSenderId: 'YOUR_SENDER_ID',
  projectId: 'YOUR_PROJECT_ID',
  databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com',
  storageBucket: 'YOUR_PROJECT_ID.appspot.com',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(
    ChangeNotifierProvider(
      create: (_) => StateProvider(),
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
  @override
  void initState() {
    super.initState();
    FirebaseService.authStream.listen((user) async {
      final sp = context.read<StateProvider>();
      if (user != null) {
        sp.setUser(user.uid, user.email ?? '', user.displayName ?? user.email ?? '');
        await FirebaseService.saveProfile(user.uid, user.email ?? '', user.displayName ?? '');
        await sp.loadSharedWorkspaces();
        sp.switchWorkspace(user.uid);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.currentUser;
    if (user == null) return const LoginScreen();
    return const HomeScreen();
  }
}
