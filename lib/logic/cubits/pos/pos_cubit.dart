import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/data/models/cart_item.dart';
import 'package:kreatif_otopart/data/models/product.dart';
import 'package:kreatif_otopart/data/models/customer.dart';
import 'package:kreatif_otopart/data/repositories/product_repository.dart';
import 'package:kreatif_otopart/logic/cubits/pos/pos_state.dart';

class PosCubit extends Cubit<PosState> {
  final ProductRepository _productRepository;

  PosCubit(this._productRepository) : super(PosInitial()) {
    // Optionally load products immediately, but explicit call is safer for now
    // loadProducts();
    // No, dashboard calls loadProducts().
  }

  // Load products from repository
  Future<void> loadProducts() async {
    emit(PosLoading());
    try {
      final products = await _productRepository.getProducts();
      emit(PosLoaded(
        products: products,
        filteredProducts: products, // Initially show all
      ));
    } catch (e) {
      emit(const PosError('Failed to load products'));
    }
  }

  // Get available categories (unique units)
  List<String> get availableCategories {
    if (state is PosLoaded) {
      final products = (state as PosLoaded).products;
      final units = products.map((p) => p.unit).toSet().toList();
      units.sort();
      return units; // Returns ['kg', 'pcs', 'pack', etc.]
    }
    return [];
  }

  // Filter products by query or category
  void filterProducts({String? query, String? category}) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      
      String currentQuery = query ?? currentState.searchQuery;
      String currentCategory = category ?? currentState.selectedCategory;

      List<Product> filtered = currentState.products.where((product) {
        bool matchesQuery = product.name.toLowerCase().contains(currentQuery.toLowerCase());
        bool matchesCategory = true;

          if (currentCategory == 'Kiloan') {
            matchesCategory = product.unit.toLowerCase() == 'kg';
          } else if (currentCategory == 'Satuan') {
            matchesCategory = product.unit.toLowerCase() != 'kg';
          }
        
        return matchesQuery && matchesCategory;
      }).toList();

      emit(currentState.copyWith(
        filteredProducts: filtered,
        searchQuery: currentQuery,
        selectedCategory: currentCategory,
      ));
    }
  }

  // Add product to cart
  void addToCart(Product product) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      final currentCart = List<CartItem>.from(currentState.cartItems);

      // Check if product already in cart
      final existingIndex = currentCart.indexWhere((item) => item.product.id == product.id);

      if (existingIndex >= 0) {
        // Increment quantity
        final existingItem = currentCart[existingIndex];
        currentCart[existingIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + 1,
        );
      } else {
        // Add new item
        currentCart.add(CartItem(
          product: product,
          quantity: 1,
        ));
      }

      emit(currentState.copyWith(cartItems: currentCart));
    }
  }

  // Remove item from cart (decrement or remove)
  void removeFromCart(CartItem item) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      final currentCart = List<CartItem>.from(currentState.cartItems);

      final index = currentCart.indexWhere((i) => i.product.id == item.product.id);
      if (index >= 0) {
        if (currentCart[index].quantity > 1) {
          currentCart[index] = currentCart[index].copyWith(
            quantity: currentCart[index].quantity - 1,
          );
        } else {
          currentCart.removeAt(index);
        }
        emit(currentState.copyWith(cartItems: currentCart));
      }
    }
  }

  // Clear entire cart
  void clearCart() {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      emit(currentState.copyWith(cartItems: []));
    }
  }

  // Select a customer
  void selectCustomer(Customer? customer) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      emit(currentState.copyWith(
        selectedCustomer: customer,
        customerName: customer?.name ?? 'Walk-in Customer',
      ));
    }
  }

  // Set customer name (free text)
  void setCustomerName(String name) {
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      emit(currentState.copyWith(
        customerName: name,
        selectedCustomer: null, // Reset selected object if name changes manually
      ));
    }
  }

  // Update quantity directly (optional, if needed)
  void updateQuantity(Product product, int quantity) {
    // Implementation similiar to addToCart but setting specific quantity
  }
}
