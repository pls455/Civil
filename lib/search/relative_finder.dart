import 'package:sqflite/sqflite.dart';

import '../core/utils/arabic_normalizer.dart';

enum RelativeType {
  father,
  grandfather,
  children,
  siblings,
  extendedFamily,
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

    if (identity.isEmpty) return const [];

    final candidates = <String, RelativeCandidate>{};

    Future<void> addMatches(
      RelativeType type,
      String sql,
      List<Object?> args,
    ) async {
      final rows = await db.rawQuery(sql, args);
      for (final row in rows) {
        final rowIdentity = _value(row, 'الهوية');
        if (rowIdentity.isEmpty || rowIdentity == identity) continue;
        candidates['$type:$rowIdentity'] =
            RelativeCandidate(type: type, person: row);
      }
    }

    // The strongest available parent relation in this schema:
    // the candidate's name is the current person's recorded father,
    // while the candidate's father/grandfather fields continue the chain.
    if (fatherName.isNotEmpty &&
        grandfatherName.isNotEmpty &&
        family.isNotEmpty) {
      final rows = await db.rawQuery(
        'SELECT * FROM "Sgaza" '
        'WHERE "الاسم" = ? '
        'AND "العائلة" = ? '
        'AND "الجد" = ?',
        [fatherName, family, grandfatherName],
      );
      if (rows.length == 1) {
        await addMatches(
          RelativeType.father,
          'SELECT * FROM "Sgaza" WHERE "الهوية" = ?',
          [_value(rows.first, 'الهوية')],
        );
      }
    }

    // The same chain lets us resolve the recorded grandfather through
    // the candidate father, when the database contains that person.
    if (grandfatherName.isNotEmpty &&
        fatherName.isNotEmpty &&
        family.isNotEmpty) {
      final rows = await db.rawQuery(
        'SELECT * FROM "Sgaza" '
        'WHERE "الاسم" = ? '
        'AND "الاب" = ? '
        'AND "العائلة" = ?',
        [grandfatherName, fatherName, family],
      );
      if (rows.length == 1) {
        await addMatches(
          RelativeType.grandfather,
          'SELECT * FROM "Sgaza" WHERE "الهوية" = ?',
          [_value(rows.first, 'الهوية')],
        );
      }
    }

    // Same father + grandfather + family is the strongest available
    // evidence for people belonging to the same immediate sibling group.
    if (fatherName.isNotEmpty &&
        grandfatherName.isNotEmpty &&
        family.isNotEmpty) {
      await addMatches(
        RelativeType.siblings,
        'SELECT * FROM "Sgaza" '
        'WHERE "الهوية" != ? '
        'AND "الاب" = ? '
        'AND "الجد" = ? '
        'AND "العائلة" = ?',
        [identity, fatherName, grandfatherName, family],
      );
    }

    // If the current person is a parent, this reverses the same relation
    // and finds records that name them as their father.
    if (name.isNotEmpty && grandfatherName.isNotEmpty && family.isNotEmpty) {
      await addMatches(
        RelativeType.children,
        'SELECT * FROM "Sgaza" '
        'WHERE "الهوية" != ? '
        'AND "الاب" = ? '
        'AND "الجد" = ? '
        'AND "العائلة" = ?',
        [identity, name, fatherName, family],
      );
    }

    // Shared grandfather with a different father is useful evidence of a
    // wider family connection, but is deliberately not called "cousin".
    if (grandfatherName.isNotEmpty && family.isNotEmpty) {
      await addMatches(
        RelativeType.extendedFamily,
        'SELECT * FROM "Sgaza" '
        'WHERE "الهوية" != ? '
        'AND "الجد" = ? '
        'AND "العائلة" = ? '
        'AND "الاب" != ?',
        [identity, grandfatherName, fatherName],
      );
    }

    return candidates.values.toList();
  }

  static String _value(Map<String, Object?> row, String key) {
    return ArabicNormalizer.normalize(row[key]?.toString());
  }
}
