import '../utils/constants.dart';

enum VaultFieldType { text, number, date, hidden }

enum VaultCardType { debit, credit, other }

// ── Alert config (time-of-day + days before expiry) ────────────────────────
class VaultAlert {
  final String id;
  final int daysBefore;
  final int hour;   // 0-23
  final int minute; // 0-59

  const VaultAlert({required this.id, required this.daysBefore, this.hour = 9, this.minute = 0});

  factory VaultAlert.fromMap(String id, Map m) => VaultAlert(
    id: id,
    daysBefore: (m['daysBefore'] ?? 30) as int,
    hour: (m['hour'] ?? 9) as int,
    minute: (m['minute'] ?? 0) as int,
  );

  Map<String, dynamic> toMap() => {'daysBefore': daysBefore, 'hour': hour, 'minute': minute};

  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // Always returns the computed trigger datetime — callers check past/future themselves.
  // Past check must use full HH:MM time, not midnight, to avoid wrongly nulling same-day alerts.
  DateTime triggerDate(DateTime expiryDate) {
    final d = expiryDate.subtract(Duration(days: daysBefore));
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  bool get isFuture => triggerDate(DateTime.now()).isAfter(DateTime.now());
}

class VaultField {
  String id;
  String label;
  VaultFieldType type;
  String? valueEncrypted;
  bool isExpiryField;
  List<VaultAlert> alerts;
  bool isPinned;
  int sortOrder;

  // runtime only — decrypted value, never persisted
  String? value;

  VaultField({
    required this.id,
    required this.label,
    this.type = VaultFieldType.text,
    this.valueEncrypted,
    this.isExpiryField = false,
    this.alerts = const [],
    this.isPinned = false,
    this.sortOrder = 0,
    this.value,
  });

  factory VaultField.fromMap(String id, Map m) => VaultField(
        id: id,
        label: m['label'] ?? '',
        type: VaultFieldType.values.firstWhere(
          (e) => e.name == (m['type'] ?? 'text'),
          orElse: () => VaultFieldType.text,
        ),
        valueEncrypted: m['valueEncrypted'],
        isExpiryField: m['isExpiryField'] == true,
        alerts: m['alerts'] == null
            ? (m['isExpiryField'] == true
                ? [VaultAlert(id: genId(), daysBefore: (m['alertDays'] ?? 30) as int)]
                : [])
            : (m['alerts'] as Map).entries
                .map((e) => VaultAlert.fromMap(e.key as String, Map.from(e.value as Map)))
                .toList(),
        isPinned: m['isPinned'] == true,
        sortOrder: (m['sortOrder'] ?? 0) as int,
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'type': type.name,
        if (valueEncrypted != null) 'valueEncrypted': valueEncrypted,
        'isExpiryField': isExpiryField,
        if (alerts.isNotEmpty) 'alerts': {for (final a in alerts) a.id: a.toMap()},
        'isPinned': isPinned,
        'sortOrder': sortOrder,
      };

  VaultField copyWith({
    String? label,
    VaultFieldType? type,
    String? valueEncrypted,
    bool? isExpiryField,
    List<VaultAlert>? alerts,
    bool? isPinned,
    int? sortOrder,
    String? value,
  }) =>
      VaultField(
        id: id,
        label: label ?? this.label,
        type: type ?? this.type,
        valueEncrypted: valueEncrypted ?? this.valueEncrypted,
        isExpiryField: isExpiryField ?? this.isExpiryField,
        alerts: alerts ?? this.alerts,
        isPinned: isPinned ?? this.isPinned,
        sortOrder: sortOrder ?? this.sortOrder,
        value: value ?? this.value,
      );

