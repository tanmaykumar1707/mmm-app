import 'package:flutter/material.dart';
import '../services/biometric_service.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const LockScreen({super.key, required this.onUnlock});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_checking) return;
    setState(() { _checking = true; _error = null; });
    final ok = await BiometricService.instance.authenticate();
    if (!mounted) return;
    if (ok) {
      widget.onUnlock();
    } else {
      setState(() { _checking = false; _error = 'Authentication failed. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2559),
      body: SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_rounded, size: 64, color: Colors.white),
            const SizedBox(height: 20),
            const Text('MY LS',
              style: TextStyle(color: Colors.white, fontSize: 28,
                  fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
            const SizedBox(height: 8),
            const Text('Make Your Life Simple',
              style: TextStyle(color: Colors.white60, fontSize: 14)),
            const SizedBox(height: 48),
            if (_checking)
              const CircularProgressIndicator(color: Colors.white)
            else ...[
              if (_error != null) ...[
                Text(_error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1B2559),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _unlock,
                icon: const Icon(Icons.fingerprint_rounded, size: 22),
                label: const Text('Unlock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
