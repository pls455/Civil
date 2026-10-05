import 'package:sqflite/sqflite.dart';

import '../core/utils/arabic_normalizer.dart';
import 'relative_match.dart';

enum RelativeType {
  father,
  grandfather,
  children,
  siblings,
}

class RelativeCandidate {
  final RelativeType type;
  final Map<String, Object?> person;
  final String detail;

  const RelativeCandidate({
    required this.type,
    required this.person,
    this.detail = '',
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

    void addMatch(
      RelativeType type,
      Map<String, Object?> row, {
      String detail = '',
    }) {
      final rowIdentity = _value(row, 'الهوية');
      if (rowIdentity.isEmpty || rowIdentity == identity) return;
      candidates['${type.name}:$rowIdentity'] = RelativeCandidate(
        type: type,
        person: row,
        detail: detail,
      );
    }

    Map<String, Object?>? father;
    if (fatherName.isNotEmpty &&
        hasSupportingEvidence(fatherName, [grandfatherName, family])) {
      father = await _findUniquePerson(
        name: fatherName,
        father: grandfatherName,
        family: family,
      );
      if (father != null) addMatch(RelativeType.father, father);
    }

    if (father != null) {
      final fatherFather = _value(father, 'الاب');
      final fatherGrandfather = _value(father, 'الجد');
      final fatherFamily = _value(father, 'العائلة');

      if (fatherGrandfather.isNotEmpty &&
          hasSupportingEvidence(
            fatherGrandfather,
            [fatherFather, fatherFamily],
          )) {
        final grandfather = await _findUniquePerson(
          name: fatherGrandfather,
          father: fatherFather,
          family: fatherFamily,
        );
        if (grandfather != null) {
          addMatch(RelativeType.grandfather, grandfather);
        }
      }
    }

    if (hasSupportingEvidence(fatherName, [grandfatherName, family])) {
      final conditions = <String>[
        '"الهوية" != ?',
        '"الاب" = ?',
      ];
      final arguments = <Object?>[identity, fatherName];

      if (grandfatherName.isNotEmpty) {
        conditions.add('"الجد" = ?');
        arguments.add(grandfatherName);
      }
      if (family.isNotEmpty) {
        conditions.add('"العائلة" = ?');
        arguments.add(family);
      }

      final rows = await db.rawQuery(
        'SELECT * FROM "Sgaza" WHERE ${conditions.join(' AND ')}',
        arguments,
      );

      for (final row in rows) {
        final siblingKind = classifySiblingRelation(
          personMother: motherName,
          candidateMother: _value(row, 'اسم الام'),
        );
        addMatch(
          RelativeType.siblings,
          row,
          detail: siblingRelationLabel(siblingKind),
        );
      }
    }

    if (name.isNotEmpty &&
        hasSupportingEvidence(name, [fatherName, family])) {
      final conditions = <String>[
        '"الهوية" != ?',
        '"الاب" = ?',
      ];
      final arguments = <Object?>[identity, name];

      if (fatherName.isNotEmpty) {
        conditions.add('"الجد" = ?');
        arguments.add(fatherName);
      }
      if (family.isNotEmpty) {
        conditions.add('"العائلة" = ?');
        arguments.add(family);
      }

      final rows = await db.rawQuery(
        'SELECT * FROM "Sgaza" WHERE ' + conditions.join(' AND '),
        arguments,
      );

      for (final row in rows) {
        addMatch(RelativeType.children, row);
      }
    }

    return candidates.values.toList();
  }

  Future<Map<String, Object?>?> _findUniquePerson({
    required String name,
    String father = '',
    String family = '',
  }) async {
    if (name.trim().isEmpty) return null;

    final conditions = <String>['"الاسم" = ?'];
    final arguments = <Object?>[name];

    if (father.trim().isNotEmpty) {
      conditions.add('"الاب" = ?');
      arguments.add(father);
    }
    if (family.trim().isNotEmpty) {
      conditions.add('"العائلة" = ?');
      arguments.add(family);
    }

    if (conditions.length < 2) return null;

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
