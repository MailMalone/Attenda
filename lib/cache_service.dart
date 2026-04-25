import 'package:shared_preferences/shared_preferences.dart';
import 'models/student_data.dart';

class CacheService {
  static const _keyStudentData = 'cached_student_data';
  static const _keyLastUpdated = 'cached_last_updated';

  /// Save StudentData to SharedPreferences and a physical JSON file.
  static Future<void> saveStudentData(StudentData data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = data.toJsonString();
    await prefs.setString(_keyStudentData, jsonStr);
    await prefs.setString(_keyLastUpdated, DateTime.now().toIso8601String());
  }

  /// Load StudentData from SharedPreferences. Returns null if nothing cached.
  static Future<StudentData?> loadStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyStudentData);
    return StudentData.fromJsonString(raw);
  }

  /// Returns a human-friendly "Last updated X ago" string, or null if never cached.
  static Future<String?> lastUpdatedLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastUpdated);
    if (raw == null) return null;
    try {
      final dt = DateTime.parse(raw);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Updated just now';
      if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
      return 'Updated ${diff.inDays}d ago';
    } catch (_) {
      return null;
    }
  }

  /// Clear cached student data (called on logout).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStudentData);
    await prefs.remove(_keyLastUpdated);
  }
}
