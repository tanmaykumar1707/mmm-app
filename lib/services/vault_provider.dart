import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/vault_model.dart';
import '../utils/constants.dart';
import 'vault_encryption.dart';
import 'vault_notification_service.dart';

enum VaultStatus { loading, needsSetup, needsToken, ready }

class VaultProvider extends ChangeNotifier {
  final VaultEncryptionService _enc = VaultEncryptionService();

  VaultStatus _status = VaultStatus.needsSetup; // start as needsSetup, not loading
  String? _uid;

  List<VaultPerson> _persons = [];
  List<VaultCategory> _categories = [];
  List<VaultFolder> _folders = [];
  List<VaultPinnedRef> _pinned = [];

  String? _activePersonId;
  String? _error;

  // Stream subscriptions (properly cancelable)
  final List<StreamSubscription> _subs = [];

  VaultStatus get status => _status;
  List<VaultPerson> get persons => _persons;
  List<VaultFolder> get folders => _folders;
  String? get activePersonId => _activePersonId;
  String? get error => _error;
  VaultEncryptionService get enc => _enc;

  List<VaultCategory> categoriesForPerson(String personId) =>
      _categories.where((c) => c.personId == personId).toList();

  List<VaultPinnedRef> get pinnedRefs => _pinned;

  // Returns resolved pinned fields (category + field + decrypted value)
  List<({VaultCategory cat, VaultField field, String? instanceId})> get pinnedFields {
    final result = <({VaultCategory cat, VaultField field, String? instanceId})>[];
    for (final ref in _pinned) {
      final cat = _categories.where((c) => c.id == ref.categoryId).firstOrNull;
      if (cat == null) continue;
      if (ref.instanceId != null) {
        final inst = cat.instances.where((i) => i.id == ref.instanceId).firstOrNull;
        final field = inst?.fields.where((f) => f.id == ref.fieldId).firstOrNull;
        if (field != null) result.add((cat: cat, field: field, instanceId: ref.instanceId));
      } else {
        final field = cat.fields.where((f) => f.id == ref.fieldId).firstOrNull;
        if (field != null) result.add((cat: cat, field: field, instanceId: null));
      }
    }
    return result;
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> init(String uid) async {
    _uid = uid;
    _status = VaultStatus.loading;
    notifyListeners();

    try {
      // Try loading key from secure storage
      final keyLoaded = await _enc.loadKeyFromStorage(uid);
      if (!keyLoaded) {
        // Check if vault was ever initialized in Firebase
        final metaSnap = await _db.child('users/$uid/vault/meta').get();
        if (!metaSnap.exists) {
          _status = VaultStatus.needsSetup;
        } else {
          // Vault exists in DB but no key on this device — always require token.
          // We intentionally do NOT auto-restore from encKeyBackup because that
          // backup is encrypted with a constant app secret, not the user's token.
          // Auto-restoring would let any device bypass the token entirely.
          _status = VaultStatus.needsToken;
        }
        notifyListeners();
        return;
      }

      await _startListening(uid);
    } catch (e) {
      debugPrint('VaultProvider.init error: $e');
      _status = VaultStatus.needsSetup;
      notifyListeners();
    }
  }

  /// Called after user generates/enters their token for the first time.
  Future<void> setupVault(String token, {String ownerName = 'Me'}) async {
    final uid = _uid!;
    await _enc.initFromToken(token, uid);

    // Create the owner person using their real display name
    final meId = genId();
    final me = VaultPerson(id: meId, name: ownerName, colorHex: '#4F46E5', isDefault: true);
    await _db.child('users/$uid/vault/persons/$meId').set(me.toMap());

    // Write default categories
    for (final cat in buildDefaultCategories(meId)) {
      await _db.child('users/$uid/vault/categories/${cat.id}').set(cat.toMap());
    }

    // Write key backup to Firebase
    final keyBackup = _enc.encryptKeyForBackup(uid);
    await _db.child('users/$uid/vault/meta').set({'initialized': true, 'encKeyBackup': keyBackup});

    await _startListening(uid);
  }

  /// Called when user enters token on a new device.
  Future<bool> unlockWithToken(String token) async {
    final uid = _uid!;
    await _enc.initFromToken(token, uid);

    // Verify by trying to read + decrypt one field
    final catSnap = await _db.child('users/$uid/vault/categories').get();
    if (!catSnap.exists) return false;

    _status = VaultStatus.loading;
    notifyListeners();
    await _startListening(uid);
    return true;
  }

  /// Wipe all vault data + local key material.
  Future<void> wipeVault() async {
    final uid = _uid!;
    await _enc.clearKeyMaterial(uid);
    await _db.child('users/$uid/vault').remove();
    _persons = [];
    _categories = [];
    _folders = [];
    _pinned = [];
    _status = VaultStatus.needsSetup;
    notifyListeners();
  }

  Future<void> _startListening(String uid) async {
    _cancelListeners();
    _activePersonId = null;

    _subs.add(_db.child('users/$uid/vault/persons').onValue.listen((e) {
      if (!e.snapshot.exists) {
        _persons = [];
      } else {
        _persons = (e.snapshot.value as Map).entries
            .map((en) => VaultPerson.fromMap(en.key as String, Map.from(en.value as Map)))
            .toList();
        _persons.sort((a, b) => a.isDefault ? -1 : 1);
      }
      if (_activePersonId == null && _persons.isNotEmpty) {
        _activePersonId = _persons.first.id;
      }
      notifyListeners();
    }, onError: (e) => debugPrint('Vault persons listener error: $e')));

    _subs.add(_db.child('users/$uid/vault/categories').onValue.listen((e) {
      if (!e.snapshot.exists) {
        _categories = [];
      } else {
        _categories = (e.snapshot.value as Map).entries
            .map((en) => VaultCategory.fromMap(en.key as String, Map.from(en.value as Map)))
            .toList();
        _decryptAllFields();
      }
      notifyListeners();
    }, onError: (e) => debugPrint('Vault categories listener error: $e')));

    _subs.add(_db.child('users/$uid/vault/folders').onValue.listen((e) {
      if (!e.snapshot.exists) {
        _folders = [];
      } else {
        _folders = (e.snapshot.value as Map).entries
            .map((en) => VaultFolder.fromMap(en.key as String, Map.from(en.value as Map)))
            .toList();
      }
      notifyListeners();
    }, onError: (e) => debugPrint('Vault folders listener error: $e')));

    _subs.add(_db.child('users/$uid/vault/pinned').onValue.listen((e) {
      if (!e.snapshot.exists) {
        _pinned = [];
      } else {
        _pinned = (e.snapshot.value as Map).entries
            .map((en) => VaultPinnedRef.fromMap(en.key as String, Map.from(en.value as Map)))
            .toList();
      }
      notifyListeners();
    }, onError: (e) => debugPrint('Vault pinned listener error: $e')));

    _status = VaultStatus.ready;
    notifyListeners();
    unawaited(VaultNotificationService.instance.rescheduleAll(_categories));
  }

  void _decryptAllFields() {
    for (final cat in _categories) {
      for (final field in cat.fields) {
        field.value = _enc.decryptOptional(field.valueEncrypted);
      }
      for (final inst in cat.instances) {
        for (final field in inst.fields) {
          field.value = _enc.decryptOptional(field.valueEncrypted);
        }
        for (final card in inst.cards) {
          for (final field in card.fields) {
            field.value = _enc.decryptOptional(field.valueEncrypted);
          }
        }
        inst.note = _enc.decryptOptional(inst.noteEncrypted);
      }
      cat.note = _enc.decryptOptional(cat.noteEncrypted);
    }
  }

  Future<void> saveBankInstanceNote(String catId, String instanceId, String note) async {
    final uid = _uid!;
    final enc = _enc.encryptOptional(note);
    await _db.child('users/$uid/vault/categories/$catId/instances/$instanceId/noteEncrypted').set(enc);
  }

  void _cancelListeners() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
  }

