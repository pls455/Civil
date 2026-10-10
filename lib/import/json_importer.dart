import 'dart:convert';
import 'dart:io';

class JsonImporter {
  Future<List<Map<String, dynamic>>> read(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is List) {
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (decoded is Map && decoded['rows'] is List) {
      return (decoded['rows'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw const FormatException('JSON schema غير مدعوم: المتوقع مصفوفة أو {rows:[...]}');
  }
}
