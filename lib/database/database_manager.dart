import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseManager {
  Database? _db;

  Future<Database> open() async {
    if (_db != null) return _db!;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'citizen_registry.sqlite');
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

  /// Replaces the production DB only after the staged SQLite file passes
  /// an integrity check. The source MDB is not involved in this operation.
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

    final stagedCheck = await openDatabase(stagedInTarget, readOnly: true);
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
