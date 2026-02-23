import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

/// Handles cloud escalation to Gemini API for complex diagnostics.
class CloudService {
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent';

  static const _maxRetries = 2;

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// Sends an image + query to Gemini for deep diagnostic analysis.
  Future<String> escalateToCloud({
    required String base64Image,
    required String query,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'You are TacitNode, an expert industrial field copilot. '
                  'A junior technician needs help diagnosing equipment. '
                  'Provide a CONCISE, actionable diagnosis in 2-3 sentences max.\n\n'
                  'Query: $query',
            },
            {
              'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image},
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 300, // Limit for concise responses
      },
    });

    return _postWithRetry(body);
  }

  /// Sends a text-only query to Gemini (no image).
  Future<String> queryCloud({required String query}) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'You are TacitNode, an expert industrial field copilot. '
                  'Provide CONCISE, actionable guidance in 2-3 sentences max.\n\n'
                  'Query: $query',
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 300, // Limit for concise responses
      },
    });

    return _postWithRetry(body);
  }

  /// Posts to Gemini API with automatic retry on 429 (rate limit) errors.
  Future<String> _postWithRetry(String body) async {
    final uri = Uri.parse('$_baseUrl?key=$_apiKey');

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return _extractText(response.body);
      }

      if (response.statusCode == 429 && attempt < _maxRetries) {
        // Extract retry delay from response, default to 12 seconds
        final retrySeconds = _parseRetryDelay(response.body);
        TLog.warn(
          'Rate limited (429). Retrying in ${retrySeconds}s '
          '(attempt ${attempt + 1}/$_maxRetries)',
        );
        await Future.delayed(Duration(seconds: retrySeconds));
        continue;
      }

      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }

    throw Exception('Gemini API failed after $_maxRetries retries');
  }

  /// Extracts the text response from a successful Gemini API response.
  String _extractText(String responseBody) {
    final data = jsonDecode(responseBody);
    final candidates = data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        return parts[0]['text'] as String? ?? 'No response text.';
      }
    }
    return 'Empty response from Gemini.';
  }

  /// Parses the retry delay from a 429 response body.
  int _parseRetryDelay(String body) {
    try {
      final match = RegExp(r'"retryDelay":\s*"(\d+)s"').firstMatch(body);
      if (match != null) {
        return int.parse(match.group(1)!) + 1; // add 1s buffer
      }
    } catch (_) {}
    return 12; // default wait
  }
}
