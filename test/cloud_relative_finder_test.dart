import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_registry/search/cloud_relative_finder.dart';
import 'package:citizen_registry/search/cloud_search_engine.dart';
import 'package:citizen_registry/search/search_engine.dart';

class _FakeCloudSearchEngine extends CloudSearchEngine {
  final List<CloudPerson> people;

  _FakeCloudSearchEngine(this.people);

  @override
  Future<CloudSearchResult> search(
    SearchQuery query, {
    int limit = CloudSearchEngine.defaultLimit,
    int offset = 0,
  }) async {
    bool contains(String value, String expected) {
      if (expected.trim().isEmpty) return true;
      return value.contains(expected.trim());
    }

    final filtered = people.where((person) {
      return contains(person.name, query.name) &&
          contains(person.father, query.father) &&
          contains(person.grandfather, query.grandfather) &&
          contains(person.family, query.family) &&
          contains(person.mother, query.mother) &&
          contains(person.birth, query.birthDate);
    }).toList();

    final start = offset.clamp(0, filtered.length);
    final end = (start + limit).clamp(start, filtered.length);
    final page = filtered.sublist(start, end);

    return CloudSearchResult(
      results: page,
      limit: limit,
      offset: offset,
      hasMore: end < filtered.length,
    );
  }
}

CloudPerson person({
  required String id,
  required String name,
  required String father,
  required String grandfather,
  required String family,
  String mother = '',
}) {
  return CloudPerson(
    id: id,
    fullName: [name, father, grandfather, family]
        .where((value) => value.isNotEmpty)
        .join(' '),
    name: name,
    father: father,
    grandfather: grandfather,
    family: family,
    gender: '',
    birth: '',
    oldFamily: '',
    mother: mother,
    motherFamily: '',
    englishName: '',
    street: '',
  );
}

void main() {
  test('finds paternal siblings when mother is missing', () async {
    final root = person(
      id: '1',
      name: 'محمد',
      father: 'عمر',
      grandfather: 'حسن',
      family: 'المصري',
    );
    final sibling = person(
      id: '2',
      name: 'خالد',
      father: 'عمر',
      grandfather: 'حسن',
      family: 'المصري',
      mother: 'سعاد',
    );

    final finder = CloudRelativeFinder(
      _FakeCloudSearchEngine([root, sibling]),
    );

    final relatives = await finder.findForPerson(root);

    final match = relatives.singleWhere(
      (item) => item.person.id == '2',
    );
    expect(match.type, CloudRelativeType.siblings);
    expect(match.detail, 'من الأب');
  });

  test('classifies the same known mother as a full sibling', () async {
    final root = person(
      id: '1',
      name: 'محمد',
      father: 'عمر',
      grandfather: 'حسن',
      family: 'المصري',
      mother: 'سعاد',
    );
    final sibling = person(
      id: '2',
      name: 'خالد',
      father: 'عمر',
      grandfather: 'حسن',
      family: 'المصري',
      mother: 'سعاد',
    );

    final finder = CloudRelativeFinder(
      _FakeCloudSearchEngine([root, sibling]),
    );

    final relatives = await finder.findForPerson(root);
    final match = relatives.singleWhere(
      (item) => item.person.id == '2',
    );

    expect(match.detail, 'شقيق');
  });

  test('does not filter children by the parent mother', () async {
    final root = person(
      id: '1',
      name: 'محمد',
      father: 'عمر',
      grandfather: 'حسن',
      family: 'المصري',
      mother: 'سعاد',
    );
    final child = person(
      id: '2',
      name: 'خالد',
      father: 'محمد',
      grandfather: 'عمر',
      family: 'المصري',
      mother: 'ليلى',
    );

    final finder = CloudRelativeFinder(
      _FakeCloudSearchEngine([root, child]),
    );

    final relatives = await finder.findForPerson(root);

    expect(
      relatives.any(
        (item) =>
            item.type == CloudRelativeType.children &&
            item.person.id == '2',
      ),
      isTrue,
    );
  });

  test('unique relationship matching continues past the first page', () async {
    final root = person(
      id: 'root',
      name: 'علي',
      father: 'محمد',
      grandfather: 'حسن',
      family: 'المصري',
    );

    final decoys = List.generate(
      100,
      (index) => person(
        id: 'decoy-$index',
        name: 'محمدية$index',
        father: 'حسن',
        grandfather: 'سالم',
        family: 'المصري',
      ),
    );

    final father = person(
      id: 'father',
      name: 'محمد',
      father: 'حسن',
      grandfather: 'سالم',
      family: 'المصري',
    );

    final finder = CloudRelativeFinder(
      _FakeCloudSearchEngine([
        ...decoys,
        father,
        root,
      ]),
    );

    final relatives = await finder.findForPerson(root);

    expect(
      relatives.any(
        (item) =>
            item.type == CloudRelativeType.father &&
            item.person.id == 'father',
      ),
      isTrue,
    );
  });
}
