import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final String detail;
  final CloudPerson person;

  const CloudCachedRelationship({
    required this.relationType,
    this.detail = '',
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
  static const _directoryPreferenceKey = 'cloud_cache_directory';
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
    final configured = await configuredDirectory();
    final path = await databasePath();

    try {
      return await _openDatabaseAt(path);
    } catch (error) {
      // Android's directory picker can return a filesystem path without
      // granting SQLite direct access to it (scoped storage / SAF). Do not
      // let every cloud search crash because a saved path is no longer usable.
      if (configured == null || configured.isEmpty) rethrow;

      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_directoryPreferenceKey);

      final directory = await getApplicationDocumentsDirectory();
      final fallbackPath = p.join(directory.path, _databaseName);
      try {
        return await _openDatabaseAt(fallbackPath);
      } catch (_) {
        // Preserve the original error; it identifies the selected path failure.
        Error.throwWithStackTrace(error, StackTrace.current);
      }
    }
  }

  Future<Database> _openDatabaseAt(String path) async {
    await Directory(p.dirname(path)).create(recursive: true);

    return openDatabase(
      path,
      version: 3,
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
          "\"detail\" TEXT NOT NULL DEFAULT '',"
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE "cloud_relationships" '
            'ADD COLUMN "detail" TEXT NOT NULL DEFAULT \'\'',
          );
        }
        if (oldVersion < 3) {
          await db.delete('cloud_relationships');
          await db.delete('cloud_expansions');
        }
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

    String keepValue(String incoming, Object? existing) {
      final next = incoming.trim();
      final previous = existing?.toString().trim() ?? '';
      return next.isNotEmpty ? next : previous;
    }

    await db.transaction((txn) async {
      for (final person in people) {
        final id = person.id.trim();
        if (id.isEmpty) continue;

        final existing = await txn.query(
          'cloud_people',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );

        final previous = existing.isEmpty ? <String, Object?>{} : existing.first;
        final firstSeen = existing.isEmpty
            ? now
            : (previous['first_seen'] as int? ?? now);

        await txn.insert(
          'cloud_people',
          {
            'id': id,
            'full_name': keepValue(person.fullName, previous['full_name']),
            'name': keepValue(person.name, previous['name']),
            'father': keepValue(person.father, previous['father']),
            'grandfather':
                keepValue(person.grandfather, previous['grandfather']),
            'family': keepValue(person.family, previous['family']),
            'gender': keepValue(person.gender, previous['gender']),
            'birth': keepValue(person.birth, previous['birth']),
            'old_family':
                keepValue(person.oldFamily, previous['old_family']),
            'mother': keepValue(person.mother, previous['mother']),
            'mother_family':
                keepValue(person.motherFamily, previous['mother_family']),
            'english_name':
                keepValue(person.englishName, previous['english_name']),
            'street': keepValue(person.street, previous['street']),
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
            detail: row['detail']?.toString() ?? '',
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
    String detail = '',
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
        'detail': detail.trim(),
        'depth': depth,
        'discovered_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> resetPersonExpansion(String identity) async {
    final id = identity.trim();
    if (id.isEmpty) return;

    final db = await open();
    await db.transaction((txn) async {
      await txn.delete(
        'cloud_relationships',
        where: 'person_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'cloud_expansions',
        where: 'person_id = ?',
        whereArgs: [id],
      );
    });
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
    final file = File(await databasePath());
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
    final preferences = await SharedPreferences.getInstance();
    final configured = preferences.getString(_directoryPreferenceKey)?.trim();

    if (configured != null && configured.isNotEmpty) {
      return p.join(configured, _databaseName);
    }

    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, _databaseName);
  }

  Future<String?> configuredDirectory() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_directoryPreferenceKey)?.trim();
  }

  Future<void> setDatabaseDirectory(String directoryPath) async {
    final value = directoryPath.trim();
    if (value.isEmpty) {
      throw ArgumentError('مسار مجلد قاعدة السحابة فارغ.');
    }

    final directory = Directory(value);
    if (!await directory.exists()) {
      throw StateError('مجلد قاعدة السحابة غير موجود.');
    }

    final targetPath = p.join(directory.path, _databaseName);
    final probePath = p.join(directory.path, '.civil_storage_test.sqlite');
    Database? probe;
    try {
      // Verify that SQLite itself can open files in this directory. A folder
      // picker result alone does not prove Android granted filesystem access.
      probe = await openDatabase(probePath);
      await probe.close();
      probe = null;
      final probeFile = File(probePath);
      if (await probeFile.exists()) await probeFile.delete();
    } catch (error) {
      await probe?.close();
      throw StateError(
        'Android لا يسمح بفتح قاعدة SQLite مباشرة في هذا المجلد. '
        'اختر مجلدًا يستطيع التطبيق الكتابة فيه. التفاصيل: $error',
      );
    }

    final previousPath = await databasePath();
    await close();

    final source = File(previousPath);
    final target = File(targetPath);
    if (await source.exists() &&
        p.normalize(previousPath) != p.normalize(targetPath) &&
        !await target.exists()) {
      try {
        await source.copy(targetPath);
      } catch (error) {
        throw StateError('تعذر نقل قاعدة السحابة إلى المجلد الجديد: $error');
      }
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_directoryPreferenceKey, directory.path);
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
