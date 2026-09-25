import 'dart:io';
import 'package:sqflite/sqflite.dart';

class SqliteImporter {
  Future<Map<String, dynamic>> inspect(String path) async {
    if (!File(path).existsSync()) throw Exception('الملف غير موجود');
    final source = await openDatabase(path, readOnly: true);
    try {
      final rows = await source.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
      return {'tables': rows.map((e) => e['name']).toList()};
    } finally {
      await source.close();
    }
  }
}
