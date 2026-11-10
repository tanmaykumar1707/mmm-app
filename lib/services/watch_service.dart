import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import '../models/card_model.dart';
import '../utils/constants.dart';
import 'state_provider.dart';

/// Bridges the Flutter app with the paired Apple Watch via WatchConnectivity.
/// iPhone → Watch : sends cards list + people list (applicationContext).
/// Watch → iPhone : receives new CardTxn and saves it via StateProvider.
class WatchService {
  static final instance = WatchService._();
  WatchService._();

  final _wc = WatchConnectivity();
  bool _initialized = false;

  Future<void> init(StateProvider sp) async {
    if (kIsWeb || !Platform.isIOS) return;
    if (_initialized) return;
    _initialized = true;

    // Listen for transactions sent from the watch
    _wc.messageStream.listen((msg) => _handleMessage(msg, sp));

    // Keep watch context updated when state changes
    sp.addListener(() => _syncToWatch(sp));

    // Initial sync
    await _syncToWatch(sp);
  }

  /// Pushes current cards + people to the watch applicationContext.
  Future<void> _syncToWatch(StateProvider sp) async {
    try {
      await _wc.updateApplicationContext({
        'cards': sp.state.cards
            .map((c) => {'id': c.id, 'name': c.name, 'color': c.color})
            .toList(),
        'people': sp.state.people,
      });
    } catch (e) {
      debugPrint('WatchService sync error: $e');
    }
  }

  /// Handles an incoming addTxn message from the watch.
  void _handleMessage(Map<dynamic, dynamic> msg, StateProvider sp) {
    if (msg['action'] != 'addTxn') return;

    final cardId = msg['cardId'] as String? ?? '';
    if (cardId.isEmpty) return;

    final now = DateTime.now();
    sp.addCardTxn(
      cardId,
      monthKey(now.year, now.month),
      CardTxn(
        id: genId(),
        spentFor: msg['spentFor'] as String? ?? '',
        spentBy: msg['spentBy'] as String? ?? '',
        amount: (msg['amount'] as num? ?? 0).toDouble(),
        date: msg['date'] as String? ?? now.toIso8601String().substring(0, 10),
      ),
    );
  }
}