  /// Days until expiry, null if not an expiry field or no value
  int? get daysUntilExpiry {
    if (!isExpiryField || value == null || value!.isEmpty) return null;
    try {
      final parts = value!.split('/');
      late DateTime expiry;
      if (parts.length == 2) {
        // MM/YY or MM/YYYY
        final m = int.parse(parts[0]);
        final y = int.parse(parts[1]);
        expiry = DateTime(y < 100 ? 2000 + y : y, m + 1, 0);
      } else if (parts.length == 3) {
        // DD/MM/YYYY
        expiry = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } else {
        return null;
      }
      return expiry.difference(DateTime.now()).inDays;
    } catch (_) {
      return null;
    }
  }
}

// ── Bank card (Debit / Credit / Other card within a bank instance) ─────────
class VaultBankCard {
  String id;
  VaultCardType cardType;
  List<VaultField> fields; // Card Number, CVV, Expiry

  VaultBankCard({
    required this.id,
    this.cardType = VaultCardType.debit,
    this.fields = const [],
  });

  factory VaultBankCard.fromMap(String id, Map m) => VaultBankCard(
        id: id,
        cardType: VaultCardType.values.firstWhere(
          (e) => e.name == (m['cardType'] ?? 'debit'),
          orElse: () => VaultCardType.debit,
        ),
        fields: m['fields'] == null
            ? []
            : (m['fields'] as Map).entries
                .map((e) => VaultField.fromMap(e.key as String, Map.from(e.value as Map)))
                .toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );

  Map<String, dynamic> toMap() => {
        'cardType': cardType.name,
        'fields': {for (final f in fields) f.id: f.toMap()},
      };
}

// ── Bank instance (one bank account under Bank Accounts category) ──────────
class VaultBankInstance {
  String id;
  String bankName;
  String colorHex;
  List<VaultField> fields;
  List<VaultBankCard> cards;
  String? noteEncrypted;
  String? note; // runtime-only, never persisted directly

  VaultBankInstance({
    required this.id,
    required this.bankName,
    this.colorHex = '#4F46E5',
    this.fields = const [],
    this.cards = const [],
    this.noteEncrypted,
    this.note,
  });

  factory VaultBankInstance.fromMap(String id, Map m) => VaultBankInstance(
        id: id,
        bankName: m['bankName'] ?? '',
        colorHex: m['colorHex'] ?? '#4F46E5',
        noteEncrypted: m['noteEncrypted'],
        fields: m['fields'] == null
            ? []
            : (m['fields'] as Map).entries
                .map((e) => VaultField.fromMap(e.key as String, Map.from(e.value as Map)))
                .toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        cards: m['cards'] == null
            ? []
            : (m['cards'] as Map).entries
                .map((e) => VaultBankCard.fromMap(e.key as String, Map.from(e.value as Map)))
                .toList(),
      );

  Map<String, dynamic> toMap() => {
        'bankName': bankName,
        'colorHex': colorHex,
        if (noteEncrypted != null) 'noteEncrypted': noteEncrypted,
        'fields': {for (final f in fields) f.id: f.toMap()},
        if (cards.isNotEmpty) 'cards': {for (final c in cards) c.id: c.toMap()},
      };
}

// ── Category ───────────────────────────────────────────────────────────────
class VaultCategory {
  String id;
  String personId;
  String name;
  String icon;
  String colorHex;
  bool isDefault;
  bool isMultiInstance; // true only for Bank Accounts
  String? folderId;
  String? noteEncrypted;
  String? note; // runtime decrypted
  List<VaultField> fields;         // regular categories
  List<VaultBankInstance> instances; // bank multi-instance

  VaultCategory({
    required this.id,
    required this.personId,
    required this.name,
    this.icon = '📄',
    this.colorHex = '#4F46E5',
    this.isDefault = false,
    this.isMultiInstance = false,
    this.folderId,
    this.noteEncrypted,
    this.note,
    this.fields = const [],
    this.instances = const [],
  });

  factory VaultCategory.fromMap(String id, Map m) => VaultCategory(
        id: id,
        personId: m['personId'] ?? '',
        name: m['name'] ?? '',
        icon: m['icon'] ?? '📄',
        colorHex: m['colorHex'] ?? '#4F46E5',
        isDefault: m['isDefault'] == true,
        isMultiInstance: m['isMultiInstance'] == true,
        folderId: m['folderId'],
        noteEncrypted: m['noteEncrypted'],
        fields: m['fields'] == null
            ? []
            : (m['fields'] as Map).entries
                .map((e) => VaultField.fromMap(e.key as String, Map.from(e.value as Map)))
                .toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        instances: m['instances'] == null
            ? []
            : (m['instances'] as Map).entries
                .map((e) => VaultBankInstance.fromMap(e.key as String, Map.from(e.value as Map)))
                .toList(),
      );

