import 'package:sqflite/sqflite.dart';

class SearchQuery {
  final String name;
  final String father;
  final String grandfather;
  final String family;
  final String identity;
  final String? provinceCode;
  final String? areaCode;
  final String? gender;
  final String? maritalStatus;
  final String? district;
  final String? neighborhood;
  final String? birthplace;
  final String? workplace;

  const SearchQuery({
    this.name = '',
    this.father = '',
    this.grandfather = '',
    this.family = '',
    this.identity = '',
    this.provinceCode,
    this.areaCode,
    this.gender,
    this.maritalStatus,
    this.district,
    this.neighborhood,
    this.birthplace,
    this.workplace,
  });

  bool get isEmpty =>
      name.trim().isEmpty &&
      father.trim().isEmpty &&
      grandfather.trim().isEmpty &&
      family.trim().isEmpty &&
      identity.trim().isEmpty &&
      (provinceCode == null || provinceCode!.trim().isEmpty) &&
      (areaCode == null || areaCode!.trim().isEmpty) &&
      (gender == null || gender!.trim().isEmpty) &&
      (maritalStatus == null || maritalStatus!.trim().isEmpty) &&
      (district == null || district!.trim().isEmpty) &&
      (neighborhood == null || neighborhood!.trim().isEmpty) &&
      (birthplace == null || birthplace!.trim().isEmpty) &&
      (workplace == null || workplace!.trim().isEmpty);
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

    void addEmployeeCondition(String column, String? value) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isEmpty) return;
      conditions.add(
        'EXISTS ('
        'SELECT 1 FROM "قائمة_الموظفين" AS e '
        'WHERE e."الهوية" = "Sgaza"."الهوية" '
        'AND e."$column" LIKE ?'
        ')',
      );
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

    addEmployeeCondition('الجنس', query.gender);
    addEmployeeCondition('الحالة الجتماعية', query.maritalStatus);
    addTextCondition('الناحية', query.district ?? '');
    addTextCondition('الحي', query.neighborhood ?? '');
    addTextCondition('مكان الميلاد', query.birthplace ?? '');
    addEmployeeCondition('مكان العمل', query.workplace);

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
