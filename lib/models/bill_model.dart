import 'package:flutter/material.dart';

enum BillCycle  { monthly, quarterly, yearly }
enum BillStatus { overdue, dueSoon, later }

// ── Alert ─────────────────────────────────────────────────────────────────────

class BillAlert {
  final String id;
  final int daysBefore;
  final int hour;
  final int minute;

  const BillAlert({
    required this.id,
    this.daysBefore = 3,
    this.hour = 9,
    this.minute = 0,
  });

  factory BillAlert.fromMap(String id, Map m) => BillAlert(
    id: id,
    daysBefore: (m['daysBefore'] ?? 3) as int,
    hour:       (m['hour']       ?? 9) as int,
    minute:     (m['minute']     ?? 0) as int,
  );

  Map<String, dynamic> toMap() =>
      {'daysBefore': daysBefore, 'hour': hour, 'minute': minute};

  DateTime triggerDate(DateTime dueDate) {
    final d = dueDate.subtract(Duration(days: daysBefore));
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Payment ───────────────────────────────────────────────────────────────────

class BillPayment {
  final String id;
  final double amount;
  final String paidOn;   // "YYYY-MM-DD" — date user selected
  final String dueDate;  // "YYYY-MM-DD" — cycle this payment covers
  final int daysLate;    // 0 = on time, >0 = late by N days
  final int createdAt;

  const BillPayment({
    required this.id,
    required this.amount,
    required this.paidOn,
    required this.dueDate,
    this.daysLate = 0,
    required this.createdAt,
  });

  factory BillPayment.fromMap(String id, Map m) => BillPayment(
    id:        id,
    amount:    (m['amount']    ?? 0).toDouble(),
    paidOn:    m['paidOn']     ?? '',
    dueDate:   m['dueDate']    ?? '',
    daysLate:  (m['daysLate']  ?? 0) as int,
    createdAt: (m['createdAt'] ?? 0) as int,
  );

  Map<String, dynamic> toMap() => {
    'amount': amount, 'paidOn': paidOn, 'dueDate': dueDate,
    'daysLate': daysLate, 'createdAt': createdAt,
  };
}

// ── Bill ──────────────────────────────────────────────────────────────────────

class Bill {
  final String id;
  final String name;
  final String type;        // "electricity", "rent", …
  final String icon;
  final BillCycle cycle;
  final double amount;
  final String colorHex;
  final int dueDay;         // day of month 1-31
  final int? dueMonth;      // 1-12: start month for quarterly/yearly
  final String nextDueDate; // "YYYY-MM-DD" — updated after every payment
  final List<BillAlert> alerts;
  final int createdAt;

  // runtime only — loaded on demand in detail screen
  List<BillPayment> payments;

  Bill({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.cycle,
    required this.amount,
    this.colorHex = '#4F46E5',
    required this.dueDay,
    this.dueMonth,
    required this.nextDueDate,
    this.alerts = const [],
    required this.createdAt,
    this.payments = const [],
  });

  factory Bill.fromMap(String id, Map m) => Bill(
    id:           id,
    name:         m['name']     ?? '',
    type:         m['type']     ?? 'custom',
    icon:         m['icon']     ?? '📄',
    cycle:        BillCycle.values.firstWhere(
                    (e) => e.name == (m['cycle'] ?? 'monthly'),
                    orElse: () => BillCycle.monthly),
    amount:       (m['amount']  ?? 0).toDouble(),
    colorHex:     m['colorHex'] ?? '#4F46E5',
    dueDay:       (m['dueDay']  ?? 1) as int,
    dueMonth:     m['dueMonth'] as int?,
    nextDueDate:  m['nextDueDate'] ?? '',
    alerts:       m['alerts'] == null
                    ? []
                    : (m['alerts'] as Map).entries
                        .map((e) => BillAlert.fromMap(e.key as String, Map.from(e.value as Map)))
                        .toList(),
    createdAt:    (m['createdAt'] ?? 0) as int,
  );

  Map<String, dynamic> toMap() => {
    'name': name, 'type': type, 'icon': icon, 'cycle': cycle.name,
    'amount': amount, 'colorHex': colorHex, 'dueDay': dueDay,
    if (dueMonth != null) 'dueMonth': dueMonth,
    'nextDueDate': nextDueDate,
    if (alerts.isNotEmpty) 'alerts': {for (final a in alerts) a.id: a.toMap()},
    'createdAt': createdAt,
  };

  Bill copyWith({
    String? name, String? type, String? icon, BillCycle? cycle,
    double? amount, String? colorHex, int? dueDay, int? dueMonth,
    String? nextDueDate, List<BillAlert>? alerts, List<BillPayment>? payments,
  }) => Bill(
    id: id, createdAt: createdAt,
    name:         name         ?? this.name,
    type:         type         ?? this.type,
    icon:         icon         ?? this.icon,
    cycle:        cycle        ?? this.cycle,
    amount:       amount       ?? this.amount,
    colorHex:     colorHex     ?? this.colorHex,
    dueDay:       dueDay       ?? this.dueDay,
    dueMonth:     dueMonth     ?? this.dueMonth,
    nextDueDate:  nextDueDate  ?? this.nextDueDate,
    alerts:       alerts       ?? this.alerts,
    payments:     payments     ?? this.payments,
  );

  // ── Computed ──────────────────────────────────────────────────────────────

  DateTime get nextDueParsed {
    try { return DateTime.parse(nextDueDate); }
    catch (_) { return DateTime.now().add(const Duration(days: 1)); }
  }

  int get daysUntilDue {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return nextDueParsed.difference(today).inDays;
  }

  BillStatus get status {
    final d = daysUntilDue;
    if (d < 0) return BillStatus.overdue;
    if (d <= 7) return BillStatus.dueSoon;
    return BillStatus.later;
  }

  Color get statusColor => switch (status) {
    BillStatus.overdue  => const Color(0xFFEF4444),
    BillStatus.dueSoon  => const Color(0xFFF59E0B),
    BillStatus.later    => const Color(0xFF2563EB),
  };

  Color hexColor() {
    try { return Color(int.parse(colorHex.replaceFirst('#', 'FF'), radix: 16)); }
    catch (_) { return const Color(0xFF4F46E5); }
  }

  String get cycleLabel => switch (cycle) {
    BillCycle.monthly   => 'Monthly',
    BillCycle.quarterly => 'Quarterly',
    BillCycle.yearly    => 'Yearly',
  };

  /// Advances nextDueDate by one cycle interval.
  String advanceNextDueDate() {
    final d = nextDueParsed;
    late DateTime next;
    switch (cycle) {
      case BillCycle.monthly:
        next = DateTime(d.year, d.month + 1, dueDay);
      case BillCycle.quarterly:
        next = DateTime(d.year, d.month + 3, dueDay);
      case BillCycle.yearly:
        next = DateTime(d.year + 1, d.month, dueDay);
    }
    return _fmt(next);
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String fmtDate(DateTime d) => _fmt(d);

  static String todayStr() => _fmt(DateTime.now());
}

// ── Bill type catalogue ───────────────────────────────────────────────────────

class BillTypeInfo {
  final String type;
  final String icon;
  final String label;
  final String colorHex;
  const BillTypeInfo({required this.type, required this.icon, required this.label, required this.colorHex});
}

const kBillTypes = [
  BillTypeInfo(type: 'rent',        icon: '🏠', label: 'Rent',        colorHex: '#7C3AED'),
  BillTypeInfo(type: 'electricity', icon: '⚡', label: 'Electricity', colorHex: '#CA8A04'),
  BillTypeInfo(type: 'gas',         icon: '🔥', label: 'Gas / LPG',   colorHex: '#DC2626'),
  BillTypeInfo(type: 'water',       icon: '💧', label: 'Water',       colorHex: '#0891B2'),
  BillTypeInfo(type: 'internet',    icon: '🌐', label: 'Internet',    colorHex: '#2563EB'),
  BillTypeInfo(type: 'mobile',      icon: '📱', label: 'Mobile',      colorHex: '#059669'),
  BillTypeInfo(type: 'ott',         icon: '🎬', label: 'OTT / Apps',  colorHex: '#DB2777'),
  BillTypeInfo(type: 'emi',         icon: '🏦', label: 'Loan / EMI',  colorHex: '#4F46E5'),
  BillTypeInfo(type: 'insurance',   icon: '🛡️', label: 'Insurance',   colorHex: '#0D9488'),
  BillTypeInfo(type: 'maintenance', icon: '🏢', label: 'Maintenance', colorHex: '#6B7280'),
  BillTypeInfo(type: 'gym',         icon: '🏋️', label: 'Gym / Club',  colorHex: '#EA580C'),
  BillTypeInfo(type: 'custom',      icon: '✏️', label: 'Custom',      colorHex: '#4F46E5'),
];

BillTypeInfo billTypeInfo(String type) =>
    kBillTypes.firstWhere((t) => t.type == type, orElse: () => kBillTypes.last);
