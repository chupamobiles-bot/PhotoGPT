import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

// dart:io only on non-web
import 'ai_service_io.dart' if (dart.library.html) 'ai_service_web.dart';

class AiService {
  static const String _backendUrl = 'https://photogpt-backend.onrender.com';
  static const String _prefApiKey  = 'byok_api_key';
  static const String _prefDeviceId = 'device_id_cached';

  // ── Device ID ─────────────────────────────────────────────────────────────
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefDeviceId);
    if (cached != null && cached.isNotEmpty) return cached;
    final id = await getPlatformDeviceId();
    await prefs.setString(_prefDeviceId, id);
    return id;
  }

  // ── BYOK key ──────────────────────────────────────────────────────────────
  static Future<String?> getSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefApiKey);
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, key.trim());
  }

  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefApiKey);
  }

  // ── Image → base64 (works on all platforms) ───────────────────────────────
  static Future<String> xfileToBase64(XFile file) async {
    final bytes = await file.readAsBytes();
    return _compressAndEncode(bytes);
  }

  static Future<String> bytesToBase64(Uint8List bytes) async {
    return _compressAndEncode(bytes);
  }

  static Future<String> _compressAndEncode(Uint8List bytes) async {
    if (kIsWeb) {
      // Skip compression on web — image package may not decode all formats
      return base64Encode(bytes);
    }
    try {
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return base64Encode(bytes);
      if (decoded.width > 1024) {
        decoded = img.copyResize(decoded, width: 1024);
      }
      return base64Encode(img.encodeJpg(decoded, quality: 80));
    } catch (_) {
      return base64Encode(bytes);
    }
  }

  // ── Main analyze call ─────────────────────────────────────────────────────
  static Future<AnalyzeResult> analyze({
    required XFile imageFile,
    required String question,
  }) async {
    final apiKey = await getSavedApiKey();
    final imageB64 = await xfileToBase64(imageFile);

    if (apiKey != null && apiKey.isNotEmpty) {
      return _analyzeDirectGroq(imageB64: imageB64, question: question, apiKey: apiKey);
    }
    return _analyzeViaBackend(imageB64: imageB64, question: question);
  }

  // ── Direct Groq vision call (BYOK) ────────────────────────────────────────
  static Future<AnalyzeResult> _analyzeDirectGroq({
    required String imageB64,
    required String question,
    required String apiKey,
  }) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final body = jsonEncode({
      'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
      'messages': [{
        'role': 'user',
        'content': [
          {'type': 'text', 'text': question},
          {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$imageB64'}},
        ],
      }],
      'max_tokens': 1024,
    });

    final response = await http.post(url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['choices'][0]['message']['content'] as String;
      return AnalyzeResult(answer: text, remaining: 999, byok: true);
    } else if (response.statusCode == 401) {
      throw InvalidKeyException('Invalid Groq API key. Check Settings.');
    } else {
      final err = jsonDecode(response.body);
      throw AiException(err['error']?['message'] as String? ?? 'Groq error ${response.statusCode}');
    }
  }

  // ── Backend call (free tier) ───────────────────────────────────────────────
  static Future<AnalyzeResult> _analyzeViaBackend({
    required String imageB64,
    required String question,
  }) async {
    final deviceId = await getDeviceId();
    final body = jsonEncode({'deviceId': deviceId, 'image': imageB64, 'question': question});

    final response = await http.post(
      Uri.parse('$_backendUrl/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 30));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return AnalyzeResult(
        answer: data['answer'] as String,
        remaining: (data['remaining'] as num).toInt(),
        byok: false,
      );
    } else if (response.statusCode == 429) {
      throw LimitReachedException(data['error'] as String? ?? 'Daily limit reached');
    } else {
      throw AiException(data['error'] as String? ?? 'Backend error ${response.statusCode}');
    }
  }

  // ── Remaining quota ────────────────────────────────────────────────────────
  static Future<int> remaining() async {
    final deviceId = await getDeviceId();
    try {
      final response = await http
          .get(Uri.parse('$_backendUrl/remaining?deviceId=$deviceId'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['remaining'] as num).toInt();
    } catch (_) {
      return -1;
    }
  }
}

class AnalyzeResult {
  final String answer;
  final int remaining;
  final bool byok;
  const AnalyzeResult({required this.answer, required this.remaining, required this.byok});
}

class LimitReachedException implements Exception {
  final String message;
  const LimitReachedException(this.message);
  @override String toString() => message;
}

class InvalidKeyException implements Exception {
  final String message;
  const InvalidKeyException(this.message);
  @override String toString() => message;
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override String toString() => message;
}
