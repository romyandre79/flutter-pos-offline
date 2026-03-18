import 'package:equatable/equatable.dart';
import 'package:kreatif_otopart/data/models/cart_item.dart';
import 'package:kreatif_otopart/data/models/product.dart';
import 'package:kreatif_otopart/data/models/customer.dart';

abstract class PosState extends Equatable {
  const PosState();

  @override
  List<Object?> get props => [];
}

class PosInitial extends PosState {}

class PosLoading extends PosState {}

class PosLoaded extends PosState {
  final List<Product> products;
  final List<Product> filteredProducts;
  final List<CartItem> cartItems;
  final String selectedCategory; // 'All', 'Kiloan', 'Satuan', 'Barang', 'Jasa'
  final String searchQuery;
  final Customer? selectedCustomer;
  final String customerName;

  const PosLoaded({
    this.products = const [],
    this.filteredProducts = const [],
    this.cartItems = const [],
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.selectedCustomer,
    this.customerName = 'Walk-in Customer',
  });

  int get totalAmount => cartItems.fold(0, (sum, item) => sum + item.subtotal);
  int get totalItems => cartItems.fold(0, (sum, item) => sum + item.quantity);

  PosLoaded copyWith({
    List<Product>? products,
    List<Product>? filteredProducts,
    List<CartItem>? cartItems,
    String? selectedCategory,
    String? searchQuery,
    Customer? selectedCustomer,
    String? customerName,
  }) {
    return PosLoaded(
      products: products ?? this.products,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      cartItems: cartItems ?? this.cartItems,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      customerName: customerName ?? this.customerName,
    );
  }

  @override
  List<Object?> get props => [
        products,
        filteredProducts,
        cartItems,
        selectedCategory,
        searchQuery,
        selectedCustomer,
        customerName,
      ];
}

class PosError extends PosState {
  final String message;

  const PosError(this.message);

  @override
  List<Object?> get props => [message];
}

class PosSuccess extends PosState {
  final String message; 

  const PosSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
