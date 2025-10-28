import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/message.dart' as models;

class ApiService {
  // IMPORTANT: Change this to your Mac's IP address for physical devices
  static String get baseUrl {
    if (Platform.isAndroid) {
      // For Android Emulator: use 10.0.2.2
      // For Physical Android Device: use your Mac's IP (e.g., 192.168.1.100)
      return 'http://192.168.1.5:8000/api/v1';  // ⚠️ CHANGE THIS TO YOUR MAC'S IP
    } else if (Platform.isIOS) {
      // For iOS Simulator: use localhost
      // For Physical iPhone: use your Mac's IP
      return 'http://localhost:8000/api/v1';
    } else {
      // macOS
      return 'http://localhost:8000/api/v1';
    }
  }

  Future<models.Message> sendQuery(String query, {List<Map<String, dynamic>>? conversationHistory}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'top_k': 3,
          'conversation_history': conversationHistory,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return models.Message.fromJson(data);
      } else {
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }

  Future<bool> uploadDocument(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );
      
      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print('Upload error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getRelatedConcepts(String conceptId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/graph/related'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'concept_id': conceptId,
          'max_depth': 2,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get related concepts');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }
}