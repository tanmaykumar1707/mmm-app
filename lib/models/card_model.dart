class CreditCard {
  String id, name, color;
  int billDate, dueDate;
  List<CardDefault> defaults;

  CreditCard({required this.id, required this.name, required this.color,
    required this.billDate, required this.dueDate, this.defaults = const []});

  factory CreditCard.fromMap(Map m) => CreditCard(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    color: m['color'] ?? '#2563eb',
    billDate: (m['billDate'] ?? 1),
    dueDate: (m['dueDate'] ?? 15),
    defaults: ((m['defaults'] ?? []) as List)
        .map((d) => CardDefault.fromMap(d)).toList(),
  );

  Map toMap() => {'id': id, 'name': name, 'color': color,
    'billDate': billDate, 'dueDate': dueDate,
    'defaults': defaults.map((d) => d.toMap()).toList()};
}

class CardDefault {
  String id, spentFor, spentBy;
  double amount;
  int? day;

  CardDefault({required this.id, required this.spentFor,
    required this.spentBy, required this.amount, this.day});

  factory CardDefault.fromMap(Map m) => CardDefault(
    id: m['id'] ?? '', spentFor: m['spentFor'] ?? '',
    spentBy: m['spentBy'] ?? '', amount: (m['amount'] ?? 0).toDouble(),
    day: m['day'],
  );

  Map toMap() => {'id': id, 'spentFor': spentFor, 'spentBy': spentBy,
    'amount': amount, 'day': day};
}

class CardTxn {
  String id, spentFor, spentBy;
  double amount;
  bool nextBill;
  bool paid;
  String date;

  CardTxn({required this.id, required this.spentFor, required this.spentBy,
    required this.amount, required this.date, this.nextBill = false, this.paid = false});

  factory CardTxn.fromMap(Map m) => CardTxn(
    id: m['id'] ?? '', spentFor: m['spentFor'] ?? '',
    spentBy: m['spentBy'] ?? '', amount: (m['amount'] ?? 0).toDouble(),
    date: m['date'] ?? '', nextBill: m['nextBill'] ?? false,
    paid: m['paid'] ?? false,
  );

  Map toMap() => {'id': id, 'spentFor': spentFor, 'spentBy': spentBy,
    'amount': amount, 'date': date, 'nextBill': nextBill, 'paid': paid};
}

class CashTxn {
  String id, spentFor, spentBy, source, date;
  double amount;
  bool paid;

  CashTxn({required this.id, required this.spentFor, required this.spentBy,
    required this.source, required this.date, required this.amount, this.paid = false});

  factory CashTxn.fromMap(Map m) => CashTxn(
    id: m['id'] ?? '', spentFor: m['spentFor'] ?? '',
    spentBy: m['spentBy'] ?? '', source: m['source'] ?? '',
    date: m['date'] ?? '', amount: (m['amount'] ?? 0).toDouble(),
    paid: m['paid'] ?? false,
  );

  Map toMap() => {'id': id, 'spentFor': spentFor, 'spentBy': spentBy,
    'source': source, 'date': date, 'amount': amount, 'paid': paid};
}
