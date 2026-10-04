import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'cloud_search_engine.dart';
import 'search_engine.dart';

class CloudCacheStats {
  final bool exists;
  final int peopleCount;
  final int relationshipCount;
  final int sizeBytes;

  const CloudCacheStats({
    required this.exists,
    required this.peopleCount,
    required this.relationshipCount,
    required this.sizeBytes,
  });
}

class CloudCachedRelationship {
  final String relationType;
  final CloudPerson person;

  const CloudCachedRelationship({
    required this.relationType,
    required this.person,
  });
}

class CloudCacheSearchResult {
  final List<CloudPerson> results;
  final int limit;
  final int offset;
  final bool hasMore;

  const CloudCacheSearchResult({
    required this.results,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });
}

class CloudCacheStore {
  static const _databaseName = 'cloud_cache.sqlite';
  static Database? _db;
  static Future<Database>? _opening;

  Future<Database> open() async {
    if (_db != null) return _db!;
    if (_opening != null) return _opening!;

    _opening = _openDatabase();
    try {
      _db = await _opening!;
      return _db!;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _openDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, _databaseName);

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS "cloud_people" ('
          '"id" TEXT PRIMARY KEY,'
          '"full_name" TEXT NOT NULL DEFAULT "",'
          '"name" TEXT NOT NULL DEFAULT "",'
          '"father" TEXT NOT NULL DEFAULT "",'
          '"grandfather" TEXT NOT NULL DEFAULT "",'
          '"family" TEXT NOT NULL DEFAULT "",'
          '"gender" TEXT NOT NULL DEFAULT "",'
          '"birth" TEXT NOT NULL DEFAULT "",'
          '"old_family" TEXT NOT NULL DEFAULT "",'
          '"mother" TEXT NOT NULL DEFAULT "",'
          '"mother_family" TEXT NOT NULL DEFAULT "",'
          '"english_name" TEXT NOT NULL DEFAULT "",'
          '"street" TEXT NOT NULL DEFAULT "",'
          '"first_seen" INTEGER NOT NULL,'
          '"last_updated" INTEGER NOT NULL'
          ')',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS "idx_cloud_people_name" '
          'ON "cloud_people" ("name")',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS "idx_cloud_people_family" '
          'ON "cloud_people" ("family")',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS "idx_cloud_people_mother" '
          'ON "cloud_people" ("mother")',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS "cloud_relationships" ('
          '"person_id" TEXT NOT NULL,'
          '"relative_id" TEXT NOT NULL,'
          '"relation_type" TEXT NOT NULL,'
          '"depth" INTEGER NOT NULL,'
          '"discovered_at" INTEGER NOT NULL,'
          'PRIMARY KEY ("person_id", "relative_id", "relation_type")'
          ')',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS "idx_cloud_relationships_person" '
          'ON "cloud_relationships" ("person_id")',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS "cloud_expansions" ('
          '"person_id" TEXT PRIMARY KEY,'
          '"max_depth" INTEGER NOT NULL,'
          '"expanded_at" INTEGER NOT NULL'
          ')',
        );
      },
    );
  }

  Future<void> upsertPerson(CloudPerson person) async {
    await upsertPeople([person]);
  }

