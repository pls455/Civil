import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_registry/ai/search_intent.dart';

void main() {
  test('SearchIntent accepts a person search from structured JSON', () {
    final intent = SearchIntent.fromJson({
      'intent': 'person_search',
      'relation': '',
      'person': {
        'name': 'أحمد',
        'father': 'محمد',
        'grandfather': '',
        'family': 'المصري',
        'identity': '',
        'mother': '',
        'birthDate': '',
        'gender': '',
        'area': '',
      },
      'relative': {
        'name': '',
        'father': '',
        'grandfather': '',
        'family': '',
        'identity': '',
        'mother': '',
        'birthDate': '',
        'gender': '',
        'area': '',
      },
    });

    expect(intent.type, AiSearchIntentType.personSearch);
    expect(intent.hasPersonCriteria, isTrue);
    expect(intent.toPersonQuery().name, 'أحمد');
    expect(intent.toPersonQuery().father, 'محمد');
    expect(intent.toPersonQuery().family, 'المصري');
  });

  test('SearchIntent accepts a reverse sibling relation', () {
    final intent = SearchIntent.fromJson({
      'intent': 'relation_search',
      'relation': 'siblings',
      'person': {
        'name': '',
        'father': '',
        'grandfather': '',
        'family': '',
        'identity': '',
        'mother': '',
        'birthDate': '',
        'gender': '',
        'area': '',
      },
      'relative': {
        'name': 'خالد',
        'father': '',
        'grandfather': '',
        'family': '',
        'identity': '',
        'mother': '',
        'birthDate': '',
        'gender': '',
        'area': '',
      },
    });

    expect(intent.type, AiSearchIntentType.relationSearch);
    expect(intent.relation, AiRelationType.siblings);
    expect(intent.hasRelativeCriteria, isTrue);
    expect(intent.toRelativeQuery().name, 'خالد');
  });
}
