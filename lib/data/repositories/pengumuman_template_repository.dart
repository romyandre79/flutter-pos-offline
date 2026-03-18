import 'package:kreatif_otopart/data/database/database_helper.dart';
import 'package:kreatif_otopart/data/models/pengumuman_template.dart';

class PengumumanTemplateRepository {
  final _dbHelper = DatabaseHelper.instance;

  Future<int> insert(PengumumanTemplate template) async {
    final db = await _dbHelper.database;
    return await db.insert('pengumuman_template', template.toMap());
  }

  Future<List<PengumumanTemplate>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pengumuman_template',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return PengumumanTemplate.fromMap(maps[i]);
    });
  }

  Future<int> update(PengumumanTemplate template) async {
    final db = await _dbHelper.database;
    return await db.update(
      'pengumuman_template',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'pengumuman_template',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
