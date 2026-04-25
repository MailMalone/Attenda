import 'dart:convert';

class StudentData {
  final String name;
  final String univCode;
  final List<dynamic> attendance;
  final Map<String, dynamic> iaMarks;

  StudentData({
    required this.name,
    required this.univCode,
    required this.attendance,
    required this.iaMarks,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'univCode': univCode,
        'attendance': attendance,
        'iaMarks': iaMarks,
      };

  factory StudentData.fromJson(Map<String, dynamic> json) {
    return StudentData(
      name: json['name'] ?? '',
      univCode: json['univCode'] ?? '',
      attendance: json['attendance'] as List<dynamic>? ?? [],
      iaMarks: Map<String, dynamic>.from(json['iaMarks'] ?? {}),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static StudentData? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return StudentData.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
