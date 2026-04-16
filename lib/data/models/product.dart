import 'package:equatable/equatable.dart';
import 'package:kreatif_pos_offline/data/models/product_unit.dart';

enum ProductType { service, goods }

extension ProductTypeExtension on ProductType {
  String get value {
    switch (this) {
      case ProductType.service:
        return 'service';
      case ProductType.goods:
        return 'goods';
    }
  }

  String get displayName {
    switch (this) {
      case ProductType.service:
        return 'Jasa / Layanan';
      case ProductType.goods:
        return 'Barang / Produk';
    }
  }

  static ProductType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'service':
        return ProductType.service;
      case 'goods':
        return ProductType.goods;
      default:
        return ProductType.goods;
    }
  }
}

class Product extends Equatable {
  final int? id;
  final String name;
  final String? description;
  final int price;
  final int cost; // Harga beli / modal
  final double? stock; // Nullable for services
  final String unit; // kg, pcs, pack, etc.
  final ProductType type;
  final int? durationDays; // Only for services
  final String? imageUrl;
  final String? barcode; // New field for barcode
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? expireDate;
  final int? expireKm;
  final List<ProductUnit> units;

  const Product({
    this.id,
    required this.name,
    this.description,
    required this.price,
    this.cost = 0,
    this.stock,
    required this.unit,
    required this.type,
    this.durationDays,
    this.imageUrl,
    this.barcode,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.expireDate,
    this.expireKm,
    this.units = const [],
  });

  ProductUnit? get baseUnit => units.isNotEmpty ? units.first : null;

  String get stockDisplay {
    if (isService) return '-';
    if (units.isEmpty) return '${stock ?? 0} $unit';
    return units.map((u) => '${u.stock} ${u.unitName}').join(', ');
  }

  bool get isService => type == ProductType.service;
  bool get isGoods => type == ProductType.goods;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'cost': cost,
      'stock': stock,
      'unit': unit,
      'type': type.value,
      'duration_days': durationDays,
      'image_url': imageUrl,
      'barcode': barcode,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'expire_date': expireDate,
      'expire_km': expireKm,
      'price': units.isNotEmpty ? units.first.price : price,
      'stock': units.isNotEmpty ? units.first.stock : stock,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: map['price'] as int,
      cost: (map['cost'] as int?) ?? 0,
      stock: (map['stock'] as num?)?.toDouble(),
      unit: map['unit'] as String,
      type: ProductTypeExtension.fromString(map['type'] as String),
      durationDays: map['duration_days'] as int?,
      imageUrl: map['image_url'] as String?,
      barcode: map['barcode'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      expireDate: map['expire_date'] as int?,
      expireKm: map['expire_km'] as int?,
      units: (map['units'] as List?)?.map((u) => ProductUnit.fromMap(u)).toList() ?? [],
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? description,
    int? price,
    int? cost,
    double? stock,
    String? unit,
    ProductType? type,
    int? durationDays,
    String? imageUrl,
    String? barcode,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? expireDate,
    int? expireKm,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      type: type ?? this.type,
      durationDays: durationDays ?? this.durationDays,
      imageUrl: imageUrl ?? this.imageUrl,
      barcode: barcode ?? this.barcode,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expireDate: expireDate ?? this.expireDate,
      expireKm: expireKm ?? this.expireKm,
      units: units ?? this.units,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        price,
        cost,
        stock,
        unit,
        type,
        durationDays,
        imageUrl,
        barcode,
        isActive,
        createdAt,
        updatedAt,
        expireDate,
        expireKm,
        units,
      ];
}
