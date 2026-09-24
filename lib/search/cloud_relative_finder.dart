import 'cloud_search_engine.dart';
import 'search_engine.dart';

enum CloudRelativeType {
  father,
  mother,
  siblings,
  children,
  grandparents,
}


class CloudRelativeCandidate {
  final CloudRelativeType type;
  final CloudPerson person;

  const CloudRelativeCandidate({
    required this.type,
    required this.person,
  });
}

class CloudRelativeFinder {
  final CloudSearchEngine engine;

  const CloudRelativeFinder(this.engine);

  Future<List<CloudRelativeCandidate>> findForPerson(
    CloudPerson person,
  ) async {
    final candidates = <String, CloudRelativeCandidate>{};

    void add(CloudRelativeType type, CloudPerson relative) {
      if (relative.id.isEmpty || relative.id == person.id) return;
      candidates['$type:${relative.id}'] =
          CloudRelativeCandidate(type: type, person: relative);
    }

    Future<List<CloudPerson>> searchExact({
      String name = '',
      String father = '',
      String grandfather = '',
      String family = '',
      String mother = '',
      String birthDate = '',
      String gender = '',
      int limit = 50,
    }) async {
      final result = await engine.search(
        SearchQuery(
          name: name,
          father: father,
          grandfather: grandfather,
          family: family,
          mother: mother,
          birthDate: birthDate,
          gender: gender.isEmpty ? null : gender,
        ),
        limit: limit,
      );

      bool same(String actual, String expected) =>
          expected.trim().isNotEmpty && actual.trim() == expected.trim();

      return result.results.where((candidate) {
        return (name.isEmpty || same(candidate.name, name)) &&
            (father.isEmpty || same(candidate.father, father)) &&
            (grandfather.isEmpty ||
                same(candidate.grandfather, grandfather)) &&
            (family.isEmpty || same(candidate.family, family)) &&
            (mother.isEmpty || same(candidate.mother, mother)) &&
            (birthDate.isEmpty || same(candidate.birth, birthDate));
      }).toList();
    }

    Future<CloudPerson?> unique({
      String name = '',
      String father = '',
      String grandfather = '',
      String family = '',
      String mother = '',
      String birthDate = '',
    }) async {
      final matches = await searchExact(
        name: name,
        father: father,
        grandfather: grandfather,
        family: family,
        mother: mother,
        birthDate: birthDate,
        limit: 20,
      );
      return matches.length == 1 ? matches.first : null;
    }

    final father = person.father.isEmpty ||
            person.grandfather.isEmpty ||
            person.family.isEmpty
        ? null
        : await unique(
            name: person.father,
            father: person.grandfather,
            family: person.family,
          );
    if (father != null) add(CloudRelativeType.father, father);

    final mother = person.mother.isEmpty || person.motherFamily.isEmpty
        ? null
        : await unique(
            name: person.mother,
            family: person.motherFamily,
          );
    if (mother != null) add(CloudRelativeType.mother, mother);

    final siblings = person.father.isEmpty ||
            person.grandfather.isEmpty ||
            person.family.isEmpty
        ? const <CloudPerson>[]
        : await searchExact(
            father: person.father,
            grandfather: person.grandfather,
            family: person.family,
            limit: 100,
          );

    for (final sibling in siblings) {
      add(CloudRelativeType.siblings, sibling);
    }

    final children = person.name.isEmpty ||
            person.father.isEmpty ||
            person.family.isEmpty
        ? const <CloudPerson>[]
        : await searchExact(
            father: person.name,
            grandfather: person.father,
            family: person.family,
            limit: 100,
          );
    for (final child in children) {
      add(CloudRelativeType.children, child);
    }

    CloudPerson? paternalGrandfather;
    if (father != null) {
      if (father.grandfather.isNotEmpty &&
          father.father.isNotEmpty &&
          father.family.isNotEmpty) {
        paternalGrandfather = await unique(
          name: father.grandfather,
          father: father.father,
          family: father.family,
        );
        if (paternalGrandfather != null) {
          add(CloudRelativeType.grandparents, paternalGrandfather);
        }
      }

      if (father.mother.isNotEmpty && father.motherFamily.isNotEmpty) {
        final paternalGrandmother = await unique(
          name: father.mother,
          family: father.motherFamily,
        );
        if (paternalGrandmother != null) {
          add(CloudRelativeType.grandparents, paternalGrandmother);
        }
      }

    }

    if (mother != null) {
      if (mother.grandfather.isNotEmpty &&
          mother.father.isNotEmpty &&
          mother.family.isNotEmpty) {
        final maternalGrandfather = await unique(
          name: mother.grandfather,
          father: mother.father,
          family: mother.family,
        );
        if (maternalGrandfather != null) {
          add(CloudRelativeType.grandparents, maternalGrandfather);
        }
      }

      if (mother.mother.isNotEmpty && mother.motherFamily.isNotEmpty) {
        final maternalGrandmother = await unique(
          name: mother.mother,
          family: mother.motherFamily,
        );
        if (maternalGrandmother != null) {
          add(CloudRelativeType.grandparents, maternalGrandmother);
        }
      }
    }

    return candidates.values.toList();
  }

}
