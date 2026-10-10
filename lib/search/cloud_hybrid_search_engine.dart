import 'cloud_cache_store.dart';
import 'cloud_search_engine.dart';
import 'search_engine.dart';

class CloudHybridSearchEngine {
  final CloudCacheStore cache;
  final CloudSearchEngine cloud;

  CloudHybridSearchEngine({
    CloudCacheStore? cache,
    CloudSearchEngine? cloud,
  })  : cache = cache ?? CloudCacheStore(),
        cloud = cloud ?? CloudSearchEngine();

  Future<CloudSearchResult> search(
    SearchQuery query, {
    int limit = CloudSearchEngine.defaultLimit,
    int offset = 0,
  }) async {
    if (_cacheCanFilter(query)) {
      final cached = await cache.search(
        query,
        limit: limit,
        offset: offset,
      );

      if (cached.results.length >= limit || !cached.hasMore) {
        try {
          final remote = await cloud.search(
            query,
            limit: limit,
            offset: offset,
          );
          return _merge(
            cached.results,
            remote,
            limit: limit,
            offset: offset,
          );
        } on Exception {
          return CloudSearchResult(
            results: cached.results,
            limit: limit,
            offset: offset,
            hasMore: cached.hasMore,
          );
        }
      }

      try {
        final remote = await cloud.search(
          query,
          limit: limit,
          offset: offset,
        );
        return _merge(
          cached.results,
          remote,
          limit: limit,
          offset: offset,
        );
      } on Exception {
        if (cached.results.isNotEmpty) {
          return CloudSearchResult(
            results: cached.results,
            limit: limit,
            offset: offset,
            hasMore: cached.hasMore,
          );
        }
        rethrow;
      }
    }

    return cloud.search(
      query,
      limit: limit,
      offset: offset,
    );
  }

  bool _cacheCanFilter(SearchQuery query) {
    return query.provinceCode?.trim().isNotEmpty != true &&
        query.areaCode?.trim().isNotEmpty != true &&
        query.maritalStatus?.trim().isNotEmpty != true &&
        query.district?.trim().isNotEmpty != true &&
        query.neighborhood?.trim().isNotEmpty != true &&
        query.birthplace?.trim().isNotEmpty != true &&
        query.workplace?.trim().isNotEmpty != true;
  }

  CloudSearchResult _merge(
    List<CloudPerson> cached,
    CloudSearchResult remote, {
    required int limit,
    required int offset,
  }) {
    final merged = <String, CloudPerson>{};

    for (final person in cached) {
      if (person.id.isNotEmpty) merged[person.id] = person;
    }
    for (final person in remote.results) {
      if (person.id.isNotEmpty) merged[person.id] = person;
    }

    final values = merged.values.toList();
    final page = values.length > limit ? values.take(limit).toList() : values;

    return CloudSearchResult(
      results: page,
      limit: limit,
      offset: offset,
      hasMore: remote.hasMore || values.length > limit,
    );
  }

  void close() {
    cloud.close();
  }
}
