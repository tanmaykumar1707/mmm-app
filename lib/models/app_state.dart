import 'expense.dart';
import 'card_model.dart';
import 'lb_entry.dart';

class AppState {
  Map<String, List<Expense>> months;
  List<Expense> defaults;
  List<CreditCard> cards;
  Map<String, Map<String, List<CardTxn>>> cardTxns;
  List<String> people;
  Map<String, bool> billGenerated;
  Map<String, List<CashTxn>> cashTxns;
  List<String> cashSources;
  List<LbEntry> lbEntries;

  AppState({
    Map<String, List<Expense>>? months,
    List<Expense>? defaults,
    List<CreditCard>? cards,
    Map<String, Map<String, List<CardTxn>>>? cardTxns,
    List<String>? people,
    Map<String, bool>? billGenerated,
    Map<String, List<CashTxn>>? cashTxns,
    List<String>? cashSources,
    List<LbEntry>? lbEntries,
  })  : months = months ?? {},
        defaults = defaults ?? [],
        cards = cards ?? [],
        cardTxns = cardTxns ?? {},
        people = people ?? [],
        billGenerated = billGenerated ?? {},
        cashTxns = cashTxns ?? {},
        cashSources = cashSources ?? [],
        lbEntries = lbEntries ?? [];

  factory AppState.empty() => AppState();

  factory AppState.fromMap(Map m) {
    final months = <String, List<Expense>>{};
    ((m['months'] ?? {}) as Map).forEach((k, v) {
      months[k] = (v as List).map((e) => Expense.fromMap(e)).toList();
    });
    final cardTxns = <String, Map<String, List<CardTxn>>>{};
    ((m['cardTxns'] ?? {}) as Map).forEach((cardId, byMonth) {
      cardTxns[cardId] = {};
      (byMonth as Map).forEach((monthKey, txnList) {
        cardTxns[cardId]![monthKey] = (txnList as List)
            .map((t) => CardTxn.fromMap(t)).toList();
      });
    });
    final cashTxns = <String, List<CashTxn>>{};
    ((m['cashTxns'] ?? {}) as Map).forEach((k, v) {
      cashTxns[k] = (v as List).map((t) => CashTxn.fromMap(t)).toList();
    });
    return AppState(
      months: months,
      defaults: ((m['defaults'] ?? []) as List).map((e) => Expense.fromMap(e)).toList(),
      cards: ((m['cards'] ?? []) as List).map((c) => CreditCard.fromMap(c)).toList(),
      cardTxns: cardTxns,
      people: List<String>.from(m['people'] ?? []),
      billGenerated: Map<String, bool>.from(m['billGenerated'] ?? {}),
      cashTxns: cashTxns,
      cashSources: List<String>.from(m['cashSources'] ?? []),
      lbEntries: ((m['lbEntries'] ?? []) as List).map((e) => LbEntry.fromMap(e)).toList(),
    );
  }

  Map toMap() => {
    'months': months.map((k, v) => MapEntry(k, v.map((e) => e.toMap()).toList())),
    'defaults': defaults.map((e) => e.toMap()).toList(),
    'cards': cards.map((c) => c.toMap()).toList(),
    'cardTxns': cardTxns.map((cid, byM) => MapEntry(cid,
        byM.map((mk, txns) => MapEntry(mk, txns.map((t) => t.toMap()).toList())))),
    'people': people,
    'billGenerated': billGenerated,
    'cashTxns': cashTxns.map((k, v) => MapEntry(k, v.map((t) => t.toMap()).toList())),
    'cashSources': cashSources,
    'lbEntries': lbEntries.map((e) => e.toMap()).toList(),
  };
}
