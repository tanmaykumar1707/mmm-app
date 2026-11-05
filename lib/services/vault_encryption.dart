import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Hardcoded app secret — combined with UID to wrap the key backup in Firebase.
// Not a substitute for the user token; just prevents raw key exposure in DB.
const _kAppSecret = 'mmm_vault_2024_secret_v1';

class VaultEncryptionService {
  final FlutterSecureStorage _storage;
  enc.Key? _key;
  bool _ready = false;

  VaultEncryptionService() : _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool get isReady => _ready;

  // ── Token generation ───────────────────────────────────────────────────────

  /// Generates a cryptographically random 24-character alphanumeric token.
  static String generateToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars
    final rng = Random.secure();
    return List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Key derivation ─────────────────────────────────────────────────────────

  /// Derives a 32-byte AES key from the token and Firebase UID using
  /// 10,000 rounds of HMAC-SHA256 (simplified PBKDF2).
  static Uint8List deriveKey(String token, String uid) {
    final input = '$token:$uid:mmm_vault_v1';
    List<int> bytes = utf8.encode(input);
    for (int i = 0; i < 10000; i++) {
      bytes = hmacSha256(bytes, utf8.encode('mmm_round_$i'));
    }
    return Uint8List.fromList(bytes);
  }

  static List<int> hmacSha256(List<int> data, List<int> key) =>
      Hmac(sha256, key).convert(data).bytes;

  // ── Secure storage ─────────────────────────────────────────────────────────

  String _keyStorageKey(String uid) => 'vault_key_$uid';
  String _tokenStorageKey(String uid) => 'vault_token_$uid';

  /// Call on app start. Loads key from secure storage if present.
  Future<bool> loadKeyFromStorage(String uid) async {
    try {
      final keyHex = await _storage.read(key: _keyStorageKey(uid));
      if (keyHex == null) return false;
      _key = enc.Key(Uint8List.fromList(_hexToBytes(keyHex)));
      _ready = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Call after user enters their token. Derives + saves key.
  Future<void> initFromToken(String token, String uid) async {
    final keyBytes = deriveKey(token, uid);
    _key = enc.Key(keyBytes);
    _ready = true;
    // Save derived key to secure storage
    await _storage.write(key: _keyStorageKey(uid), value: _bytesToHex(keyBytes));
    // Save token for "restore from this device" on reinstall
    await _storage.write(key: _tokenStorageKey(uid), value: token);
  }

  /// Returns token from secure storage (for "restore from device" on reinstall).
  Future<String?> getStoredToken(String uid) async {
    try {
      return await _storage.read(key: _tokenStorageKey(uid));
    } catch (_) {
      return null;
    }
  }

  /// Clears all vault key material from device (used for "wipe vault").
  Future<void> clearKeyMaterial(String uid) async {
    await _storage.delete(key: _keyStorageKey(uid));
    await _storage.delete(key: _tokenStorageKey(uid));
    _key = null;
    _ready = false;
  }

  // ── Firebase key backup ────────────────────────────────────────────────────

  /// Wraps the AES key for backup in Firebase, encrypted with appSecret+uid.
  String encryptKeyForBackup(String uid) {
    if (_key == null) throw StateError('Key not initialized');
    final backupKey = enc.Key(Uint8List.fromList(
      _deriveBackupKey(uid).sublist(0, 32),
    ));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(backupKey, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(_key!.bytes, iv: iv);
    // Encode as iv:ciphertext in base64
    return '${base64.encode(iv.bytes)}:${encrypted.base64}';
  }

  /// Restores the AES key from the Firebase backup, then saves to storage.
  Future<bool> restoreFromBackup(String encryptedKeyBackup, String uid) async {
    try {
      final parts = encryptedKeyBackup.split(':');
      if (parts.length != 2) return false;
      final iv = enc.IV(Uint8List.fromList(base64.decode(parts[0])));
      final backupKey = enc.Key(Uint8List.fromList(_deriveBackupKey(uid).sublist(0, 32)));
      final encrypter = enc.Encrypter(enc.AES(backupKey, mode: enc.AESMode.cbc));
      final keyBytes = encrypter.decryptBytes(enc.Encrypted(base64.decode(parts[1])), iv: iv);
      _key = enc.Key(Uint8List.fromList(keyBytes));
      _ready = true;
      await _storage.write(key: _keyStorageKey(uid), value: _bytesToHex(keyBytes));
      return true;
    } catch (_) {
      return false;
    }
  }

  List<int> _deriveBackupKey(String uid) {
    List<int> bytes = utf8.encode('$_kAppSecret:$uid');
    for (int i = 0; i < 1000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return bytes;
  }

  // ── Encrypt / Decrypt ──────────────────────────────────────────────────────

  /// Encrypts a plain-text value. Returns base64(iv):base64(ciphertext).
  String encrypt(String plainText) {
    if (_key == null) throw StateError('Vault key not initialized');
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${base64.encode(iv.bytes)}:${encrypted.base64}';
  }

  /// Decrypts a value previously encrypted with [encrypt].
  String decrypt(String cipherText) {
    if (_key == null) throw StateError('Vault key not initialized');
    try {
      final parts = cipherText.split(':');
      if (parts.length != 2) return '';
      final iv = enc.IV(Uint8List.fromList(base64.decode(parts[0])));
      final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc));
      return encrypter.decrypt(enc.Encrypted(base64.decode(parts[1])), iv: iv);
    } catch (_) {
      return '';
    }
  }

  /// Encrypts if value is non-empty, else returns null.
  String? encryptOptional(String? value) =>
      (value != null && value.isNotEmpty) ? encrypt(value) : null;

  /// Decrypts if cipherText is non-null/non-empty, else returns null.
  String? decryptOptional(String? cipherText) =>
      (cipherText != null && cipherText.isNotEmpty) ? decrypt(cipherText) : null;

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}
