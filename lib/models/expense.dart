class Expense {
  String id, name, category;
  double amount;
  int? dueDate;
  bool paid;

  Expense({required this.id, required this.name, required this.category,
    required this.amount, this.dueDate, this.paid = false});

  factory Expense.fromMap(Map m) => Expense(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    category: m['category'] ?? 'Other',
    amount: (m['amount'] ?? 0).toDouble(),
    dueDate: m['dueDate'],
    paid: m['paid'] ?? false,
  );

  Map toMap() => {'id': id, 'name': name, 'category': category,
    'amount': amount, 'dueDate': dueDate, 'paid': paid};
}