  Future<void> upsertPeople(List<CloudPerson> people) async {
    if (people.isEmpty) return;
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      for (final person in people) {
        final id = person.id.trim();
        if (id.isEmpty) continue;

        final existing = await txn.query(
          'cloud_people',
          columns: ['first_seen'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );

        final firstSeen = existing.isEmpty
            ? now
            : (existing.first['first_seen'] as int? ?? now);

        await txn.insert(
          'cloud_people',
          {
            'id': id,
            'full_name': person.fullName,
            'name': person.name,
            'father': person.father,
            'grandfather': person.grandfather,
            'family': person.family,
            'gender': person.gender,
            'birth': person.birth,
            'old_family': person.oldFamily,
            'mother': person.mother,
            'mother_family': person.motherFamily,
            'english_name': person.englishName,
            'street': person.street,
            'first_seen': firstSeen,
            'last_updated': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<CloudCacheSearchResult> search(
    SearchQuery query, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await open();
    final conditions = <String>[];
    final arguments = <Object?>[];

    void addText(String column, String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      conditions.add('"$column" LIKE ?');
      arguments.add('%$trimmed%');
    }

    addText('id', query.identity);
    addText('name', query.name);
    addText('father', query.father);
    addText('grandfather', query.grandfather);
    addText('family', query.family);
    addText('mother', query.mother);
    addText('birth', query.birthDate);
    addText('gender', query.gender ?? '');

    if (conditions.isEmpty) {
      return CloudCacheSearchResult(
        results: const [],
        limit: limit,
        offset: offset,
        hasMore: false,
      );
    }

    final rows = await db.query(
      'cloud_people',
      where: conditions.join(' AND '),
      whereArgs: arguments,
      orderBy: 'last_updated DESC, id',
      limit: limit + 1,
      offset: offset,
    );

    final hasMore = rows.length > limit;
    final visible = hasMore ? rows.take(limit) : rows;

    return CloudCacheSearchResult(
      results: visible.map(_personFromRow).toList(),
      limit: limit,
      offset: offset,
      hasMore: hasMore,
    );
  }

  Future<List<CloudCachedRelationship>> relationshipsForPerson(
    String identity,
  ) async {
    final id = identity.trim();
    if (id.isEmpty) return const [];

    final db = await open();
    final rows = await db.rawQuery(
      'SELECT r."relation_type", p.* '
      'FROM "cloud_relationships" r '
      'JOIN "cloud_people" p ON p."id" = r."relative_id" '
      'WHERE r."person_id" = ? '
      'ORDER BY r."relation_type", p."full_name", p."id"',
      [id],
    );

    return rows
        .map(
          (row) => CloudCachedRelationship(
            relationType: row['relation_type']?.toString() ?? '',
            person: _personFromRow(row),
          ),
        )
        .toList();
  }

  Future<void> saveRelationship({
    required String personId,
    required String relativeId,
    required String relationType,
    required int depth,
  }) async {
    final first = personId.trim();
    final second = relativeId.trim();
    final type = relationType.trim();
    if (first.isEmpty || second.isEmpty || type.isEmpty || first == second) {
      return;
    }

    final db = await open();
    await db.insert(
      'cloud_relationships',
      {
        'person_id': first,
        'relative_id': second,
        'relation_type': type,
        'depth': depth,
        'discovered_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> expansionDepth(String identity) async {
    final id = identity.trim();
    if (id.isEmpty) return -1;
    final db = await open();
    final rows = await db.query(
      'cloud_expansions',
      columns: ['max_depth'],
      where: 'person_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return -1;
    return (rows.first['max_depth'] as int?) ?? -1;
  }

  Future<void> markExpanded(
    String identity,
    int maxDepth,
  ) async {
    final id = identity.trim();
    if (id.isEmpty) return;
    final db = await open();
    final current = await expansionDepth(id);
    if (current >= maxDepth) return;

    await db.insert(
      'cloud_expansions',
      {
        'person_id': id,
        'max_depth': maxDepth,
        'expanded_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CloudPerson?> findById(String identity) async {
    final id = identity.trim();
    if (id.isEmpty) return null;
    final db = await open();
    final rows = await db.query(
      'cloud_people',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _personFromRow(rows.first);
  }

  Future<CloudCacheStats> stats() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, _databaseName));
    if (!await file.exists()) {
      return const CloudCacheStats(
        exists: false,
        peopleCount: 0,
        relationshipCount: 0,
        sizeBytes: 0,
      );
    }

    final db = await open();
    final people = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM "cloud_people"'),
        ) ??
        0;
    final relationships = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM "cloud_relationships"'),
        ) ??
        0;

    return CloudCacheStats(
      exists: true,
      peopleCount: people,
      relationshipCount: relationships,
      sizeBytes: await file.length(),
    );
  }

  Future<String> databasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, _databaseName);
  }

  Future<void> clear() async {
    await close();
    final file = File(await databasePath());
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }

  CloudPerson _personFromRow(Map<String, Object?> row) {
    return CloudPerson(
      id: row['id']?.toString() ?? '',
      fullName: row['full_name']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      father: row['father']?.toString() ?? '',
      grandfather: row['grandfather']?.toString() ?? '',
      family: row['family']?.toString() ?? '',
      gender: row['gender']?.toString() ?? '',
      birth: row['birth']?.toString() ?? '',
      oldFamily: row['old_family']?.toString() ?? '',
      mother: row['mother']?.toString() ?? '',
      motherFamily: row['mother_family']?.toString() ?? '',
      englishName: row['english_name']?.toString() ?? '',
      street: row['street']?.toString() ?? '',
    );
  }
}