  Map<String, dynamic> toMap() => {
        'personId': personId,
        'name': name,
        'icon': icon,
        'colorHex': colorHex,
        'isDefault': isDefault,
        'isMultiInstance': isMultiInstance,
        if (folderId != null) 'folderId': folderId,
        if (noteEncrypted != null) 'noteEncrypted': noteEncrypted,
        if (fields.isNotEmpty) 'fields': {for (final f in fields) f.id: f.toMap()},
        if (instances.isNotEmpty) 'instances': {for (final i in instances) i.id: i.toMap()},
      };

  /// Nearest expiry in days across all expiry fields
  int? get nearestExpiryDays {
    final days = fields
        .where((f) => f.isExpiryField)
        .map((f) => f.daysUntilExpiry)
        .whereType<int>()
        .toList();
    if (days.isEmpty) return null;
    days.sort();
    return days.first;
  }

  int get fieldCount => isMultiInstance
      ? instances.fold(0, (s, i) => s + i.fields.length)
      : fields.length;
}

// ── Person ─────────────────────────────────────────────────────────────────
class VaultPerson {
  String id;
  String name;
  String colorHex;
  bool isDefault; // "Me" — cannot be deleted

  VaultPerson({
    required this.id,
    required this.name,
    this.colorHex = '#4F46E5',
    this.isDefault = false,
  });

  factory VaultPerson.fromMap(String id, Map m) => VaultPerson(
        id: id,
        name: m['name'] ?? '',
        colorHex: m['colorHex'] ?? '#4F46E5',
        isDefault: m['isDefault'] == true,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'colorHex': colorHex,
        'isDefault': isDefault,
      };

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

// ── Folder ─────────────────────────────────────────────────────────────────
class VaultFolder {
  String id;
  String personId;
  String name;
  List<String> categoryIds;

  VaultFolder({
    required this.id,
    required this.personId,
    required this.name,
    this.categoryIds = const [],
  });

  factory VaultFolder.fromMap(String id, Map m) => VaultFolder(
        id: id,
        personId: m['personId'] ?? '',
        name: m['name'] ?? '',
        categoryIds: m['categoryIds'] == null
            ? []
            : List<String>.from(m['categoryIds'] as List),
      );

  Map<String, dynamic> toMap() => {
        'personId': personId,
        'name': name,
        'categoryIds': categoryIds,
      };
}

// ── Pinned field reference ─────────────────────────────────────────────────
class VaultPinnedRef {
  String id;
  String categoryId;
  String fieldId;
  String? instanceId; // for bank fields

  VaultPinnedRef({
    required this.id,
    required this.categoryId,
    required this.fieldId,
    this.instanceId,
  });

  factory VaultPinnedRef.fromMap(String id, Map m) => VaultPinnedRef(
        id: id,
        categoryId: m['categoryId'] ?? '',
        fieldId: m['fieldId'] ?? '',
        instanceId: m['instanceId'],
      );

