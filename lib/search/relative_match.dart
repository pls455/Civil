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
