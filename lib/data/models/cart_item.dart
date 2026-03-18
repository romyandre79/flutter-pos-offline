import 'package:equatable/equatable.dart';
import 'package:kreatif_otopart/data/models/product.dart';

class CartItem extends Equatable {
  final Product product;
  final int quantity;
  final String? note;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.note,
  });

  int get subtotal => product.price * quantity;

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? note,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [product, quantity, note];
}
