import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/core/theme/app_theme.dart';
import 'package:kreatif_otopart/core/utils/currency_formatter.dart';
import 'package:kreatif_otopart/data/models/order_item.dart';
import 'package:kreatif_otopart/data/models/payment.dart';
import 'package:kreatif_otopart/logic/cubits/order/order_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/order/order_state.dart';
import 'package:kreatif_otopart/logic/cubits/pos/pos_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/pos/pos_state.dart';
import 'package:kreatif_otopart/data/models/customer.dart';
import 'package:kreatif_otopart/data/repositories/customer_repository.dart';
import 'package:kreatif_otopart/data/models/order.dart'; // Add OrderStatus import
import 'package:kreatif_otopart/presentation/widgets/payment_dialog.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  void _handleCharge(BuildContext context, int totalAmount) {
    // Capture the cubit from the current context
    final posCubit = context.read<PosCubit>();
    final state = posCubit.state;

    if (state is! PosLoaded) return;

    // Validate Status and Stock
    for (final item in state.cartItems) {
      if (item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jumlah item tidak boleh 0'),
            backgroundColor: AppThemeColors.error,
          ),
        );
        return;
      }

      if (item.product.isGoods) {
        final currentStock = item.product.stock ?? 0;
        if (item.quantity > currentStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Stok ${item.product.name} tidak mencukupi (Sisa: ${currentStock.toStringAsFixed(0)})'),
              backgroundColor: AppThemeColors.error,
            ),
          );
          return;
        }
      }
    }
    
    showDialog(
      context: context,
      builder: (ctx) => PaymentDialog(
        totalAmount: totalAmount,
        onConfirm: (paidAmount, paymentMethod, status, dueDate) {
          // Use the captured cubit
          _processCheckout(context, posCubit, paidAmount, paymentMethod, status, dueDate);
        },
      ),
    );
  }

  void _processCheckout(
    BuildContext context,
    PosCubit posCubit,
    int paidAmount,
    PaymentMethod paymentMethod,
    OrderStatus status,
    DateTime? dueDate,
  ) {
    final posState = posCubit.state;
    if (posState is! PosLoaded) return;

    final cartItems = posState.cartItems;
    if (cartItems.isEmpty) return;

    // Convert CartItems to OrderItems
    final orderItems = cartItems.map((item) {
      return OrderItem(
        orderId: 0, // Placeholder
        productId: item.product.id,
        serviceName: item.product.name, // Using serviceName for product name compatibility
        quantity: item.quantity.toDouble(),
        unit: item.product.unit,
        pricePerUnit: item.product.price,
        subtotal: item.subtotal,
      );
    }).toList();

    context.read<OrderCubit>().createOrder(
      customerName: posState.customerName, 
      customerId: posState.selectedCustomer?.id,
      customerPhone: posState.selectedCustomer?.phone,
      items: orderItems,
      dueDate: dueDate, // Pass the selected due date
      initialPayment: paidAmount,
      paymentMethod: paymentMethod,
      status: status,
      createdBy: 1, // TODO: Get from AuthCubit
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderCubit, OrderState>(
      listener: (context, state) {
        if (state is OrderCreated) {
          context.read<PosCubit>().clearCart();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Penjualan ${state.order.invoiceNo} berhasil dibuat'),
              backgroundColor: AppThemeColors.success,
            ),
          );
        } else if (state is OrderError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppThemeColors.error,
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            left: BorderSide(color: AppThemeColors.border),
          ),
        ),
        child: Column(
          children: [
            // Customer Selector
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: _CustomerSelector(),
            ),
            
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppThemeColors.border),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daftar Penjualan',
                    style: AppTypography.titleMedium,
                  ),

                ],
              ),
            ),
            
            // Cart Items List
            Expanded(
              child: BlocBuilder<PosCubit, PosState>(
                builder: (context, state) {
                  if (state is PosLoaded) {
                    if (state.cartItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              size: 48,
                              color: AppThemeColors.disabled,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Keranjang Masih Kosong',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppThemeColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: state.cartItems.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = state.cartItems[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Quantity Controls
                              Column(
                                children: [
                                  InkWell(
                                    onTap: () => context.read<PosCubit>().addToCart(item.product),
                                    child: const Icon(Icons.add_circle, color: AppThemeColors.primary, size: 20),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text('${item.quantity}', style: AppTypography.labelLarge),
                                  ),
                                  InkWell(
                                    onTap: () => context.read<PosCubit>().removeFromCart(item),
                                    child: const Icon(Icons.remove_circle, color: AppThemeColors.error, size: 20),
                                  ),
                                ],
                              ),
                              const SizedBox(width: AppSpacing.md),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name, style: AppTypography.bodyMedium),
                                    Text(
                                      '@ ${CurrencyFormatter.format(item.product.price)}',
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              // Subtotal
                              Text(
                                CurrencyFormatter.format(item.subtotal),
                                style: AppTypography.labelLarge,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),

            // Footer (Total & Checkout)
            BlocBuilder<PosCubit, PosState>(
              builder: (context, state) {
                int total = 0;
                if (state is PosLoaded) {
                   total = state.totalAmount;
                }

                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: AppTypography.titleMedium),
                          Text(
                            CurrencyFormatter.format(total),
                            style: AppTypography.titleLarge.copyWith(color: AppThemeColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          ),
                          onPressed: total > 0 
                            ? () => _handleCharge(context, total)
                            : null,
                          child: Text(
                             total > 0 ? 'Bayar ${CurrencyFormatter.format(total)}' : 'Bayar',
                             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerSelector extends StatefulWidget {
  const _CustomerSelector();

  @override
  State<_CustomerSelector> createState() => _CustomerSelectorState();
}

class _CustomerSelectorState extends State<_CustomerSelector> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        if (state is! PosLoaded) return const SizedBox.shrink();

        final selectedCustomer = state.selectedCustomer;

        if (selectedCustomer != null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppThemeColors.primary.withValues(alpha: 0.05),
              borderRadius: AppRadius.mdRadius,
              border: Border.all(color: AppThemeColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: AppThemeColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedCustomer.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (selectedCustomer.phone != null)
                        Text(
                          selectedCustomer.phone!,
                          style: AppTypography.labelSmall.copyWith(color: AppThemeColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppThemeColors.textSecondary),
                  onPressed: () {
                    context.read<PosCubit>().selectCustomer(null);
                  },
                ),
              ],
            ),
          );
        }

        return Autocomplete<Customer>(
          displayStringForOption: (Customer option) => option.name,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<Customer>.empty();
            }
            return context.read<CustomerRepository>().searchCustomers(textEditingValue.text);
          },
          onSelected: (Customer selection) {
            context.read<PosCubit>().selectCustomer(selection);
          },
          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Nama / No HP Pelanggan',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdRadius,
                  borderSide: const BorderSide(color: AppThemeColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdRadius,
                  borderSide: const BorderSide(color: AppThemeColors.border),
                ),
              ),
              onChanged: (value) {
                context.read<PosCubit>().setCustomerName(value);
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: AppRadius.mdRadius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300), 
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Customer option = options.elementAt(index);
                      return ListTile(
                        title: Text(option.name),
                        subtitle: option.phone != null ? Text(option.phone!) : null,
                        onTap: () {
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
