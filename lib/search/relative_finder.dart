import 'package:sqflite/sqflite.dart';

import '../core/utils/arabic_normalizer.dart';

enum RelativeType {
  father,
  grandfather,
  children,
  siblings,
}

class RelativeCandidate {
  final RelativeType type;
  final Map<String, Object?> person;

  const RelativeCandidate({
    required this.type,
    required this.person,
  });
}

class RelativeFinder {
  final Database db;

  const RelativeFinder(this.db);

  Future<List<RelativeCandidate>> findForPerson(
    Map<String, Object?> person,
  ) async {
    final identity = _value(person, 'الهوية');
    final name = _value(person, 'الاسم');
    final fatherName = _value(person, 'الاب');
    final grandfatherName = _value(person, 'الجد');
    final family = _value(person, 'العائلة');
    final motherName = _value(person, 'اسم الام');

    if (identity.isEmpty) return const [];

    final candidates = <String, RelativeCandidate>{};

    void addMatch(RelativeType type, Map<String, Object?> row) {
      final rowIdentity = _value(row, 'الهوية');
      if (rowIdentity.isEmpty || rowIdentity == identity) return;
      candidates['$type:$rowIdentity'] =
          RelativeCandidate(type: type, person: row);
    }

    Map<String, Object?>? father;
    if (fatherName.isNotEmpty &&
        grandfatherName.isNotEmpty &&
        family.isNotEmpty) {
      father = await _findUniquePerson(
        name: fatherName,
        father: grandfatherName,
        family: family,
      );
      if (father != null) {
        addMatch(RelativeType.father, father);
      }
    }

    Map<String, Object?>? grandfather;
    if (father != null) {
      final fatherFather = _value(father, 'الاب');
      final fatherGrandfather = _value(father, 'الجد');
      final fatherFamily = _value(father, 'العائلة');

      if (fatherGrandfather.isNotEmpty &&
          fatherFather.isNotEmpty &&
          fatherFamily.isNotEmpty) {
        grandfather = await _findUniquePerson(
          name: fatherGrandfather,
          father: fatherFather,
          family: fatherFamily,
        );
        if (grandfather != null) {
          addMatch(RelativeType.grandfather, grandfather);
        }
      }
    }

    if (fatherName.isNotEmpty &&
        grandfatherName.isNotEmpty &&
        family.isNotEmpty &&
        motherName.isNotEmpty) {
      final rows = await db.rawQuery(
        'SELECT * FROM "Sgaza" '
        'WHERE "الهوية" != ? '
        'AND "الاب" = ? '
        'AND "الجد" = ? '
        'AND "العائلة" = ? '
        'AND "اسم الام" = ?',
        [
          identity,
          fatherName,
          grandfatherName,
          family,
          motherName,
        ],
      );

      for (final row in rows) {
        addMatch(RelativeType.siblings, row);
      }
    }

    final currentPerson = name.isNotEmpty &&
            fatherName.isNotEmpty &&
            grandfatherName.isNotEmpty &&
            family.isNotEmpty
        ? await _findUniquePerson(
            name: name,
            father: fatherName,
            family: family,
            grandfather: grandfatherName,
          )
        : null;

    if (currentPerson != null &&
        _value(currentPerson, 'الهوية') == identity) {
      final rows = await db.rawQuery(
        'SELECT * FROM "Sgaza" '
        'WHERE "الهوية" != ? '
        'AND "الاب" = ? '
        'AND "الجد" = ? '
        'AND "العائلة" = ? '
        'AND "اسم الام" = ?',
        [identity, name, fatherName, family, motherName],
      );

      for (final row in rows) {
        addMatch(RelativeType.children, row);
      }
    }

    return candidates.values.toList();
  }

  Future<Map<String, Object?>?> _findUniquePerson({
    required String name,
    required String father,
    required String family,
    String grandfather = '',
  }) async {
    if (name.isEmpty || family.isEmpty) return null;

    final conditions = <String>[
      '"الاسم" = ?',
      '"العائلة" = ?',
      '"الاب" = ?',
    ];
    final arguments = <Object?>[name, family, father];

    if (grandfather.isNotEmpty) {
      conditions.add('"الجد" = ?');
      arguments.add(grandfather);
    }

    final rows = await db.rawQuery(
      'SELECT * FROM "Sgaza" WHERE ${conditions.join(' AND ')}',
      arguments,
    );

    return rows.length == 1 ? rows.first : null;
  }

  static String _value(Map<String, Object?> row, String key) {
    return ArabicNormalizer.normalize(row[key]?.toString());
  }
}
