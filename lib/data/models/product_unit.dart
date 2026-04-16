import 'package:equatable/equatable.dart';

class ProductUnit extends Equatable {
  final int? id;
  final int? productId;
  final String unitName;
  final int price;
  final int cost;
  final double multiplier;
  final int? parentUnitId;
  final double stock;

  const ProductUnit({
    this.id,
    this.productId,
    required this.unitName,
    required this.price,
    this.cost = 0,
    this.multiplier = 1.0,
    this.parentUnitId,
    this.stock = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'unit_name': unitName,
      'price': price,
      'cost': cost,
      'multiplier': multiplier,
      'parent_unit_id': parentUnitId,
      'stock': stock,
    };
  }

  factory ProductUnit.fromMap(Map<String, dynamic> map) {
    return ProductUnit(
      id: map['id'] as int?,
      productId: map['product_id'] as int?,
      unitName: map['unit_name'] as String,
      price: map['price'] as int,
      cost: (map['cost'] as int?) ?? 0,
      multiplier: (map['multiplier'] as num).toDouble(),
      parentUnitId: map['parent_unit_id'] as int?,
      stock: (map['stock'] as num).toDouble(),
    );
  }

  ProductUnit copyWith({
    int? id,
    int? productId,
    String? unitName,
    int? price,
    int? cost,
    double? multiplier,
    int? parentUnitId,
    double? stock,
  }) {
    return ProductUnit(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unitName: unitName ?? this.unitName,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      multiplier: multiplier ?? this.multiplier,
      parentUnitId: parentUnitId ?? this.parentUnitId,
      stock: stock ?? this.stock,
    );
  }

  @override
  List<Object?> get props => [id, productId, unitName, price, cost, multiplier, parentUnitId, stock];
}
