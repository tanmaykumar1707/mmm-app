import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill_model.dart';

class BillNotificationService {
  static final BillNotificationService instance = BillNotificationService._();
  BillNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  static const _prefKey = 'bill_notif_ids';
  bool _ready = false;

  Future<void> init() async {
    if (kIsWeb || _ready) return;
    tz.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {}
    const iosSettings    = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidSettings, iOS: iosSettings));
    _ready = true;
  }

  /// Schedule all alerts for a bill based on its current nextDueDate.
  Future<void> scheduleBillAlerts(Bill bill) async {
    if (kIsWeb) return;
    await cancelBillAlerts(bill.id);
    if (bill.alerts.isEmpty || bill.nextDueDate.isEmpty) return;

    DateTime dueDate;
    try { dueDate = DateTime.parse(bill.nextDueDate); }
    catch (_) { return; }

    final scheduledIds = <int>[];
    for (final alert in bill.alerts) {
      final trigger = alert.triggerDate(dueDate);
      if (trigger.isBefore(DateTime.now())) continue;

      final notifId = _stableId(bill.id, alert.id);
      final daysLabel = alert.daysBefore == 0
          ? 'due today'
          : '${alert.daysBefore} day${alert.daysBefore == 1 ? '' : 's'} left';
      try {
        await _plugin.zonedSchedule(
          notifId,
          'Bill Due — ${bill.name}',
          '${bill.icon} ${bill.amount.toStringAsFixed(0)} is $daysLabel (${bill.cycleLabel})',
          tz.TZDateTime.from(trigger, tz.local),
          NotificationDetails(
            android: const AndroidNotificationDetails(
              'bill_reminders_v1', 'Bill Reminders',
              channelDescription: 'Reminders for recurring bill due dates',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true, presentBadge: true, presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        scheduledIds.add(notifId);
      } catch (e) {
        debugPrint('Bill notification schedule error: $e');
      }
    }
    await _saveIds(bill.id, scheduledIds);
  }

  Future<void> cancelBillAlerts(String billId) async {
    if (kIsWeb) return;
    final ids = await _loadIds(billId);
    for (final id in ids) { await _plugin.cancel(id); }
    await _clearIds(billId);
  }

  Future<void> rescheduleAll(List<Bill> bills) async {
    if (kIsWeb) return;
    for (final bill in bills) { await scheduleBillAlerts(bill); }
  }

  int _stableId(String billId, String alertId) =>
      ('bill:$billId:$alertId').hashCode.abs() % 2000000000;

  Future<void> _saveIds(String billId, List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    final all = raw != null ? _decode(raw) : <String, dynamic>{};
    all[billId] = ids;
    await prefs.setString(_prefKey, _encode(all));
  }

  Future<List<int>> _loadIds(String billId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return [];
    final all = _decode(raw);
    final ids = all[billId];
    if (ids == null) return [];
    return List<int>.from(ids as List);
  }

  Future<void> _clearIds(String billId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return;
    final all = Map<String, dynamic>.from(_decode(raw));
    all.remove(billId);
    await prefs.setString(_prefKey, _encode(all));
  }

  String _encode(Map m) {
    final entries = m.entries.map((e) => '"${e.key}":[${(e.value as List).join(',')}]').join(',');
    return '{$entries}';
  }

  Map<String, dynamic> _decode(String s) {
    final result = <String, dynamic>{};
    final inner = s.substring(1, s.length - 1);
    if (inner.isEmpty) return result;
    final regex = RegExp(r'"([^"]+)":\[([^\]]*)\]');
    for (final m in regex.allMatches(inner)) {
      final key = m.group(1)!;
      final vals = m.group(2)!;
      result[key] = vals.isEmpty ? <int>[] : vals.split(',').map(int.parse).toList();
    }
    return result;
  }
}
