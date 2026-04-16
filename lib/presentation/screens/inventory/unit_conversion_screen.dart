import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos_offline/core/theme/app_theme.dart';
import 'package:kreatif_pos_offline/core/utils/currency_formatter.dart';
import 'package:kreatif_pos_offline/data/models/product.dart';
import 'package:kreatif_pos_offline/data/models/product_unit.dart';
import 'package:kreatif_pos_offline/data/repositories/product_repository.dart';
import 'package:kreatif_pos_offline/logic/cubits/product/product_cubit.dart';
import 'package:kreatif_pos_offline/logic/cubits/product/product_state.dart';

class UnitConversionScreen extends StatefulWidget {
  const UnitConversionScreen({super.key});

  @override
  State<UnitConversionScreen> createState() => _UnitConversionScreenState();
}

class _UnitConversionScreenState extends State<UnitConversionScreen> {
  Product? _selectedProduct;
  ProductUnit? _fromUnit;
  ProductUnit? _toUnit;
  final _qtyController = TextEditingController();
  bool _isConverting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konversi Satuan Stok', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppThemeColors.headerGradient),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductSelector(),
            if (_selectedProduct != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildConversionForm(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _selectedProduct != null
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ElevatedButton(
                onPressed: _isConverting ? null : _processConversion,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isConverting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Proses Konversi'),
              ),
            )
          : null,
    );
  }

  Widget _buildProductSelector() {
    return BlocBuilder<ProductCubit, ProductState>(
      builder: (context, state) {
        if (state is ProductLoaded) {
          final goods = state.products.where((p) => p.isGoods && p.units.length > 1).toList();
          return DropdownButtonFormField<Product>(
            value: _selectedProduct,
            decoration: const InputDecoration(
              labelText: 'Pilih Produk',
              prefixIcon: Icon(Icons.inventory_2),
            ),
            items: goods.map((p) {
              return DropdownMenuItem(value: p, child: Text(p.name));
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedProduct = val;
                _fromUnit = null;
                _toUnit = null;
              });
            },
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildConversionForm() {
    final units = _selectedProduct?.units ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            DropdownButtonFormField<ProductUnit>(
              value: _fromUnit,
              decoration: const InputDecoration(labelText: 'Dari Satuan (Sumber)'),
              items: units.map((u) {
                return DropdownMenuItem(value: u, child: Text('${u.unitName} (Stok: ${u.stock})'));
              }).toList(),
              onChanged: (val) => setState(() => _fromUnit = val),
            ),
            const SizedBox(height: AppSpacing.md),
            const Icon(Icons.arrow_downward, color: AppThemeColors.primary),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ProductUnit>(
              value: _toUnit,
              decoration: const InputDecoration(labelText: 'Ke Satuan (Tujuan)'),
              items: units.map((u) {
                return DropdownMenuItem(value: u, child: Text(u.unitName));
              }).toList(),
              onChanged: (val) => setState(() => _toUnit = val),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Jumlah yang dikonversi',
                helperText: 'Masukkan jumlah dalam satuan sumber',
              ),
            ),
            if (_fromUnit != null && _toUnit != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildMultiplierInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMultiplierInfo() {
    // Logic to calculate conversion factor based on multipliers
    double factor = 1.0;
    if (_fromUnit != null && _toUnit != null) {
       // Calculation: how many 'toUnit' in 1 'fromUnit'
       // If fromUnit is parent of toUnit: multiplier is from fromUnit? No, multiplier is on child.
       // The logic should be: Convert both to base unit (where multiplier = 1), then compare.
       // Or simpler: User just inputs the qty they want to move, and we use the relationship if any.
       // Let's assume for manual conversion, the user provides the "Multiplier" manually or we detect it.
       factor = _toUnit!.multiplier / _fromUnit!.multiplier;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppThemeColors.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.smRadius,
      ),
      child: Text(
        'Info: 1 ${_fromUnit!.unitName} = ${_fromUnit!.multiplier / _toUnit!.multiplier} ${_toUnit!.unitName}?',
        style: AppTypography.labelSmall,
      ),
    );
  }

  void _processConversion() async {
    if (_selectedProduct == null || _fromUnit == null || _toUnit == null || _qtyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lengkapi form terlebih dahulu')));
      return;
    }

    final fromQty = double.tryParse(_qtyController.text) ?? 0.0;
    if (fromQty <= 0) return;
    if (fromQty > _fromUnit!.stock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok sumber tidak mencukupi')));
      return;
    }

    setState(() => _isConverting = true);

    try {
      final repo = context.read<ProductRepository>();
      // Use the relationship: multiplier is qty of THIS unit per 1 parent unit.
      // E.g., Box (parent) -> Pcs (child, mult 12). 1 Box = 12 Pcs.
      // multiplier_factor = to.multiplier / from.multiplier ??
      
      final multiplier = _fromUnit!.multiplier / _toUnit!.multiplier; 

      await repo.convertUnit(
        productId: _selectedProduct!.id!,
        fromUnitId: _fromUnit!.id!,
        toUnitId: _toUnit!.id!,
        fromQty: fromQty,
        multiplier: multiplier,
      );

      if (mounted) {
        context.read<ProductCubit>().loadProducts();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konversi berhasil'), backgroundColor: AppThemeColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: AppThemeColors.error));
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }
}
