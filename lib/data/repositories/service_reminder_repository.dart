import 'package:kreatif_otopart/data/database/database_helper.dart';
import 'package:kreatif_otopart/data/models/service_reminder.dart';

class ServiceReminderRepository {
  final DatabaseHelper _databaseHelper;

  ServiceReminderRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<int> insert(ServiceReminder reminder) async {
    final db = await _databaseHelper.database;
    return await db.insert('service_reminders', reminder.toMap());
  }

  Future<List<ServiceReminder>> getAll({String? status}) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps;
    
    if (status != null) {
      maps = await db.query(
        'service_reminders',
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'reminder_km ASC',
      );
    } else {
      maps = await db.query(
        'service_reminders',
        orderBy: 'reminder_km ASC',
      );
    }

    return List.generate(maps.length, (i) => ServiceReminder.fromMap(maps[i]));
  }

  Future<void> update(ServiceReminder reminder) async {
    final db = await _databaseHelper.database;
    await db.update(
      'service_reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'service_reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAsSent(int id) async {
    final db = await _databaseHelper.database;
    await db.update(
      'service_reminders',
      {
        'is_sent': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> cancelReminder(int id) async {
    final db = await _databaseHelper.database;
    await db.update(
      'service_reminders',
      {
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
