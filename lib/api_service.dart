import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'models/student_data.dart';
 
class ApiService {
  final String _baseUrl = 'https://studentportal.universitysolutions.in';
  String _cookie = '';
 
  void _updateCookie(http.Response response) {
    final rawCookie = response.headers['set-cookie'];
    if (rawCookie == null) return;
 
    // Parse existing cookies into a map so newer values overwrite older ones
    final Map<String, String> cookieMap = {};
    if (_cookie.isNotEmpty) {
      for (var c in _cookie.split(';')) {
        final parts = c.trim().split('=');
        if (parts.length >= 2) {
          cookieMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
        }
      }
    }
 
    // Merge new cookies — each Set-Cookie header is separated by commas
    for (var raw in rawCookie.split(',')) {
      final cookiePart = raw.split(';')[0];
      final parts = cookiePart.trim().split('=');
      if (parts.length >= 2) {
        cookieMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }
 
    _cookie = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
 
  Map<String, String> get _headers => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'X-Requested-With': 'XMLHttpRequest',
        if (_cookie.isNotEmpty) 'Cookie': _cookie,
      };
 
  Map<String, String> get _formHeaders => {
        ..._headers,
        'Content-Type': 'application/x-www-form-urlencoded',
      };
 
  // ─── HTML table parser (for IA Marks) ─────────────────────────────────────
 
  Map<String, dynamic> _parseHtmlTable(String htmlString) {
    if (htmlString.isEmpty) return {'headers': [], 'rows': []};
 
    final table = parse(htmlString).querySelector('table');
    if (table == null) return {'headers': [], 'rows': []};
 
    final headers = table
        .querySelectorAll('th')
        .map((th) => th.text.trim())
        .toList();
 
    final rows = table
        .querySelectorAll('tr')
        .map((tr) {
          final cells = tr.querySelectorAll('td');
          if (cells.isEmpty) return null;
          return cells.map((td) => td.text.trim()).toList();
        })
        .whereType<List<String>>()
        .toList();
 
    return {'headers': headers, 'rows': rows};
  }
 
 
  // ─── Main login + data fetch ───────────────────────────────────────────────
 
  Future<StudentData> loginAndGetData(String regno, String passwd) async {
    // 1. Login
    final loginResp = await http.post(
      Uri.parse('$_baseUrl/signin.php'),
      headers: _formHeaders,
      body: {'regno': regno, 'passwd': passwd},
    );
    _updateCookie(loginResp);
 
    final loginJson = jsonDecode(loginResp.body);
    if (loginJson['error_code'].toString() != '0') {
      throw Exception(loginJson['msg'] ?? 'Invalid credentials');
    }
 
    // 2. Get UNIVCODE
    final menuResp = await http.post(
      Uri.parse('$_baseUrl/src/getMenus.php'),
      headers: _formHeaders,
    );
    _updateCookie(menuResp);
 
    final menuJson = jsonDecode(menuResp.body);
    final univcode = menuJson['UNIVCODE']?.toString();
    if (univcode == null || univcode.isEmpty) {
      throw Exception('Could not retrieve UNIVCODE');
    }
 
    // 3. Warm up the attendance session (portal requires this page load)
    final warmupResp = await http.get(
      Uri.parse('$_baseUrl/html_modules/attendancenew.html'),
      headers: _headers,
    );
    _updateCookie(warmupResp);
 
    // 4–6. Fire metadata, attendance, and IA marks concurrently
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
 
    final results = await Future.wait([
      // 1. Attendance summary
      http.post(
        Uri.parse('$_baseUrl/app.php?a=viewAttendanceDetsummary&univcode=$univcode'),
        headers: _formHeaders,
        body: {'date': todayStr},
      ),
      // 2. IA Marks
      http.get(
        Uri.parse('$_baseUrl/app.php?a=viewIaMarksNew&univcode=$univcode'),
        headers: _headers,
      ),
      // 3. Student metadata (Still fetch for the name, but don't parse semester)
      http.get(
        Uri.parse('$_baseUrl/app.php?a=viewdatewiseatt&univcode=$univcode'),
        headers: _headers,
      ),
    ]);
 
    // Parse name from metadata (but ignore semester)
    String studentName = menuJson['FUNIVNAME'] ?? 'Student';
    try {
      final metaJson = jsonDecode(results[2].body);
      if (metaJson['error_code'].toString() == '0') {
        final data = metaJson['data'] as Map<String, dynamic>? ?? {};
        final portalName = data['fname']?.toString() ?? '';
        if (portalName.isNotEmpty) studentName = portalName;
      }
    } catch (_) {}
 
    // Parse attendance
    List<dynamic> attendanceData = [];
    try {
      final attJson = jsonDecode(results[0].body);
      if (attJson['error_code'].toString() == '0') {
        attendanceData = attJson['data'] ?? [];
      }
    } catch (_) {}
 
    // Parse IA marks
    Map<String, dynamic> iaMarksParsed = {};
    try {
      final iaJson = jsonDecode(results[1].body);
      if (iaJson['error_code'].toString() == '0') {
        final rawHtml = iaJson['data']['marks'] ?? '';
        iaMarksParsed = _parseHtmlTable(rawHtml);
      }
    } catch (_) {}
 
    return StudentData(
      name: studentName,
      univCode: univcode,
      attendance: attendanceData,
      iaMarks: iaMarksParsed,
    );
  }
}
 