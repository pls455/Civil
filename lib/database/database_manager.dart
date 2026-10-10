import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class InstalledDatabaseStats {
  final bool exists;
  final int sizeBytes;
  final int tableCount;
  final List<String> tables;

  const InstalledDatabaseStats({
    required this.exists,
    required this.sizeBytes,
    required this.tableCount,
    required this.tables,
  });
}

class DatabaseManager {
  Database? _db;

  Future<String> databasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'citizen_registry.sqlite');
  }

  Future<Database> open() async {
    if (_db != null) return _db!;

    final path = await databasePath();
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS metadata '
          '(key TEXT PRIMARY KEY, value TEXT)',
        );
      },
    );
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<InstalledDatabaseStats> stats() async {
    final path = await databasePath();
    final file = File(path);
    if (!await file.exists()) {
      return const InstalledDatabaseStats(
        exists: false,
        sizeBytes: 0,
        tableCount: 0,
        tables: [],
      );
    }

    final db = await openDatabase(path, readOnly: true);
    try {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name NOT LIKE 'sqlite_%' "
        "ORDER BY name",
      );
      final tables = rows
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      return InstalledDatabaseStats(
        exists: true,
        sizeBytes: await file.length(),
        tableCount: tables.length,
        tables: tables,
      );
    } finally {
      await db.close();
    }
  }

  Future<void> replaceWith(File stagedDb) async {
    if (!await stagedDb.exists()) {
      throw ArgumentError('Staged database does not exist');
    }

    final stagedPath = stagedDb.path;
    final checkDb = await openDatabase(stagedPath, readOnly: true);
    try {
      final result = await checkDb.rawQuery('PRAGMA integrity_check');
      final value = result.isEmpty ? null : result.first.values.first;
      if (value != 'ok') {
        throw StateError('SQLite integrity check failed: $value');
      }
    } finally {
      await checkDb.close();
    }

    await close();

    final targetDir = await getApplicationDocumentsDirectory();
    final target = p.join(targetDir.path, 'citizen_registry.sqlite');
    final stagedInTarget = p.join(
      targetDir.path,
      'citizen_registry.sqlite.staged',
    );
    final backup = p.join(targetDir.path, 'citizen_registry.sqlite.bak');

    final stagedTargetFile = File(stagedInTarget);
    if (await stagedTargetFile.exists()) {
      await stagedTargetFile.delete();
    }
    await stagedDb.copy(stagedInTarget);

    final stagedCheck = await openDatabase(
      stagedInTarget,
      readOnly: true,
    );
    try {
      final result = await stagedCheck.rawQuery('PRAGMA integrity_check');
      final value = result.isEmpty ? null : result.first.values.first;
      if (value != 'ok') {
        throw StateError('Staged SQLite integrity check failed: $value');
      }
    } finally {
      await stagedCheck.close();
    }

    final targetFile = File(target);
    final backupFile = File(backup);
    if (await backupFile.exists()) {
      await backupFile.delete();
    }

    try {
      if (await targetFile.exists()) {
        await targetFile.rename(backup);
      }
      await stagedTargetFile.rename(target);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    } catch (_) {
      if (!await targetFile.exists() && await backupFile.exists()) {
        await backupFile.rename(target);
      }
      rethrow;
    } finally {
      if (await stagedTargetFile.exists()) {
        await stagedTargetFile.delete();
      }
    }
  }
}
