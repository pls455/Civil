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

    // Resolve the recorded father only when name + father + family
    // identifies exactly one person. Names by themselves are not identities.
    Map<String, Object?>? father;
    if (fatherName.isNotEmpty &&
        grandfatherName.isNotEmpty &&
        family.isNotEmpty) {
      father = await _findUniquePerson(
        name: fatherName,
        father: grandfatherName,
        family: family,
        grandfather: '',
      );
      if (father != null) {
        addMatch(RelativeType.father, father);
      }
    }

    // Follow the identified father record to resolve the grandfather.
    Map<String, Object?>? grandfather;
    if (father != null) {
      final father'sFather = _value(father, 'الاب');
      final father'sGrandfather = _value(father, 'الجد');
      final father'sFamily = _value(father, 'العائلة');

      if (father'sGrandfather.isNotEmpty &&
          father'sFather.isNotEmpty &&
          father'sFamily.isNotEmpty) {
        grandfather = await _findUniquePerson(
          name: father'sGrandfather,
          father: father'sFather,
          family: father'sFamily,
        );
        if (grandfather != null) {
          addMatch(RelativeType.grandfather, grandfather);
        }
      }
    }

    // Siblings are accepted only after the current person's father has been
    // uniquely identified. The father itself is excluded from this group.
    if (father != null &&
        fatherName.isNotEmpty &&
        grandfatherName.isNotEmpty &&
        family.isNotEmpty) {
      final rows = await db.rawQuery(
        'SELECT * FROM "Sgaza" '
        'WHERE "الهوية" != ? '
        'AND "الهوية" != ? '
        'AND "الاب" = ? '
        'AND "الجد" = ? '
        'AND "العائلة" = ? '
        'AND "اسم الام" = ?',
        [
          identity,
          _value(father, 'الهوية'),
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

    // Children are accepted only when the current person itself is uniquely
    // identified by the same genealogical fields stored for its father.
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
      'SELECT * FROM "Sgaza" WHERE ' + conditions.join(' AND '),
      arguments,
    );

    return rows.length == 1 ? rows.first : null;
  }

  static String _value(Map<String, Object?> row, String key) {
    return ArabicNormalizer.normalize(row[key]?.toString());
  }
}
