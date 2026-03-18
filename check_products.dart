import 'package:flutter/widgets.dart';
import 'package:kreatif_otopart/data/database/database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await DatabaseHelper.instance.database;
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
  print('Product Count: ${result.first['count']}');
  
  final products = await db.query('products');
  for (var p in products) {
    print('Product: ${p['id']} - ${p['name']} (Stock: ${p['stock']})');
  }
}
