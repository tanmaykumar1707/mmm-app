import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/bill_model.dart';
import '../utils/constants.dart';

final _db = FirebaseDatabase.instance.ref();

class BillProvider extends ChangeNotifier {
  String? _uid;
  List<Bill> _bills = [];
  bool _loading = true;
  final List<StreamSubscription> _subs = [];

  List<Bill> get bills   => _bills;
  bool       get loading => _loading;

  List<Bill> get overdue => _sorted(_bills.where((b) => b.status == BillStatus.overdue));
  List<Bill> get dueSoon => _sorted(_bills.where((b) => b.status == BillStatus.dueSoon));
  List<Bill> get later   => _sorted(_bills.where((b) => b.status == BillStatus.later));

  List<Bill> _sorted(Iterable<Bill> src) =>
      src.toList()..sort((a, b) => a.nextDueParsed.compareTo(b.nextDueParsed));

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init(String uid) async {
    if (_uid == uid) return;
    _uid = uid;
    _loading = true;
    notifyListeners();
    _cancelSubs();

    _subs.add(_db.child('users/$uid/bills').onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        _bills = [];
      } else {
        _bills = (event.snapshot.value as Map).entries.map((e) =>
            Bill.fromMap(e.key as String, Map.from(e.value as Map))).toList();
      }
      _loading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('BillProvider listener error: $e');
      _loading = false;
      notifyListeners();
    }));
  }

  void clear() {
    _cancelSubs();
    _bills = [];
    _uid = null;
    _loading = true;
    notifyListeners();
  }

  // ── Payment history ───────────────────────────────────────────────────────

  Future<List<BillPayment>> loadPayments(String billId) async {
    if (_uid == null) return [];
    final snap = await _db.child('users/$_uid/bills/$billId/payments').get();
    if (!snap.exists || snap.value == null) return [];
    final list = (snap.value as Map).entries
        .map((e) => BillPayment.fromMap(e.key as String, Map.from(e.value as Map)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> addBill(Bill bill) async {
    if (_uid == null) return;
    await _db.child('users/$_uid/bills/${bill.id}').set(bill.toMap());
  }

  Future<void> updateBill(Bill bill) async {
    if (_uid == null) return;
    // Only update mutable fields; payments subcollection is untouched.
    final map = bill.toMap();
    map.remove('payments'); // never overwrite payments via full update
    await _db.child('users/$_uid/bills/${bill.id}').update(map);
  }

  Future<void> deleteBill(String billId) async {
    if (_uid == null) return;
    await _db.child('users/$_uid/bills/$billId').remove();
  }

  /// Atomic batch: write payment record + advance nextDueDate on the bill.
  Future<void> markPaid({
    required String billId,
    required double amount,
    required String paidOn,      // "YYYY-MM-DD"
    required String dueDate,     // "YYYY-MM-DD" — cycle this covers
    required int daysLate,
    required String nextDueDate, // already computed next cycle date
  }) async {
    if (_uid == null) return;
    final paymentId = genId();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update({
      'users/$_uid/bills/$billId/nextDueDate': nextDueDate,
      'users/$_uid/bills/$billId/payments/$paymentId': {
        'amount': amount,
        'paidOn': paidOn,
        'dueDate': dueDate,
        'daysLate': daysLate,
        'createdAt': now,
      },
    });
  }

  void _cancelSubs() {
    for (final s in _subs) { s.cancel(); }
    _subs.clear();
  }

  @override
  void dispose() {
    _cancelSubs();
    super.dispose();
  }
}
