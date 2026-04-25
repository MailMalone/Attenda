import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SubjectAliasService {
  static const _key = 'subject_aliases_v1';

  static Future<void> save(Map<String, String> aliases) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(aliases));
  }

  static Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