  // ── Person operations ──────────────────────────────────────────────────────

  void setActivePerson(String personId) {
    _activePersonId = personId;
    notifyListeners();
  }

  Future<void> addPerson(String name, String colorHex) async {
    final uid = _uid!;
    final id = genId();
    final person = VaultPerson(id: id, name: name, colorHex: colorHex);
    await _db.child('users/$uid/vault/persons/$id').set(person.toMap());
    // Create default categories for this person too
    for (final cat in buildDefaultCategories(id)) {
      await _db.child('users/$uid/vault/categories/${cat.id}').set(cat.toMap());
    }
  }

  Future<void> deletePerson(String personId) async {
    final uid = _uid!;
    // Remove all categories for this person
    final toDelete = _categories.where((c) => c.personId == personId).map((c) => c.id).toList();
    for (final catId in toDelete) {
      await _db.child('users/$uid/vault/categories/$catId').remove();
    }
    await _db.child('users/$uid/vault/persons/$personId').remove();
    if (_activePersonId == personId) {
      _activePersonId = _persons.isNotEmpty ? _persons.first.id : null;
      notifyListeners();
    }
  }

  // ── Category operations ────────────────────────────────────────────────────

  Future<void> saveCategory(VaultCategory cat) async {
    final uid = _uid!;
    // Encrypt all field values before saving
    for (final field in cat.fields) {
      field.valueEncrypted = _enc.encryptOptional(field.value);
    }
    for (final inst in cat.instances) {
      for (final field in inst.fields) {
        field.valueEncrypted = _enc.encryptOptional(field.value);
      }
    }
    cat.noteEncrypted = _enc.encryptOptional(cat.note);
    await _db.child('users/$uid/vault/categories/${cat.id}').set(cat.toMap());
  }

