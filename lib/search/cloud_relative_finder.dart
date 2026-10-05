import '../core/utils/arabic_normalizer.dart';
import 'cloud_search_engine.dart';
import 'relative_match.dart';
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
  final String detail;

  const CloudRelativeCandidate({
    required this.type,
    required this.person,
    this.detail = '',
  });
}

class CloudRelativeFinder {
  final CloudSearchEngine engine;

  const CloudRelativeFinder(this.engine);

  Future<List<CloudRelativeCandidate>> findForPerson(
    CloudPerson person,
  ) async {
    final candidates = <String, CloudRelativeCandidate>{};

    void add(
      CloudRelativeType type,
      CloudPerson relative, {
      String detail = '',
    }) {
      if (relative.id.isEmpty || relative.id == person.id) return;
      candidates['${type.name}:$relative.id'] = CloudRelativeCandidate(
        type: type,
        person: relative,
        detail: detail,
      );
    }

    bool same(String actual, String expected) {
      final normalizedActual = ArabicNormalizer.normalize(actual);
      final normalizedExpected = ArabicNormalizer.normalize(expected);
      return normalizedExpected.isNotEmpty &&
          normalizedActual == normalizedExpected;
    }

    bool matches(
      CloudPerson candidate, {
      String name = '',
      String father = '',
      String grandfather = '',
      String family = '',
      String mother = '',
      String birthDate = '',
    }) {
      return (name.isEmpty || same(candidate.name, name)) &&
          (father.isEmpty || same(candidate.father, father)) &&
          (grandfather.isEmpty ||
              same(candidate.grandfather, grandfather)) &&
          (family.isEmpty || same(candidate.family, family)) &&
          (mother.isEmpty || same(candidate.mother, mother)) &&
          (birthDate.isEmpty || same(candidate.birth, birthDate));
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

      return result.results
          .where(
            (candidate) => matches(
              candidate,
              name: name,
              father: father,
              grandfather: grandfather,
              family: family,
              mother: mother,
              birthDate: birthDate,
            ),
          )
          .toList();
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

        all.addAll(
          page.results.where(
            (candidate) => matches(
              candidate,
              name: name,
              father: father,
              grandfather: grandfather,
              family: family,
              mother: mother,
              birthDate: birthDate,
            ),
          ),
        );

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
      const pageSize = 100;
      var offset = 0;
      CloudPerson? found;

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

        final exact = page.results
            .where(
              (candidate) => matches(
                candidate,
                name: name,
                father: father,
                grandfather: grandfather,
                family: family,
                mother: mother,
                birthDate: birthDate,
              ),
            )
            .toList();

        if (exact.length > 1) return null;
        if (exact.length == 1) {
          found ??= exact.first;
        }

        if (!page.hasMore || page.results.isEmpty) break;
        offset += page.results.length;
      }

      return found;
    }

    CloudPerson? father;
    if (person.father.isNotEmpty &&
        hasSupportingEvidence(
          person.father,
          [person.grandfather, person.family],
        )) {
      father = await unique(
        name: person.father,
        father: person.grandfather,
        family: person.family,
      );
      if (father != null) add(CloudRelativeType.father, father);
    }

    CloudPerson? mother;
    if (person.mother.isNotEmpty &&
        person.id.isNotEmpty &&
        person.name.isNotEmpty &&
        hasSupportingEvidence(
          person.name,
          [person.father, person.grandfather, person.family],
        ) &&
        person.family.isNotEmpty) {
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
          final isExactCurrentPerson =
              child.id == person.id &&
              (person.fullName.isEmpty || child.fullName == person.fullName) &&
              (person.name.isEmpty || child.name == person.name) &&
              (person.father.isEmpty || child.father == person.father) &&
              (person.grandfather.isEmpty ||
                  child.grandfather == person.grandfather) &&
              (person.family.isEmpty || child.family == person.family) &&
              child.mother == motherCandidate.name;

          if (isExactCurrentPerson) {
            verifiedMothers[motherCandidate.id] = motherCandidate;
          }
        }
      }

      if (verifiedMothers.length == 1) {
        mother = verifiedMothers.values.first;
      } else if (verifiedMothers.length > 1 &&
          person.motherFamily.isNotEmpty) {
        final byMotherFamily = verifiedMothers.values
            .where(
              (candidate) =>
                  candidate.oldFamily.trim() == person.motherFamily.trim(),
            )
            .toList();
        if (byMotherFamily.length == 1) {
          mother = byMotherFamily.first;
        }
      }
    }

    if (mother != null) add(CloudRelativeType.mother, mother);

    if (person.father.isNotEmpty &&
        hasSupportingEvidence(
          person.father,
          [person.grandfather, person.family],
        )) {
      final siblings = await searchAllExact(
        father: person.father,
        grandfather: person.grandfather,
        family: person.family,
      );

      for (final sibling in siblings) {
        final siblingKind = classifySiblingRelation(
          personMother: person.mother,
          candidateMother: sibling.mother,
        );
        add(
          CloudRelativeType.siblings,
          sibling,
          detail: siblingRelationLabel(siblingKind),
        );
      }
    }

    if (person.name.isNotEmpty &&
        hasSupportingEvidence(
          person.name,
          [person.father, person.family],
        )) {
      final children = await searchAllExact(
        father: person.name,
        grandfather: person.father,
        family: person.family,
      );

      for (final child in children) {
        add(CloudRelativeType.children, child);
      }
    }

    if (father != null && father.grandfather.isNotEmpty) {
      final paternalGrandfather = await unique(
        name: father.grandfather,
        father: father.father,
        family: father.family,
      );
      if (paternalGrandfather != null) {
        add(CloudRelativeType.grandparents, paternalGrandfather);
      }

      if (father.mother.isNotEmpty &&
          hasSupportingEvidence(
            father.mother,
            [father.motherFamily, father.family],
          )) {
        final paternalGrandmother = await unique(
          name: father.mother,
          family: father.motherFamily.isNotEmpty
              ? father.motherFamily
              : father.family,
        );
        if (paternalGrandmother != null) {
          add(CloudRelativeType.grandparents, paternalGrandmother);
        }
      }
    }

    if (mother != null) {
      if (mother.grandfather.isNotEmpty &&
          hasSupportingEvidence(
            mother.grandfather,
            [mother.father, mother.family],
          )) {
        final maternalGrandfather = await unique(
          name: mother.grandfather,
          father: mother.father,
          family: mother.family,
        );
        if (maternalGrandfather != null) {
          add(CloudRelativeType.grandparents, maternalGrandfather);
        }
      }

      if (mother.mother.isNotEmpty &&
          hasSupportingEvidence(
            mother.mother,
            [mother.motherFamily, mother.family],
          )) {
        final maternalGrandmother = await unique(
          name: mother.mother,
          family: mother.motherFamily.isNotEmpty
              ? mother.motherFamily
              : mother.family,
        );
        if (maternalGrandmother != null) {
          add(CloudRelativeType.grandparents, maternalGrandmother);
        }
      }
    }

    return candidates.values.toList();
  }
}
