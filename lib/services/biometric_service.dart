import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final instance = BiometricService._();
  BiometricService._();

  static const _key = 'app_lock_enabled';
  final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) { return false; }
  }

  Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, val);
  }

  Future<bool> authenticate() async {
    if (kIsWeb) return true;
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock MY LS to continue',
        options: const AuthenticationOptions(biometricOnly: false),
      );
    } catch (_) { return false; }
  }
}
