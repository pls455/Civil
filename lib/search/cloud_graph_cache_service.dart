import 'cloud_cache_store.dart';
import 'cloud_relative_finder.dart';
import 'cloud_search_engine.dart';

class CloudGraphCacheService {
  static const defaultMaxDepth = 4;

  final CloudSearchEngine engine;
  final CloudCacheStore cache;

  const CloudGraphCacheService({
    required this.engine,
    required this.cache,
  });

  Future<int> discover(
    CloudPerson root, {
    int maxDepth = defaultMaxDepth,
  }) async {
    final normalizedDepth = maxDepth < 0
        ? 0
        : maxDepth > defaultMaxDepth
            ? defaultMaxDepth
            : maxDepth;

    if (root.id.trim().isEmpty) return 0;

    final queue = <_QueueEntry>[
      _QueueEntry(person: root, depth: 0),
    ];
    final visited = <String>{};
    var discoveredPeople = 0;

    while (queue.isNotEmpty) {
      final entry = queue.removeAt(0);
      final id = entry.person.id.trim();
      if (id.isEmpty || !visited.add(id)) continue;

      await cache.upsertPerson(entry.person);

      final savedDepth = await cache.expansionDepth(id);
      if (savedDepth >= normalizedDepth) {
        continue;
      }

      if (entry.depth >= normalizedDepth) {
        await cache.markExpanded(id, normalizedDepth);
        continue;
      }

      final relatives =
          await CloudRelativeFinder(engine).findForPerson(entry.person);

      for (final candidate in relatives) {
        await cache.upsertPerson(candidate.person);
        await cache.saveRelationship(
          personId: id,
          relativeId: candidate.person.id,
          relationType: candidate.type.name,
          depth: entry.depth + 1,
          detail: candidate.detail,
        );

        if (!visited.contains(candidate.person.id.trim())) {
          queue.add(
            _QueueEntry(
              person: candidate.person,
              depth: entry.depth + 1,
            ),
          );
        }
      }

      await cache.markExpanded(id, normalizedDepth);

      discoveredPeople++;
    }

    return discoveredPeople;
  }
}

class _QueueEntry {
  final CloudPerson person;
  final int depth;

  const _QueueEntry({
    required this.person,
    required this.depth,
  });
}
