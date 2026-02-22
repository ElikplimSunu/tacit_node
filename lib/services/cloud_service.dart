import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Handles cloud escalation to Gemini API for complex diagnostics.
class CloudService {
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// Sends an image + query to Gemini for deep diagnostic analysis.
  /// Returns the model's text response.
  Future<String> escalateToCloud({
    required String base64Image,
    required String query,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    final uri = Uri.parse('$_baseUrl?key=$_apiKey');

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'You are TacitNode, an expert industrial field copilot. '
                  'A junior technician is asking for help diagnosing equipment. '
                  'Analyze the image and provide a clear, actionable diagnosis.\n\n'
                  'Technician query: $query',
            },
            {
              'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image},
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 1024},
    });

    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts = candidates[0]['content']?['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'] as String? ?? 'No response text.';
        }
      }
      return 'Empty response from Gemini.';
    } else {
      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }
  }

  /// Sends a text-only query to Gemini (no image).
  Future<String> queryCloud({required String query}) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    final uri = Uri.parse('$_baseUrl?key=$_apiKey');

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'You are TacitNode, an expert industrial field copilot. '
                  'Provide clear, actionable guidance.\n\n'
                  'Technician query: $query',
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 1024},
    });

    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts = candidates[0]['content']?['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'] as String? ?? 'No response text.';
        }
      }
      return 'Empty response from Gemini.';
    } else {
      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }
  }
}
