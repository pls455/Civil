import '../search/search_engine.dart';

enum AiSearchIntentType {
  personSearch,
  relationSearch,
}

enum AiRelationType {
  father,
  mother,
  siblings,
  children,
  grandparents,
}

class SearchIntent {
  final AiSearchIntentType type;
  final AiRelationType? relation;
  final Map<String, String> person;
  final Map<String, String> relative;

  const SearchIntent({
    required this.type,
    required this.relation,
    required this.person,
    required this.relative,
  });

  static const _fields = <String>[
    'name',
    'father',
    'grandfather',
    'family',
    'identity',
    'mother',
    'birthDate',
    'gender',
    'area',
  ];

  factory SearchIntent.fromJson(Map<String, dynamic> json) {
    final intent = json['intent']?.toString().trim() ?? '';
    final relationValue = json['relation']?.toString().trim() ?? '';

    final type = switch (intent) {
      'person_search' => AiSearchIntentType.personSearch,
      'relation_search' => AiSearchIntentType.relationSearch,
      _ => throw const FormatException('نوع طلب البحث غير معروف.'),
    };

    AiRelationType? relation;
    if (relationValue.isNotEmpty) {
      relation = switch (relationValue) {
        'father' => AiRelationType.father,
        'mother' => AiRelationType.mother,
        'siblings' => AiRelationType.siblings,
        'children' => AiRelationType.children,
        'grandparents' => AiRelationType.grandparents,
        _ => throw const FormatException('نوع القرابة غير مدعوم.'),
      };
    }

    Map<String, String> readMap(Object? raw) {
      if (raw is! Map) return <String, String>{};
      final output = <String, String>{};
      for (final field in _fields) {
        final value = raw[field]?.toString().trim() ?? '';
        output[field] = value;
      }
      return output;
    }

    final person = readMap(json['person']);
    final relative = readMap(json['relative']);

    return SearchIntent(
      type: type,
      relation: relation,
      person: person,
      relative: relative,
    );
  }

  SearchQuery toPersonQuery() {
    return SearchQuery(
      name: person['name'] ?? '',
      father: person['father'] ?? '',
      grandfather: person['grandfather'] ?? '',
      family: person['family'] ?? '',
      identity: person['identity'] ?? '',
      mother: person['mother'] ?? '',
      birthDate: person['birthDate'] ?? '',
      gender: person['gender']?.isEmpty == true ? null : person['gender'],
      areaCode: person['area']?.isEmpty == true ? null : person['area'],
    );
  }

  SearchQuery toRelativeQuery() {
    return SearchQuery(
      name: relative['name'] ?? '',
      father: relative['father'] ?? '',
      grandfather: relative['grandfather'] ?? '',
      family: relative['family'] ?? '',
      identity: relative['identity'] ?? '',
      mother: relative['mother'] ?? '',
      birthDate: relative['birthDate'] ?? '',
      gender: relative['gender']?.isEmpty == true ? null : relative['gender'],
      areaCode: relative['area']?.isEmpty == true ? null : relative['area'],
    );
  }

  bool get hasPersonCriteria => person.values.any(
        (value) => value.trim().isNotEmpty,
      );

  bool get hasRelativeCriteria => relative.values.any(
        (value) => value.trim().isNotEmpty,
      );
}
