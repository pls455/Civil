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
      candidates['$type:' + relative.id] =
          CloudRelativeCandidate(type: type, person: relative);
    }

    Future<List<CloudPerson>> searchExact({
      String name = '',
      String father = '',
      String grandfather = '',
      String family = '',
      String mother = '',
      String birthDate = '',
      int limit = 2,
      int offset = 0,
    }) async {
      final result = await engine.search(
        SearchQuery(
          name: name,
          father: father,
          grandfather: grandfather,
          family: family,
          mother: mother,
          birthDate: birthDate,
        ),
        limit: limit,
        offset: offset,
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

    Future<List<CloudPerson>> searchAllExact({
      String name = '',
      String father = '',
      String grandfather = '',
      String family = '',
      String mother = '',
      String birthDate = '',
    }) async {
      const pageSize = 100;
      final all = <CloudPerson>[];
      var offset = 0;

      while (true) {
        final page = await engine.search(
          SearchQuery(
            name: name,
            father: father,
            grandfather: grandfather,
            family: family,
            mother: mother,
            birthDate: birthDate,
          ),
          limit: pageSize,
          offset: offset,
        );

        bool same(String actual, String expected) =>
            expected.trim().isNotEmpty && actual.trim() == expected.trim();

        final exact = page.results.where((candidate) {
          return (name.isEmpty || same(candidate.name, name)) &&
              (father.isEmpty || same(candidate.father, father)) &&
              (grandfather.isEmpty ||
                  same(candidate.grandfather, grandfather)) &&
              (family.isEmpty || same(candidate.family, family)) &&
              (mother.isEmpty || same(candidate.mother, mother)) &&
              (birthDate.isEmpty || same(candidate.birth, birthDate));
        });

        all.addAll(exact);

        if (!page.hasMore || page.results.isEmpty) break;
        offset += page.results.length;
      }

      return all;
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
        limit: 2,
      );
      return matches.length == 1 ? matches.first : null;
    }

    // Father is accepted only when the available paternal fields identify
    // exactly one record.
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

    // Mother is accepted only when name + mother's family identify one record.
    final mother = person.mother.isEmpty || person.motherFamily.isEmpty
        ? null
        : await unique(
            name: person.mother,
            family: person.motherFamily,
          );
    if (mother != null) add(CloudRelativeType.mother, mother);

    // Siblings are inferred only from one uniquely identified father. The
    // father itself is excluded, preventing the parent from appearing as a
    // sibling just because his own father matches the same chain.
    if (father != null) {
      final siblings = await searchAllExact(
        father: person.father,
        grandfather: person.grandfather,
        family: person.family,
        mother: person.mother,
      );

      for (final sibling in siblings) {
        if (sibling.id == father.id) continue;
        add(CloudRelativeType.siblings, sibling);
      }
    }

    // Children are inferred only when the current person can itself be
    // uniquely resolved from the fields stored by a child for its father.
    // Ambiguous duplicate names therefore produce no child claims.
    final currentPerson = person.name.isEmpty ||
            person.father.isEmpty ||
            person.grandfather.isEmpty ||
            person.family.isEmpty
        ? null
        : await unique(
            name: person.name,
            father: person.father,
            grandfather: person.grandfather,
            family: person.family,
          );

    if (currentPerson != null && currentPerson.id == person.id) {
      final children = await searchAllExact(
        father: person.name,
        grandfather: person.father,
        family: person.family,
        mother: person.mother,
      );

      for (final child in children) {
        add(CloudRelativeType.children, child);
      }
    }

    // Grandparents are resolved by following the uniquely identified parent
    // records rather than matching the names on the current person directly.
    if (father != null) {
      if (father.grandfather.isNotEmpty &&
          father.father.isNotEmpty &&
          father.family.isNotEmpty) {
        final paternalGrandfather = await unique(
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
