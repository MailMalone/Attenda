import 'dart:convert';
import 'package:http/http.dart' as http;
import 'timetable_service.dart';

class TimetableLoaderService {
  static Future<Map<String, List<PeriodEntry>>> fetchAndParse({
    required String url,
    required String semester,
    required String section,
    required List<Map<String, dynamic>> attendanceSubjects,
    required Map<String, String> subjectAliases,
  }) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch timetable from server');
    }

    final data = jsonDecode(response.body);
    
    // Support both nested and flat JSON formats
    Map<String, dynamic>? secData;
    if (data.containsKey('semesters')) {
      secData = data['semesters']?[semester]?['sections']?[section.toUpperCase()];
    } else {
      // Assume the root of the JSON is the timetable for this section
      secData = data as Map<String, dynamic>;
    }

    if (secData == null) {
      throw Exception('No timetable data found for Sem $semester Section $section');
    }

    final Map<String, List<PeriodEntry>> timetable = {};
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    for (var day in days) {
      final List<dynamic> dayPeriods = secData[day] ?? [];
      timetable[day] = dayPeriods.map((p) {
        if (p['type'] == 'free') {
          return const PeriodEntry(
            subjectCode: '',
            subjectName: 'Free Period',
            alias: '',
            isFree: true,
          );
        }

        final code = p['code']?.toString() ?? '';
        final type = p['type']?.toString().toLowerCase() ?? '';
        final jsonAlias = p['alias']?.toString() ?? '';
        final isPrac = type == 'practical' || type == 'p';
        final isSL = type == 'sl';

        // Try to find full name from attendance and check if it's a practical
        String name = '';
        bool isPracFromAttendance = false;
        try {
          final sub = attendanceSubjects.firstWhere(
            (s) => s['fsubcode']?.toString() == code,
            orElse: () => {},
          );
          name = sub['fsubname']?.toString() ?? '';
          if (name.toLowerCase().contains('practical')) {
            isPracFromAttendance = true;
          }
        } catch (_) {}

        return PeriodEntry(
          subjectCode: code,
          subjectName: name,
          alias: jsonAlias.isNotEmpty ? jsonAlias : (subjectAliases[name] ?? ''),
          isSL: isSL,
          isPractical: isPrac || isPracFromAttendance,
        );
      }).toList();
    }

    return timetable;
  }
}
