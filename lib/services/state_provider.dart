import 'package:flutter/material.dart';
import '../models/app_state.dart';
import '../models/expense.dart';
import '../models/card_model.dart';
import '../models/lb_entry.dart';
import '../utils/constants.dart';
import 'firebase_service.dart';
import 'dart:async';

class StateProvider extends ChangeNotifier {
  AppState _state = AppState.empty();
  AppState get state => _state;

  String? _myUid;
  String? _myEmail;
  String? _myDisplayName;
  String? get myUid => _myUid;
  String? get myEmail => _myEmail;
  String? get myDisplayName => _myDisplayName;

  String? _currentWorkspaceUid;
  String? get currentWorkspaceUid => _currentWorkspaceUid;
  bool get isReadOnly => _currentWorkspaceUid != null && _currentWorkspaceUid != _myUid;

  List<Map<String, String>> _sharedWorkspaces = [];
  List<Map<String, String>> get sharedWorkspaces => _sharedWorkspaces;

  // Error state — shown as a banner in the UI
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  void clearError() { _errorMessage = null; notifyListeners(); }

  StreamSubscription? _stateSub;
  Timer? _saveTimer;

  void setUser(String uid, String email, String displayName) {
    _myUid = uid;
    _myEmail = email;
    _myDisplayName = displayName;
  }

  Future<void> loadSharedWorkspaces() async {
    if (_myUid == null) return;
    try {
      _sharedWorkspaces = await FirebaseService.getSharedWorkspaces(_myUid!);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Could not load shared workspaces: $e';
      notifyListeners();
    }
  }

  void switchWorkspace(String uid) {
    _currentWorkspaceUid = uid;
    _stateSub?.cancel();
    _stateSub = FirebaseService.watchState(uid).listen(
      (s) {
        _state = s;
        _errorMessage = null;
        if (_state.people.isEmpty && uid == _myUid) {
          _state.people = [_myDisplayName ?? 'Me'];
        }
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Firebase error: ${e.toString()}';
        notifyListeners();
      },
    );
    notifyListeners();
  }

  void clearWorkspace() {
    _stateSub?.cancel();
    _stateSub = null;
    _myUid = null;
    _currentWorkspaceUid = null;
    _state = AppState.empty();
    notifyListeners();
  }