  Future<void> deleteCategory(String catId) async {
    await _db.child('users/$_uid/vault/categories/$catId').remove();
  }

  Future<void> updateCategoryNote(String catId, String note) async {
    final uid = _uid!;
    final enc = _enc.encryptOptional(note);
    await _db.child('users/$uid/vault/categories/$catId/noteEncrypted').set(enc);
  }

  // ── Field operations ───────────────────────────────────────────────────────

  Future<void> saveField(String catId, VaultField field) async {
    final uid = _uid!;
    final toSave = field.copyWith(valueEncrypted: _enc.encryptOptional(field.value));
    await _db.child('users/$uid/vault/categories/$catId/fields/${field.id}').set(toSave.toMap());
    final cat = _categories.where((c) => c.id == catId).firstOrNull;
    if (cat != null) {
      unawaited(VaultNotificationService.instance.scheduleFieldAlerts(field, cat.name));
    }
  }

  Future<void> deleteField(String catId, String fieldId) async {
    await _db.child('users/$_uid/vault/categories/$catId/fields/$fieldId').remove();
    unawaited(VaultNotificationService.instance.cancelFieldAlerts(fieldId));
  }

  Future<void> saveFieldAlerts(String catId, String fieldId, List<VaultAlert> alerts) async {
    final uid = _uid!;
    final alertsMap = alerts.isEmpty ? null : {for (final a in alerts) a.id: a.toMap()};
    await _db.child('users/$uid/vault/categories/$catId/fields/$fieldId/alerts').set(alertsMap);
    final cat = _categories.where((c) => c.id == catId).firstOrNull;
    final field = cat?.fields.where((f) => f.id == fieldId).firstOrNull;
    if (field != null && cat != null) {
      unawaited(VaultNotificationService.instance.scheduleFieldAlerts(
        field.copyWith(alerts: alerts), cat.name));
    }
  }

  // ── Bank instance operations ───────────────────────────────────────────────

  Future<void> addBankInstance(String catId, VaultBankInstance instance) async {
    final uid = _uid!;
    for (final field in instance.fields) {
      field.valueEncrypted = _enc.encryptOptional(field.value);
    }
    for (final card in instance.cards) {
      for (final field in card.fields) {
        field.valueEncrypted = _enc.encryptOptional(field.value);
      }
    }
    await _db.child('users/$uid/vault/categories/$catId/instances/${instance.id}').set(instance.toMap());
  }

