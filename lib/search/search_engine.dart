import 'package:sqflite/sqflite.dart';

class SearchEngine {
  final Database db;
  SearchEngine(this.db);

  Future<List<Map<String, Object?>>> search(
    String query, {
    int limit = 50,
    int offset = 0,
  }) async {
    final value = query.trim();
    if (value.isEmpty) return <Map<String, Object?>>[];

    return db.rawQuery(
      'SELECT * FROM "Sgaza" '
      'WHERE CAST("الهوية" AS TEXT) LIKE ? '
      'OR "الاسم" LIKE ? '
      'OR "الاب" LIKE ? '
      'OR "الجد" LIKE ? '
      'OR "العائلة" LIKE ? '
      'OR "اسم الام" LIKE ? '
      'LIMIT ? OFFSET ?',
      [
        '%$value%',
        '%$value%',
        '%$value%',
        '%$value%',
        '%$value%',
        '%$value%',
        limit,
        offset,
      ],
    );
  }
}