  void save() {
    if (isReadOnly || _myUid == null) return;
    // Debounce: coalesce rapid successive mutations into one Firebase write
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      FirebaseService.saveState(_myUid!, _state);
    });
  }

  // ── Month expenses ──
  List<Expense> monthExpenses(String k) => _state.months[k] ?? [];

  void addExpense(String k, Expense e) {
    _state.months[k] = [...(monthExpenses(k)), e];
    save(); notifyListeners();
  }

  void updateExpense(String k, Expense e) {
    final list = monthExpenses(k).toList();
    final i = list.indexWhere((x) => x.id == e.id);
    if (i >= 0) list[i] = e;
    _state.months[k] = list;
    save(); notifyListeners();
  }

  void deleteExpense(String k, String id) {
    _state.months[k] = monthExpenses(k).where((e) => e.id != id).toList();
    save(); notifyListeners();
  }

  void toggleExpensePaid(String k, String id) {
    final list = monthExpenses(k).toList();
    final i = list.indexWhere((e) => e.id == id);
    if (i >= 0) list[i].paid = !list[i].paid;
    _state.months[k] = list;
    save(); notifyListeners();
  }

  void createMonthFromDefaults(String k) {
    _state.months[k] = _state.defaults.map((d) => Expense(
      id: genId(), name: d.name, category: d.category,
      amount: d.amount, dueDate: d.dueDate,
    )).toList();
    save(); notifyListeners();
  }

  // ── Defaults ──
  void addDefault(Expense e) { _state.defaults.add(e); save(); notifyListeners(); }
  void updateDefault(Expense e) {
    final i = _state.defaults.indexWhere((x) => x.id == e.id);
    if (i >= 0) _state.defaults[i] = e;
    save(); notifyListeners();
  }
  void deleteDefault(String id) {
    _state.defaults.removeWhere((e) => e.id == id);
    save(); notifyListeners();
  }

  // ── People ──
  void addPerson(String name) { _state.people.add(name); save(); notifyListeners(); }
  void deletePerson(String name) {
    _state.people.remove(name);
    save(); notifyListeners();
  }

  // ── Cards ──
  void addCard(CreditCard card) { _state.cards.add(card); save(); notifyListeners(); }
  void updateCard(CreditCard card) {
    final i = _state.cards.indexWhere((c) => c.id == card.id);
    if (i >= 0) _state.cards[i] = card;
    save(); notifyListeners();
  }
  void deleteCard(String id) {
    _state.cards.removeWhere((c) => c.id == id);
    _state.cardTxns.remove(id);
    save(); notifyListeners();
  }

  // ── Card transactions ──
  List<CardTxn> cardTxns(String cardId, String mk) =>
      _state.cardTxns[cardId]?[mk] ?? [];

  void addCardTxn(String cardId, String mk, CardTxn t) {
    _state.cardTxns[cardId] ??= {};
    _state.cardTxns[cardId]![mk] = [...cardTxns(cardId, mk), t];
    save(); notifyListeners();
  }

  void deleteCardTxn(String cardId, String mk, String id) {
    _state.cardTxns[cardId]?[mk]?.removeWhere((t) => t.id == id);
    save(); notifyListeners();
  }

  void updateCardTxn(String cardId, String mk, CardTxn t) {
    final list = cardTxns(cardId, mk).toList();
    final i = list.indexWhere((x) => x.id == t.id);
    if (i >= 0) list[i] = t;
    _state.cardTxns[cardId]?[mk] = list;
    save(); notifyListeners();
  }

  void toggleNextBill(String cardId, String mk, String id) {
    final list = cardTxns(cardId, mk);
    final i = list.indexWhere((t) => t.id == id);
    if (i >= 0) list[i].nextBill = !list[i].nextBill;
    save(); notifyListeners();
  }

  void toggleCardTxnPaid(String cardId, String mk, String id) {
    final list = cardTxns(cardId, mk);
    final i = list.indexWhere((t) => t.id == id);
    if (i >= 0) list[i].paid = !list[i].paid;
    save(); notifyListeners();
  }

  void setBillGenerated(String key, bool val) {
    _state.billGenerated[key] = val;
    save(); notifyListeners();
  }

  // ── Cash transactions ──
  List<CashTxn> cashTxns(String mk) => _state.cashTxns[mk] ?? [];

  void addCashTxn(String mk, CashTxn t) {
    _state.cashTxns[mk] = [...cashTxns(mk), t];
    save(); notifyListeners();
  }

  void updateCashTxn(String mk, CashTxn t) {
    final list = cashTxns(mk).toList();
    final i = list.indexWhere((x) => x.id == t.id);
    if (i >= 0) list[i] = t;
    _state.cashTxns[mk] = list;
    save(); notifyListeners();
  }

  void deleteCashTxn(String mk, String id) {
    _state.cashTxns[mk]?.removeWhere((t) => t.id == id);
    save(); notifyListeners();
  }

  void toggleCashTxnPaid(String mk, String id) {
    final list = cashTxns(mk);
    final i = list.indexWhere((t) => t.id == id);
    if (i >= 0) list[i].paid = !list[i].paid;
    save(); notifyListeners();
  }

  void addCashSource(String src) {
    if (!_state.cashSources.contains(src)) {
      _state.cashSources.add(src);
      save(); notifyListeners();
    }
  }

  // ── LB entries ──
  void addLbEntry(LbEntry e) { _state.lbEntries.add(e); save(); notifyListeners(); }
  void updateLbEntry(LbEntry e) {
    final i = _state.lbEntries.indexWhere((x) => x.id == e.id);
    if (i >= 0) _state.lbEntries[i] = e;
    save(); notifyListeners();
  }
  void deleteLbEntry(String id) {
    _state.lbEntries.removeWhere((e) => e.id == id);
    save(); notifyListeners();
  }
  void addRepayment(String lbId, Repayment r) {
    final i = _state.lbEntries.indexWhere((e) => e.id == lbId);
    if (i >= 0) {
      _state.lbEntries[i].repayments = [..._state.lbEntries[i].repayments, r];
    }
    save(); notifyListeners();
  }
  void deleteRepayment(String lbId, String repaymentId) {
    final i = _state.lbEntries.indexWhere((e) => e.id == lbId);
    if (i >= 0) {
      _state.lbEntries[i].repayments.removeWhere((r) => r.id == repaymentId);
    }
    save(); notifyListeners();
  }

  void clearAll() {
    _state = AppState.empty();
    if (_myDisplayName != null) _state.people = [_myDisplayName!];
    save(); notifyListeners();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }
}
