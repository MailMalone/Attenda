import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PeriodEntry {
  final String subjectCode;
  final String subjectName;
  final String alias;
  final bool isSL;
  final bool isPractical;
  final bool isFree;

  const PeriodEntry({
    required this.subjectCode,
    required this.subjectName,
    required this.alias,
    this.isSL = false,
    this.isPractical = false,
    this.isFree = false,
  });

  String get displayName {
    if (isFree) return 'Free Period';
    return alias.isNotEmpty ? alias : subjectCode;
  }

  Map<String, dynamic> toJson() => {
        'subjectCode': subjectCode,
        'subjectName': subjectName,
        'alias': alias,
        'isSL': isSL,
        'isPractical': isPractical,
        'isFree': isFree,
      };

  factory PeriodEntry.fromJson(Map<String, dynamic> j) => PeriodEntry(
        subjectCode: j['subjectCode'] ?? '',
        subjectName: j['subjectName'] ?? '',
        alias: j['alias'] ?? '',
        isSL: j['isSL'] == true,
        isPractical: j['isPractical'] == true,
        isFree: j['isFree'] == true,
      );

  PeriodEntry copyWith({
    String? subjectCode,
    String? subjectName,
    String? alias,
    bool? isSL,
    bool? isPractical,
    bool? isFree,
  }) =>
      PeriodEntry(
        subjectCode: subjectCode ?? this.subjectCode,
        subjectName: subjectName ?? this.subjectName,
        alias: alias ?? this.alias,
        isSL: isSL ?? this.isSL,
        isPractical: isPractical ?? this.isPractical,
        isFree: isFree ?? this.isFree,
      );
}

class TimetableService {
  static const _key = 'timetable_data_v2';

  static Future<void> save(Map<String, List<PeriodEntry>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = data.map(
      (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(_key, jsonEncode(encoded));
  }

  static Future<Map<String, List<PeriodEntry>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(
          k,
          (v as List).map((e) => PeriodEntry.fromJson(e as Map<String, dynamic>)).toList(),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
