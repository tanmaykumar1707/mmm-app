import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vault_model.dart';

class VaultNotificationService {
  static final VaultNotificationService instance = VaultNotificationService._();
  VaultNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _prefKey = 'vault_notif_ids';

  Future<void> init() async {
    if (kIsWeb) return;
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      // fallback to UTC
    }

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } else if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      // Android 12+ requires explicit user grant for exact alarms
      await android?.requestExactAlarmsPermission();
      return true;
    }
    return false;
  }

  Future<void> scheduleFieldAlerts(VaultField field, String categoryName) async {
    if (kIsWeb) return;
    await cancelFieldAlerts(field.id);
    if (!field.isExpiryField || field.alerts.isEmpty || field.value == null || field.value!.isEmpty) return;

    final expiryDate = _parseDate(field.value!);
    if (expiryDate == null) return;

    final scheduledIds = <int>[];
    for (final alert in field.alerts) {
      final trigger = alert.triggerDate(expiryDate);
      // Skip if the FULL trigger time (not just midnight) has already passed
      if (trigger.isBefore(DateTime.now())) continue;

      final notifId = _stableId(field.id, alert.id);
      try {
        await _plugin.zonedSchedule(
          notifId,
          'Expiry Alert — $categoryName',
          '${field.label} expires in ${alert.daysBefore} day(s) on ${field.value}',
          tz.TZDateTime.from(trigger, tz.local),
          NotificationDetails(
            android: const AndroidNotificationDetails(
              'vault_expiry_v1', 'Vault Expiry Alerts',
              channelDescription: 'Reminders for document expiry dates',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        scheduledIds.add(notifId);
      } catch (e) {
        debugPrint('Failed to schedule notification: $e');
      }
    }
    await _saveScheduledIds(field.id, scheduledIds);
  }

  Future<void> cancelFieldAlerts(String fieldId) async {
    if (kIsWeb) return;
    final ids = await _loadScheduledIds(fieldId);
    for (final id in ids) {
      await _plugin.cancel(id);
    }
    await _clearScheduledIds(fieldId);
  }

  Future<void> rescheduleAll(List<VaultCategory> categories) async {
    if (kIsWeb) return;
    for (final cat in categories) {
      for (final field in cat.fields) {
        if (field.isExpiryField) await scheduleFieldAlerts(field, cat.name);
      }
      for (final inst in cat.instances) {
        for (final field in inst.fields) {
          if (field.isExpiryField) await scheduleFieldAlerts(field, '${cat.name} — ${inst.bankName}');
        }
      }
    }
  }

  int _stableId(String fieldId, String alertId) =>
      (fieldId + alertId).hashCode.abs() % 2000000000;

  DateTime? _parseDate(String value) {
    try {
      final parts = value.split('/');
      if (parts.length == 2) {
        final m = int.parse(parts[0]);
        final y = int.parse(parts[1]);
        return DateTime(y < 100 ? 2000 + y : y, m + 1, 0);
      } else if (parts.length == 3) {
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveScheduledIds(String fieldId, List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    final all = raw != null ? _decode(raw) : <String, dynamic>{};
    all[fieldId] = ids;
    await prefs.setString(_prefKey, _encode(all));
  }

  Future<List<int>> _loadScheduledIds(String fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return [];
    final all = _decode(raw);
    final ids = all[fieldId];
    if (ids == null) return [];
    return List<int>.from(ids as List);
  }

  Future<void> _clearScheduledIds(String fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return;
    final all = Map<String, dynamic>.from(_decode(raw));
    all.remove(fieldId);
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
