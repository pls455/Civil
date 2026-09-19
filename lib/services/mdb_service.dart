import 'package:flutter/services.dart';

class MdbService {
  static const _channel = MethodChannel('civil/mdb');

  Future<Map<String, dynamic>> importMdb({required String sourcePath, required String outputPath}) async {
    final result = await _channel.invokeMethod<dynamic>('importMdb', {'sourcePath': sourcePath, 'outputPath': outputPath});
    return Map<String, dynamic>.from(result as Map);
  }
}
