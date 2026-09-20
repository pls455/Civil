import 'package:sqflite/sqflite.dart';

class SearchQuery {
  final String name;
  final String father;
  final String grandfather;
  final String family;
  final String identity;
  final String? provinceCode;
  final String? areaCode;

  const SearchQuery({
    this.name = '',
    this.father = '',
    this.grandfather = '',
    this.family = '',
    this.identity = '',
    this.provinceCode,
    this.areaCode,
  });

  bool get isEmpty =>
      name.trim().isEmpty &&
      father.trim().isEmpty &&
      grandfather.trim().isEmpty &&
      family.trim().isEmpty &&
      identity.trim().isEmpty &&
      (provinceCode == null || provinceCode!.trim().isEmpty) &&
      (areaCode == null || areaCode!.trim().isEmpty);
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

    final provinceCode = query.provinceCode?.trim();
    if (provinceCode != null && provinceCode.isNotEmpty) {
      conditions.add('CAST("رمز المحافظة" AS TEXT) = ?');
      arguments.add(provinceCode);
    }

    final areaCode = query.areaCode?.trim();
    if (areaCode != null && areaCode.isNotEmpty) {
      conditions.add('CAST("رمز المنطقة" AS TEXT) = ?');
      arguments.add(areaCode);
    }

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
