import 'package:kreatif_pos_offline/data/database/database_helper.dart';
import 'package:kreatif_pos_offline/data/models/product.dart';
import 'package:kreatif_pos_offline/data/models/product_unit.dart';
import 'package:sqflite/sqflite.dart';

class ProductRepository {
  final DatabaseHelper _databaseHelper;

  ProductRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<List<Product>> getProducts({ProductType? type, bool activeOnly = true, String? query}) async {
    final db = await _databaseHelper.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (activeOnly) {
      whereClause = 'is_active = 1';
    }

    if (type != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND type = ?';
      } else {
        whereClause = 'type = ?';
      }
      whereArgs.add(type.value);
    }

    if (query != null && query.isNotEmpty) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND (name LIKE ? OR barcode = ?)';
      } else {
        whereClause = '(name LIKE ? OR barcode = ?)';
      }
      whereArgs.add('%$query%');
      whereArgs.add(query);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    List<Product> products = [];
    for (var m in maps) {
      final productId = m['id'] as int;
      final unitMaps = await db.query('product_units', where: 'product_id = ?', whereArgs: [productId]);
      final units = unitMaps.map((u) => ProductUnit.fromMap(u)).toList();
      
      final productMap = Map<String, dynamic>.from(m);
      productMap['units'] = units;
      products.add(Product.fromMap(productMap));
    }

    return products;
  }

  Future<Product?> getProductById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final productId = maps.first['id'] as int;
      final unitMaps = await db.query('product_units', where: 'product_id = ?', whereArgs: [productId]);
      final units = unitMaps.map((u) => ProductUnit.fromMap(u)).toList();
      
      final productMap = Map<String, dynamic>.from(maps.first);
      productMap['units'] = units;
      return Product.fromMap(productMap);
    }
    return null;
  }

  Future<int> addProduct(Product product) async {
    final db = await _databaseHelper.database;
    return await db.transaction((txn) async {
      final productId = await txn.insert('products', product.toMap());
      
      for (var unit in product.units) {
        await txn.insert('product_units', unit.copyWith(productId: productId).toMap());
      }
      
      return productId;
    });
  }

  Future<int> updateProduct(Product product) async {
    final db = await _databaseHelper.database;
    return await db.transaction((txn) async {
      final result = await txn.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
      
      // Update units: simple approach is delete and re-insert
      await txn.delete('product_units', where: 'product_id = ?', whereArgs: [product.id]);
      for (var unit in product.units) {
        await txn.insert('product_units', unit.copyWith(productId: product.id).toMap());
      }
      
      return result;
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await _databaseHelper.database;
    // Soft delete: set is_active to 0
    return await db.update(
      'products',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> hardDeleteProduct(int id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  Future<void> updateStock(int productId, double quantityChange, {int? unitId}) async {
    final db = await _databaseHelper.database;
    
    await db.transaction((txn) async {
      if (unitId != null) {
        // Case: deducting using a specific unit (e.g., from POS)
        if (quantityChange < 0) {
           await _deductStockRecursive(txn, productId, unitId, -quantityChange);
        } else {
           // Adding stock usually simple increment
           await txn.rawUpdate(
             'UPDATE product_units SET stock = stock + ? WHERE id = ?',
             [quantityChange, unitId]
           );
        }
      } else {
        // Fallback for types that don't use multi-unit yet
        await txn.rawUpdate(
          'UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ?',
          [quantityChange, DateTime.now().toIso8601String(), productId],
        );
      }
    });
  }

  Future<void> _deductStockRecursive(Transaction txn, int productId, int unitId, double qtyToDeduct) async {
    final unitMaps = await txn.query('product_units', where: 'id = ?', whereArgs: [unitId]);
    if (unitMaps.isEmpty) return;
    
    final unit = ProductUnit.fromMap(unitMaps.first);
    
    if (unit.stock >= qtyToDeduct) {
      // Enough stock in this unit
      await txn.rawUpdate(
        'UPDATE product_units SET stock = stock - ? WHERE id = ?',
        [qtyToDeduct, unitId]
      );
    } else {
      // Not enough stock, try to convert from parent
      final deficit = qtyToDeduct - unit.stock;
      
      if (unit.parentUnitId != null && unit.multiplier > 0) {
        // Calculate how many parent units needed
        final parentQtyNeeded = (deficit / unit.multiplier).ceilToDouble();
        
        // Deduct from parent first (recursive)
        await _deductStockRecursive(txn, productId, unit.parentUnitId!, parentQtyNeeded);
        
        // After parent deducted, we now have enough "virtual" stock to fulfill the deficit
        // The remaining stock after fulfilling the deficit:
        final addedFromParent = parentQtyNeeded * unit.multiplier;
        final newStock = addedFromParent - deficit; // stock was 0 or less than qtyToDeduct
        
        // Update current unit stock to remaining balance
        await txn.update(
          'product_units',
          {'stock': newStock},
          where: 'id = ?',
          whereArgs: [unitId]
        );
      } else {
        // No parent, cannot fulfill, just allow negative if needed or handle error
        // For POS, we usually allow negative if forced, but here we just deduct anyway
        await txn.rawUpdate(
          'UPDATE product_units SET stock = stock - ? WHERE id = ?',
          [qtyToDeduct, unitId]
        );
      }
    }
  }

  Future<void> convertUnit({
    required int productId,
    required int fromUnitId,
    required int toUnitId,
    required double fromQty,
    required double multiplier,
  }) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      // 1. Deduct from source unit
      await txn.rawUpdate(
        'UPDATE product_units SET stock = stock - ? WHERE id = ? AND product_id = ?',
        [fromQty, fromUnitId, productId]
      );
      
      // 2. Add to target unit
      final toQty = fromQty * multiplier;
      await txn.rawUpdate(
        'UPDATE product_units SET stock = stock + ? WHERE id = ? AND product_id = ?',
        [toQty, toUnitId, productId]
      );
      
      // 3. Log conversion
      await txn.insert('unit_conversions', {
        'product_id': productId,
        'from_unit_id': fromUnitId,
        'to_unit_id': toUnitId,
        'from_qty': fromQty,
        'to_qty': toQty,
      });
    });
  }

  Future<void> addProducts(List<Product> products) async {
    final db = await _databaseHelper.database;
    final batch = db.batch();

    for (var product in products) {
      batch.insert('products', product.toMap());
    }

    await batch.commit(noResult: true);
  }
}
