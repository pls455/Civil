import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_registry/search/relative_match.dart';

void main() {
  test('same known mother makes siblings full siblings', () {
    expect(
      classifySiblingRelation(
        personMother: 'سعاد محمد',
        candidateMother: 'سعاد محمد',
      ),
      SiblingRelationKind.full,
    );
  });

  test('different known mother keeps the paternal sibling relation', () {
    expect(
      classifySiblingRelation(
        personMother: 'سعاد محمد',
        candidateMother: 'ليلى أحمد',
      ),
      SiblingRelationKind.paternal,
    );
  });

  test('missing mother does not discard a paternal sibling relation', () {
    expect(
      classifySiblingRelation(
        personMother: '',
        candidateMother: 'سعاد محمد',
      ),
      SiblingRelationKind.paternal,
    );
  });

  test('missing candidate mother does not discard a paternal sibling relation', () {
    expect(
      classifySiblingRelation(
        personMother: 'سعاد محمد',
        candidateMother: '',
      ),
      SiblingRelationKind.paternal,
    );
  });

  test('supporting evidence requires the anchor plus at least one known field', () {
    expect(hasSupportingEvidence('محمد', ['', 'المصري']), isTrue);
    expect(hasSupportingEvidence('محمد', ['', '']), isFalse);
    expect(hasSupportingEvidence('', ['المصري']), isFalse);
  });
}