  Map<String, dynamic> toMap() => {
        'categoryId': categoryId,
        'fieldId': fieldId,
        if (instanceId != null) 'instanceId': instanceId,
      };
}

// ── Default category templates ─────────────────────────────────────────────
List<VaultCategory> buildDefaultCategories(String personId) {
  int _ord = 0;
  VaultField f(String label, {VaultFieldType type = VaultFieldType.text, bool hidden = false, bool expiry = false, int alertDays = 30}) {
    final id = genId();
    return VaultField(
      id: id, label: label, type: hidden ? VaultFieldType.hidden : type,
      isExpiryField: expiry,
      alerts: expiry ? [VaultAlert(id: genId(), daysBefore: alertDays)] : [],
      sortOrder: _ord++,
    );
  }

  return [
    // Aadhaar
    VaultCategory(id: genId(), personId: personId, name: 'Aadhaar', icon: '🪪', colorHex: '#0891B2', isDefault: true,
      fields: [f('Aadhaar Number', hidden: true), f('Full Name'), f('Date of Birth', type: VaultFieldType.date), f('Linked Mobile', hidden: true)]),

    // PAN
    VaultCategory(id: genId(), personId: personId, name: 'PAN Card', icon: '📋', colorHex: '#059669', isDefault: true,
      fields: [f('PAN Number', hidden: true), f('Full Name'), f('Date of Birth', type: VaultFieldType.date), f("Father's Name")]),

    // Driving Licence
    VaultCategory(id: genId(), personId: personId, name: 'Driving Licence', icon: '🚗', colorHex: '#7C3AED', isDefault: true,
      fields: [f('DL Number', hidden: true), f('Full Name'), f('Date of Birth', type: VaultFieldType.date), f('Valid Till', type: VaultFieldType.date, expiry: true, alertDays: 60), f('Vehicle Class')]),

    // Passport
    VaultCategory(id: genId(), personId: personId, name: 'Passport', icon: '🛂', colorHex: '#DB2777', isDefault: true,
      fields: [f('Passport Number', hidden: true), f('Full Name'), f('Date of Birth', type: VaultFieldType.date), f('Place of Issue'), f('Valid Till', type: VaultFieldType.date, expiry: true, alertDays: 60), f('File Number')]),

    // Bank Accounts — multi-instance
    VaultCategory(id: genId(), personId: personId, name: 'Bank Accounts', icon: '🏦', colorHex: '#4F46E5', isDefault: true, isMultiInstance: true),

    // UAN
    VaultCategory(id: genId(), personId: personId, name: 'UAN / EPF', icon: '👷', colorHex: '#D97706', isDefault: true,
      fields: [f('UAN Number', hidden: true), f('Full Name'), f('PF Account No.', hidden: true), f('Employer Name')]),

    // Electricity
    VaultCategory(id: genId(), personId: personId, name: 'Electricity', icon: '⚡', colorHex: '#CA8A04', isDefault: true,
      fields: [f('Consumer No.', hidden: true), f('Name on Account'), f('Distribution Company'), f('Meter No.')]),

    // Gas
    VaultCategory(id: genId(), personId: personId, name: 'Gas', icon: '🔥', colorHex: '#DC2626', isDefault: true,
      fields: [f('Consumer No.', hidden: true), f('BP / LPG ID', hidden: true), f('Name on Account'), f('Distribution Company')]),

    // Mparivahan
    VaultCategory(id: genId(), personId: personId, name: 'Mparivahan', icon: '🚙', colorHex: '#0D9488', isDefault: true,
      fields: [f('Registration No.'), f('Owner Name'), f('Vehicle Type'), f('Chassis No.', hidden: true), f('Engine No.', hidden: true), f('Insurance Expiry', type: VaultFieldType.date, expiry: true, alertDays: 30), f('PUC Expiry', type: VaultFieldType.date, expiry: true, alertDays: 15)]),
  ];
}

/// Default bank instance field template (account-level fields only)
List<VaultField> buildBankInstanceFields() {
  int o = 0;
  VaultField f(String label, {bool hidden = false, VaultFieldType type = VaultFieldType.text}) =>
      VaultField(id: genId(), label: label, type: hidden ? VaultFieldType.hidden : type, sortOrder: o++);
  return [
    f('Account Number', hidden: true),
    f('Customer ID', hidden: true),
    f('IFSC Code'),
    f('Branch Name'),
  ];
}

/// Default card field template (3 fields per card)
List<VaultField> buildBankCardFields() {
  int o = 0;
  VaultField f(String label, {bool hidden = false, VaultFieldType type = VaultFieldType.text}) =>
      VaultField(id: genId(), label: label, type: hidden ? VaultFieldType.hidden : type, sortOrder: o++);
  return [
    f('Card Number', hidden: true),
    f('CVV', hidden: true),
    f('Expiry', type: VaultFieldType.date),
  ];
}
