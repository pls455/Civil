import '../core/utils/arabic_normalizer.dart';
import 'package:sqflite/sqflite.dart';

class SearchEngine {
  final Database db;
  SearchEngine(this.db);

  Future<List<Map<String, Object?>>> byIdentity(String identity, {int limit = 50, int offset = 0}) {
    return db.query('Sgaza', where: 'identity_normalized = ?', whereArgs: [ArabicNormalizer.normalize(identity)], limit: limit, offset: offset);
  }

  Future<List<Map<String, Object?>>> byName(String query, {int limit = 50, int offset = 0}) {
    final q = ArabicNormalizer.normalize(query);
    return db.rawQuery(
      'SELECT * FROM Sgaza WHERE name_normalized LIKE ? OR father_normalized LIKE ? OR grandfather_normalized LIKE ? OR family_normalized LIKE ? OR mother_normalized LIKE ? LIMIT ? OFFSET ?',
      ['%$q%', '%$q%', '%$q%', '%$q%', '%$q%', limit, offset],
    );
  }
}
