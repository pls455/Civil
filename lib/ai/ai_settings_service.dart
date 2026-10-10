import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiSettingsService {
  static const _geminiApiKey = 'gemini_api_key';

  final FlutterSecureStorage _storage;

  AiSettingsService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> readGeminiApiKey() {
    return _storage.read(key: _geminiApiKey);
  }

  Future<void> saveGeminiApiKey(String value) async {
    final key = value.trim();
    if (key.isEmpty) {
      throw ArgumentError('مفتاح Gemini فارغ.');
    }
    await _storage.write(key: _geminiApiKey, value: key);
  }

  Future<void> deleteGeminiApiKey() {
    return _storage.delete(key: _geminiApiKey);
  }
}
