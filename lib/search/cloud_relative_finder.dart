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
      candidates['$type:$relative.id'] =
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

    // Mother:
    // The mother's record is searched by her name + the husband's family
    // (the child's family), not by m_family. If several candidates remain,
    // verify the exact child and use the mother's own family from the child's
    // m_family as the final discriminator when the candidate exposes it as
    // old_family.
    CloudPerson? mother;
    if (person.mother.isNotEmpty &&
        person.family.isNotEmpty &&
        person.id.isNotEmpty &&
        person.name.isNotEmpty &&
        person.father.isNotEmpty &&
        person.grandfather.isNotEmpty) {
      final motherMatches = await searchAllExact(
        name: person.mother,
        family: person.family,
      );

      final verifiedMothers = <String, CloudPerson>{};

      for (final motherCandidate in motherMatches) {
        final childMatches = await searchExact(
          name: person.name,
          father: person.father,
          grandfather: person.grandfather,
          family: person.family,
          mother: motherCandidate.name,
          limit: 2,
        );

        for (final child in childMatches) {
          final fullNameMatches = person.fullName.trim().isEmpty ||
              child.fullName.trim() == person.fullName.trim();

          final childMatchesCurrentPerson =
              child.id == person.id &&
              fullNameMatches &&
              child.name.trim() == person.name.trim() &&
              child.father.trim() == person.father.trim() &&
              child.grandfather.trim() == person.grandfather.trim() &&
              child.family.trim() == person.family.trim() &&
              child.mother.trim() == motherCandidate.name.trim();

          if (childMatchesCurrentPerson) {
            verifiedMothers[motherCandidate.id] = motherCandidate;
          }
        }
      }

      if (verifiedMothers.length == 1) {
        mother = verifiedMothers.values.first;
      } else if (verifiedMothers.length > 1 &&
          person.motherFamily.isNotEmpty) {
        final byMotherFamily = verifiedMothers.values.where((candidate) {
          return candidate.oldFamily.trim() == person.motherFamily.trim();
        }).toList();

        if (byMotherFamily.length == 1) {
          mother = byMotherFamily.first;
        }
      }
    }

    if (mother != null) add(CloudRelativeType.mother, mother);

    if (person.father.isNotEmpty &&
        person.grandfather.isNotEmpty &&
        person.family.isNotEmpty &&
        person.mother.isNotEmpty) {
      final siblings = await searchAllExact(
        father: person.father,
        grandfather: person.grandfather,
        family: person.family,
        mother: person.mother,
      );

      for (final sibling in siblings) {
        add(CloudRelativeType.siblings, sibling);
      }
    }

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