  Future<void> saveBankInstance(String catId, VaultBankInstance instance) async {
    await addBankInstance(catId, instance);
  }

  Future<void> deleteBankInstance(String catId, String instanceId) async {
    await _db.child('users/$_uid/vault/categories/$catId/instances/$instanceId').remove();
  }

  Future<void> saveBankField(String catId, String instanceId, VaultField field) async {
    final uid = _uid!;
    final toSave = field.copyWith(valueEncrypted: _enc.encryptOptional(field.value));
    await _db.child('users/$uid/vault/categories/$catId/instances/$instanceId/fields/${field.id}').set(toSave.toMap());
  }

  // ── Bank card operations ───────────────────────────────────────────────────

  Future<void> deleteBankField(String catId, String instanceId, String fieldId) async {
    await _db.child('users/$_uid/vault/categories/$catId/instances/$instanceId/fields/$fieldId').remove();
  }

  Future<void> addBankCard(String catId, String instanceId, VaultBankCard card) async {
    final uid = _uid!;
    for (final field in card.fields) {
      field.valueEncrypted = _enc.encryptOptional(field.value);
    }
    await _db.child('users/$uid/vault/categories/$catId/instances/$instanceId/cards/${card.id}').set(card.toMap());
  }

  Future<void> deleteBankCard(String catId, String instanceId, String cardId) async {
    await _db.child('users/$_uid/vault/categories/$catId/instances/$instanceId/cards/$cardId').remove();
  }

  Future<void> saveBankCardField(String catId, String instanceId, String cardId, VaultField field) async {
    final uid = _uid!;
    final toSave = field.copyWith(valueEncrypted: _enc.encryptOptional(field.value));
    await _db.child('users/$uid/vault/categories/$catId/instances/$instanceId/cards/$cardId/fields/${field.id}').set(toSave.toMap());
  }

  // ── Folder operations ──────────────────────────────────────────────────────

  Future<void> saveFolder(VaultFolder folder) async {
    await _db.child('users/$_uid/vault/folders/${folder.id}').set(folder.toMap());
  }

  Future<void> deleteFolder(String folderId) async {
    // Remove folder ref from categories
    for (final cat in _categories.where((c) => c.folderId == folderId)) {
      await _db.child('users/$_uid/vault/categories/${cat.id}/folderId').remove();
    }
    await _db.child('users/$_uid/vault/folders/$folderId').remove();
  }

  Future<void> moveCategoryToFolder(String catId, String? folderId) async {
    final uid = _uid!;
    if (folderId == null) {
      await _db.child('users/$uid/vault/categories/$catId/folderId').remove();
    } else {
      await _db.child('users/$uid/vault/categories/$catId/folderId').set(folderId);
      // Add catId to folder's list
      final folder = _folders.where((f) => f.id == folderId).firstOrNull;
      if (folder != null && !folder.categoryIds.contains(catId)) {
        final updated = VaultFolder(id: folder.id, personId: folder.personId, name: folder.name,
          categoryIds: [...folder.categoryIds, catId]);
        await saveFolder(updated);
      }
    }
  }

  // ── Pinned fields ──────────────────────────────────────────────────────────

  Future<void> pinField(String catId, String fieldId, {String? instanceId}) async {
    final uid = _uid!;
    final id = genId();
    final ref = VaultPinnedRef(id: id, categoryId: catId, fieldId: fieldId, instanceId: instanceId);
    await _db.child('users/$uid/vault/pinned/$id').set(ref.toMap());
  }

  Future<void> unpinField(String pinnedRefId) async {
    await _db.child('users/$_uid/vault/pinned/$pinnedRefId').remove();
  }

  DatabaseReference get _db => FirebaseDatabase.instance.ref();

  @override
  void dispose() {
    _cancelListeners();
    super.dispose();
  }
}
