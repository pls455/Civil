import 'dart:convert';
import 'dart:io';

class GeminiApiException implements Exception {
  final String message;
  final int? statusCode;

  const GeminiApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class GeminiClient {
  static const model = 'gemini-3.8-flash';
  static const endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/' +
      model +
      ':generateContent';

  final HttpClient _client;

  GeminiClient({HttpClient? client}) : _client = client ?? HttpClient();

  Future<String> generateText({
    required String apiKey,
    required String prompt,
  }) async {
    final key = apiKey.trim();
    final requestPrompt = prompt.trim();

    if (key.isEmpty) {
      throw const GeminiApiException('مفتاح Gemini غير مُدخل.');
    }
    if (requestPrompt.isEmpty) {
      throw const GeminiApiException('طلب Gemini فارغ.');
    }

    final request = await _client
        .postUrl(Uri.parse(endpoint))
        .timeout(const Duration(seconds: 15));

    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set('x-goog-api-key', key);

    request.add(
      utf8.encode(
        jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': requestPrompt},
              ],
            },
          ],
        }),
      ),
    );

    final response =
        await request.close().timeout(const Duration(seconds: 30));
    final body = await response.transform(utf8.decoder).join();

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw GeminiApiException(
        'استجابة Gemini غير صالحة.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200 || decoded is! Map<String, dynamic>) {
      final error =
          decoded is Map<String, dynamic> ? decoded['error'] : null;
      final message = error is Map<String, dynamic>
          ? error['message']?.toString().trim()
          : null;

      throw GeminiApiException(
        message?.isNotEmpty == true
            ? message!
            : 'فشل اتصال Gemini (HTTP ' +
                response.statusCode.toString() +
                ').',
        statusCode: response.statusCode,
      );
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const GeminiApiException('Gemini لم يُرجع نتيجة.');
    }

    final firstCandidate = candidates.first;
    if (firstCandidate is! Map<String, dynamic>) {
      throw const GeminiApiException('صيغة نتيجة Gemini غير متوقعة.');
    }

    final content = firstCandidate['content'];
    if (content is! Map<String, dynamic>) {
      throw const GeminiApiException('Gemini أعاد استجابة بلا محتوى.');
    }

    final parts = content['parts'];
    if (parts is! List) {
      throw const GeminiApiException('Gemini أعاد محتوى بلا نص.');
    }

    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        final text = part['text']?.toString();
        if (text != null && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
    }

    throw const GeminiApiException('Gemini لم يُرجع نصاً.');
  }

  Future<void> testConnection({required String apiKey}) async {
    await generateText(
      apiKey: apiKey,
      prompt:
          'أجب بكلمة واحدة فقط: متصل. هذا اختبار اتصال تقني ولا يحتوي على بيانات مواطنين.',
    );
  }

  void close() => _client.close(force: true);
}
