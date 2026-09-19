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
    _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT)');
    });
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> replaceWith(File tempDb) async {
    final db = await open();
    final target = db.path;
    await db.close();
    _db = null;
    final backup = '$target.bak';
    final targetFile = File(target);
    if (await targetFile.exists()) await targetFile.rename(backup);
    await tempDb.copy(target);
    final backupFile = File(backup);
    if (await backupFile.exists()) await backupFile.delete();
  }
}
