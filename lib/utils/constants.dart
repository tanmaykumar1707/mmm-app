import 'dart:math';
import 'package:flutter/material.dart';

const kPrimary      = Color(0xFF4F46E5);   // indigo
const kPrimaryLight = Color(0xFF818CF8);   // soft indigo
const kPrimaryDark  = Color(0xFF3730A3);   // deep indigo
const kAccent    = Color(0xFF00C853);   // green
const kWarn      = Color(0xFFFFA726);   // orange/amber
const kDanger    = Color(0xFFEF5350);   // red
const kBlue      = Color(0xFF2563EB);
const kBg        = Color(0xFFF4F6FB);
const kCard      = Colors.white;
const kTextDark  = Color(0xFF111827);
const kTextMid   = Color(0xFF4B5563);
const kTextLight = Color(0xFF9CA3AF);

const List<Color> kCardColors = [
  Color(0xFF2563EB),
  Color(0xFF7C3AED),
  Color(0xFFDC2626),
  Color(0xFF059669),
  Color(0xFFD97706),
  Color(0xFF0891B2),
  Color(0xFFDB2777),
  Color(0xFFEA580C),
];

const List<String> kCategories = [
  'Housing', 'Utilities', 'Food', 'Entertainment',
  'Insurance', 'Transport', 'Health', 'Education', 'Other'
];

const List<String> kMonths = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December'
];

String formatINR(double n) {
  if (n >= 100000) return '₹${(n/100000).toStringAsFixed(1)}L';
  if (n >= 1000)   return '₹${(n/1000).toStringAsFixed(1)}K';
  return '₹${n.toStringAsFixed(0)}';
}

String formatINRFull(double n) {
  final s = n.toStringAsFixed(0);
  // Indian number format
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  for (int i = rest.length; i > 0; i -= 2) {
    parts.insert(0, rest.substring(i < 2 ? 0 : i - 2, i));
  }
  return '₹${parts.join(',')},${last3}';
}

String monthKey(int year, int month) =>
    '$year-${month.toString().padLeft(2, '0')}';

final _genIdRng = Random.secure();
String genId() {
  final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final rnd = List.generate(6, (_) => _genIdRng.nextInt(36).toRadixString(36)).join();
  return '$ts$rnd';
}
