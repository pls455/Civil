import 'package:sqflite/sqflite.dart';

class SearchQuery {
  final String name;
  final String father;
  final String grandfather;
  final String family;
  final String identity;

  const SearchQuery({
    this.name = '',
    this.father = '',
    this.grandfather = '',
    this.family = '',
    this.identity = '',
  });

  bool get isEmpty =>
      name.isEmpty &&
      father.isEmpty &&
      grandfather.isEmpty &&
      family.isEmpty &&
      identity.isEmpty;
}

class SearchEngine {
  final Database db;
  SearchEngine(this.db);

  Future<List<Map<String, Object?>>> search(
    SearchQuery query, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (query.isEmpty) return <Map<String, Object?>>[];

    final conditions = <String>[];
    final arguments = <Object?>[];

    void addTextCondition(String column, String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      conditions.add('"$column" LIKE ?');
      arguments.add('%$trimmed%');
    }

    final identity = query.identity.trim();
    if (identity.isNotEmpty) {
      conditions.add('CAST("الهوية" AS TEXT) LIKE ?');
      arguments.add('%$identity%');
    }

    addTextCondition('الاسم', query.name);
    addTextCondition('الاب', query.father);
    addTextCondition('الجد', query.grandfather);
    addTextCondition('العائلة', query.family);

    arguments.add(limit);
    arguments.add(offset);

    return db.rawQuery(
      'SELECT * FROM "Sgaza" '
      'WHERE ${conditions.join(' AND ')} '
      'LIMIT ? OFFSET ?',
      arguments,
    );
  }
}
