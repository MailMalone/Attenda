import 'dart:convert';
import 'package:http/http.dart' as http;


class CloudStorageService {
  static const String _githubUsername = 'MailMalone';
  static const String _githubRepo = 'Attenda-Timetables';
  
  // Use the raw content URL to bypass API rate limits
  static const String _baseUrl = 'https://raw.githubusercontent.com/$_githubUsername/$_githubRepo/main/Notes';

  /// Fetches the manifest file containing all notes mapping.
  /// Format: { "subjectCode": [ { "name": "...", "url": "..." } ] }
  static Future<Map<String, dynamic>> fetchNotesManifest() async {
    try {
      final url = Uri.parse('$_baseUrl/notes_index.json');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        // Manifest not found yet
        return {};
      } else {
        throw Exception('Failed to load notes index. Status: ${response.statusCode}');
      }
    } catch (e) {
      return {};
    }
  }

  /// This is now a helper to filter the manifest for a specific subject
  static List<Map<String, String>> getPdfsForSubjectFromManifest(Map<String, dynamic> manifest, String subjectCode) {
    if (!manifest.containsKey(subjectCode)) return [];
    
    final List<dynamic> list = manifest[subjectCode];
    return list.map((item) => {
      'name': item['name'].toString(),
      'url': item['url'].toString(),
    }).toList();
  }
}
