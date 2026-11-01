class Repayment {
  String id, note, date;
  double amount;

  Repayment({required this.id, required this.note,
    required this.date, required this.amount});

  factory Repayment.fromMap(Map m) => Repayment(
    id: m['id'] ?? '', note: m['note'] ?? '',
    date: m['date'] ?? '', amount: (m['amount'] ?? 0).toDouble(),
  );

  Map toMap() => {'id': id, 'note': note, 'date': date, 'amount': amount};
}

class LbEntry {
  String id, type, person, reason, date;
  double amount;
  String? dueDate;
  bool settled;
  List<Repayment> repayments;

  LbEntry({required this.id, required this.type, required this.person,
    required this.reason, required this.date, required this.amount,
    this.dueDate, this.settled = false, this.repayments = const []});

  double get repaid => repayments.fold(0, (s, r) => s + r.amount);
  double get remaining => (amount - repaid).clamp(0, double.infinity);
  bool get isSettled => settled || remaining == 0;

  factory LbEntry.fromMap(Map m) => LbEntry(
    id: m['id'] ?? '', type: m['type'] ?? 'lent',
    person: m['person'] ?? '', reason: m['reason'] ?? '',
    date: m['date'] ?? '', amount: (m['amount'] ?? 0).toDouble(),
    dueDate: m['dueDate'], settled: m['settled'] ?? false,
    repayments: ((m['repayments'] ?? []) as List)
        .map((r) => Repayment.fromMap(r)).toList(),
  );

  Map toMap() => {'id': id, 'type': type, 'person': person, 'reason': reason,
    'date': date, 'amount': amount, 'dueDate': dueDate, 'settled': settled,
    'repayments': repayments.map((r) => r.toMap()).toList()};
}
