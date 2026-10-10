import '../core/utils/arabic_normalizer.dart';

enum SiblingRelationKind {
  full,
  paternal,
}

SiblingRelationKind classifySiblingRelation({
  required String personMother,
  required String candidateMother,
}) {
  final first = ArabicNormalizer.normalize(personMother);
  final second = ArabicNormalizer.normalize(candidateMother);

  if (first.isNotEmpty && second.isNotEmpty && first == second) {
    return SiblingRelationKind.full;
  }

  return SiblingRelationKind.paternal;
}

String siblingRelationLabel(SiblingRelationKind relation) {
  switch (relation) {
    case SiblingRelationKind.full:
      return 'شقيق';
    case SiblingRelationKind.paternal:
      return 'من الأب';
  }
}

bool hasSupportingEvidence(String anchor, List<String> supporting) {
  if (anchor.trim().isEmpty) return false;
  return supporting.any((value) => value.trim().isNotEmpty);
}


int lineageEvidenceScore({
  required String expectedParent,
  required String candidateParent,
  required String expectedFamily,
  required String candidateFamily,
}) {
  var score = 0;

  final expectedParentValue = ArabicNormalizer.normalize(expectedParent);
  final candidateParentValue = ArabicNormalizer.normalize(candidateParent);
  if (expectedParentValue.isNotEmpty) {
    if (candidateParentValue.isNotEmpty &&
        candidateParentValue != expectedParentValue) {
      return -1;
    }
    if (candidateParentValue == expectedParentValue) {
      score += 2;
    }
  }

  final expectedFamilyValue = ArabicNormalizer.normalize(expectedFamily);
  final candidateFamilyValue = ArabicNormalizer.normalize(candidateFamily);
  if (expectedFamilyValue.isNotEmpty) {
    if (candidateFamilyValue.isNotEmpty &&
        candidateFamilyValue != expectedFamilyValue) {
      return -1;
    }
    if (candidateFamilyValue == expectedFamilyValue) {
      score += 1;
    }
  }

  return score;
}

int evidenceScore({
  required String expectedGrandfather,
  required String candidateGrandfather,
  required String expectedFamily,
  required String candidateFamily,
}) {
  var score = 0;

  final expectedGrandfatherValue =
      ArabicNormalizer.normalize(expectedGrandfather);
  final candidateGrandfatherValue =
      ArabicNormalizer.normalize(candidateGrandfather);
  if (expectedGrandfatherValue.isNotEmpty) {
    if (candidateGrandfatherValue.isNotEmpty &&
        candidateGrandfatherValue != expectedGrandfatherValue) {
      return -1;
    }
    if (candidateGrandfatherValue == expectedGrandfatherValue) {
      score += 2;
    }
  }

  final expectedFamilyValue = ArabicNormalizer.normalize(expectedFamily);
  final candidateFamilyValue = ArabicNormalizer.normalize(candidateFamily);
  if (expectedFamilyValue.isNotEmpty) {
    if (candidateFamilyValue.isNotEmpty &&
        candidateFamilyValue != expectedFamilyValue) {
      return -1;
    }
    if (candidateFamilyValue == expectedFamilyValue) {
      score += 1;
    }
  }

  return score;
}
