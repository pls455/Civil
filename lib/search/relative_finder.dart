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
        hasSupportingEvidence(
          fatherName,
          [grandfatherName, family],
        )) {
      father = await _findBestPerson(
        name: fatherName,
        expectedGrandfather: grandfatherName,
        expectedFamily: family,
      );
      if (father != null) {
        addMatch(RelativeType.father, father);
      }
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
        final grandfather = await _findBestPerson(
          name: fatherGrandfather,
          expectedGrandfather: '',
          expectedFamily: fatherFamily,
        );
        if (grandfather != null) {
          addMatch(RelativeType.grandfather, grandfather);
        }
      }
    }

    if (fatherName.isNotEmpty &&
        hasSupportingEvidence(
          fatherName,
          [grandfatherName, family],
        )) {
      final rows = await _peopleWithFather(fatherName);

      for (final row in rows) {
        final candidateGrandfather = _value(row, 'الجد');
        final candidateFamily = _value(row, 'العائلة');
        if (grandfatherName.isNotEmpty &&
            candidateGrandfather != grandfatherName) {
          continue;
        }
        if (family.isNotEmpty && candidateFamily != family) {
          continue;
        }
        if (grandfatherName.isEmpty && family.isEmpty) {
          continue;
        }

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
        hasSupportingEvidence(
          name,
          [fatherName, family],
        )) {
      final rows = await _peopleWithFather(name);

      for (final row in rows) {
        final candidateGrandfather = _value(row, 'الجد');
        final candidateFamily = _value(row, 'العائلة');
        if (fatherName.isNotEmpty &&
            candidateGrandfather != fatherName) {
          continue;
        }
        if (family.isNotEmpty && candidateFamily != family) {
          continue;
        }
        if (fatherName.isEmpty && family.isEmpty) {
          continue;
        }
        addMatch(RelativeType.children, row);
      }
    }

    return candidates.values.toList();
  }

  Future<List<Map<String, Object?>>> _peopleWithFather(String father) async {
    final value = father.trim();
    if (value.isEmpty) return const [];

    final rows = await db.rawQuery(
      'SELECT * FROM "Sgaza" WHERE "الاب" LIKE ?',
      ['%$value%'],
    );

    final normalizedFather = ArabicNormalizer.normalize(value);
    return rows
        .where(
          (row) =>
              _value(row, 'الاب') == normalizedFather &&
              _value(row, 'الهوية').isNotEmpty,
        )
        .toList();
  }

  Future<Map<String, Object?>?> _findBestPerson({
    required String name,
    required String expectedGrandfather,
    required String expectedFamily,
  }) async {
    final value = name.trim();
    if (value.isEmpty) return null;

    final rows = await db.rawQuery(
      'SELECT * FROM "Sgaza" WHERE "الاسم" LIKE ?',
      ['%$value%'],
    );

    final normalizedName = ArabicNormalizer.normalize(value);
    final matches = rows.where((row) {
      if (_value(row, 'الاسم') != normalizedName) return false;

      final score = lineageEvidenceScore(
        expectedParent: expectedGrandfather,
        candidateParent: _value(row, 'الاب'),
        expectedFamily: expectedFamily,
        candidateFamily: _value(row, 'العائلة'),
      );
      return score >= 1;
    }).toList();

    if (matches.isEmpty) return null;

    var bestScore = -1;
    Map<String, Object?>? best;
    var bestCount = 0;

    for (final row in matches) {
      final score = lineageEvidenceScore(
        expectedParent: expectedGrandfather,
        candidateParent: _value(row, 'الاب'),
        expectedFamily: expectedFamily,
        candidateFamily: _value(row, 'العائلة'),
      );
      if (score > bestScore) {
        bestScore = score;
        best = row;
        bestCount = 1;
      } else if (score == bestScore) {
        bestCount++;
      }
    }

    return bestCount == 1 ? best : null;
  }

  static String _value(Map<String, Object?> row, String key) {
    return ArabicNormalizer.normalize(row[key]?.toString());
  }
}
