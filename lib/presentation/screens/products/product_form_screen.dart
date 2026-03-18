import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:kreatif_otopart/core/theme/app_theme.dart';
import 'package:kreatif_otopart/data/models/product.dart';
import 'package:kreatif_otopart/logic/cubits/product/product_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/auth/auth_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_otopart/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_otopart/data/models/user.dart';
import 'package:kreatif_otopart/data/models/unit.dart';
import 'package:kreatif_otopart/logic/cubits/unit/unit_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/unit/unit_state.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  late TextEditingController _stockController;
  late TextEditingController _durationController;
  late TextEditingController _descriptionController;
  late TextEditingController _barcodeController;
  late TextEditingController _expireDateController;
  late TextEditingController _expireKmController;
  
  File? _imageFile;
  // final ImagePicker _picker = ImagePicker(); // Removed

  ProductType _selectedType = ProductType.service;
  String _selectedUnit = 'pcs';

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name);
    _priceController = TextEditingController(text: product?.price.toString());
    _costController = TextEditingController(text: product?.cost.toString() ?? '0');
    _stockController = TextEditingController(text: product?.stock?.toString() ?? '0');
    _durationController = TextEditingController(text: product?.durationDays?.toString() ?? '3');
    _descriptionController = TextEditingController(text: product?.description);
    _barcodeController = TextEditingController(text: product?.barcode);
    _expireDateController = TextEditingController(text: product?.expireDate?.toString() ?? '');
    _expireKmController = TextEditingController(text: product?.expireKm?.toString() ?? '');

    if (product != null) {
      _selectedType = product.type;
      _selectedUnit = product.unit;
      if (product.imageUrl != null) {
        _imageFile = File(product.imageUrl!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    _barcodeController.dispose();
    _expireDateController.dispose();
    _expireKmController.dispose();
    super.dispose();
  }



// ...

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'heic'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final processedFile = await _processImage(file);
        
        setState(() {
          _imageFile = processedFile;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e'), backgroundColor: AppThemeColors.error),
        );
      }
    }
  }

  Future<File> _processImage(File file) async {
    final ext = path.extension(file.path).toLowerCase();
    
    // Check if HEIC/HEIF
    if (ext == '.heic' || ext == '.heif') {
      try {
        // Prepare target path
        final tempDir = await getTemporaryDirectory();
        final targetPath = '${tempDir.path}/${path.basenameWithoutExtension(file.path)}.jpg';
        
        // Convert using flutter_image_compress (Mobile/MacOS)
        // On Windows this might throw or fail if not supported, so we wrap in try-catch
        if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
            final result = await FlutterImageCompress.compressAndGetFile(
              file.absolute.path,
              targetPath,
              quality: 85,
              format: CompressFormat.jpeg,
            );
            
            if (result != null) {
              return File(result.path);
            }
        }
        
        // Fallback for Windows or if conversion failed (return original and hope OS supports it)
        // Note: Windows 10/11 with HEIF extension can display HEIC, but Flutter 'Image.file' might still struggle 
        // without a specific decoder. However, standard 'FileImage' uses the engine's decoder.
        return file;
        
      } catch (e) {
        debugPrint('Error converting HEIC: $e');
        return file; // Return original if conversion fails
      }
    }
    
    return file; // Not HEIC, return as is
  }

  Future<String?> _saveImage() async {
    if (_imageFile == null) return null;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      // Ensure specific images directory exists
      final imagesDir = Directory('${appDir.path}/product_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      final fileName = path.basename(_imageFile!.path);
      final savedImage = await _imageFile!.copy('${imagesDir.path}/$fileName');
      return savedImage.path;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return _imageFile?.path;
    }
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final price = int.parse(_priceController.text);
      final cost = int.parse(_costController.text);
      final description = _descriptionController.text;
      
      final imagePath = await _saveImage();
      if (!mounted) return;
      
      final product = Product(
        id: widget.product?.id,
        name: name,
        description: description.isEmpty ? null : description,
        price: price,
        cost: cost,
        barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
        unit: _selectedUnit,
        type: _selectedType,
        // Optional fields based on type
        stock: _selectedType == ProductType.goods 
            ? double.tryParse(_stockController.text) ?? 0.0 
            : null,
        durationDays: _selectedType == ProductType.service 
            ? int.tryParse(_durationController.text) ?? 1 
            : null,
        imageUrl: imagePath ?? widget.product?.imageUrl,
        expireDate: int.tryParse(_expireDateController.text),
        expireKm: int.tryParse(_expireKmController.text),
      );

      if (widget.product == null) {
        context.read<ProductCubit>().addProduct(product);
      } else {
        context.read<ProductCubit>().updateProduct(product);
      }

      Navigator.pop(context);
    }
  }

  void _deleteProduct() {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hapus Item?'),
          content: const Text('Apakah Anda yakin ingin menghapus item ini? Tindakan ini tidak dapat dibatalkan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                if (widget.product?.id != null) {
                   context.read<ProductCubit>().deleteProduct(widget.product!.id!);
                   Navigator.pop(context); // Close screen
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.product == null ? 'Tambah Item' : 'Ubah Item',
          style: AppTypography.headlineMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppThemeColors.headerGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.product != null && context.read<AuthCubit>().state is AuthAuthenticated && (context.read<AuthCubit>().state as AuthAuthenticated).user.role == UserRole.owner)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteProduct,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: AppRadius.lgRadius,
                      image: _imageFile != null
                          ? DecorationImage(
                              image: FileImage(_imageFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      border: Border.all(color: AppThemeColors.border),
                    ),
                    child: _imageFile == null
                        ? const Icon(Icons.add_a_photo, size: 40, color: AppThemeColors.textSecondary)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Type Selector
              Text('Tipe Item', style: AppTypography.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeRadio(ProductType.service),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _buildTypeRadio(ProductType.goods),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Item',
                  hintText: 'Contoh: Cuci Kering atau Sabun',
                  prefixIcon: Icon(
                    _selectedType == ProductType.service ? Icons.category_outlined : Icons.inventory_2_outlined,
                    color: AppThemeColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mdRadius,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.mdRadius,
                    borderSide: BorderSide(color: AppThemeColors.border),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama item tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Barcode
              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Barcode (Opsional)',
                  hintText: 'Scan atau ketik barcode',
                  prefixIcon: const Icon(Icons.qr_code, color: AppThemeColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mdRadius,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.mdRadius,
                    borderSide: BorderSide(color: AppThemeColors.border),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Unit
              BlocBuilder<UnitCubit, UnitState>(
                builder: (context, state) {
                   List<Unit> units = [];
                   if (state is UnitLoaded) {
                     units = state.units;
                   } else if (state is UnitOperationSuccess) {
                     units = state.units;
                   }
                   
                   // Helper to check if current selected unit is valid
                   final isValid = units.any((u) => u.name == _selectedUnit);
                   
                   return DropdownButtonFormField<String>(
                    value: isValid ? _selectedUnit : null,
                    items: units.map((unit) {
                      return DropdownMenuItem(
                        value: unit.name,
                        child: Text(unit.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedUnit = val);
                    },
                    decoration: InputDecoration(
                      labelText: 'Satuan',
                      hintText: 'Pilih Satuan',
                      prefixIcon: const Icon(Icons.straighten, color: AppThemeColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.mdRadius,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.mdRadius,
                        borderSide: BorderSide(color: AppThemeColors.border),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Satuan tidak boleh kosong';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Price & Cost Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Harga Jual',
                        prefixText: 'Rp ',
                        prefixIcon: const Icon(Icons.sell_outlined, color: AppThemeColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.mdRadius,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Harga tidak boleh kosong';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Harga harus berupa angka';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Modal (Opsional)',
                        prefixText: 'Rp ',
                        prefixIcon: const Icon(Icons.attach_money, color: AppThemeColors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.mdRadius,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Conditional Fields
              if (_selectedType == ProductType.service) ...[
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Estimasi Pengerjaan (Hari)',
                    prefixIcon: const Icon(Icons.schedule, color: AppThemeColors.primary),
                    suffixText: 'Hari',
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdRadius,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Estimasi tidak boleh kosong';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Harus berupa angka';
                    }
                    return null;
                  },
                ),
              ],
              
              if (_selectedType == ProductType.goods) ...[
                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Stok Awal',
                    prefixIcon: const Icon(Icons.inventory, color: AppThemeColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdRadius,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Stok tidak boleh kosong';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Harus berupa angka';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expireDateController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Jumlah Hari Kedaluwarsa',
                        prefixIcon: const Icon(Icons.inventory, color: AppThemeColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.mdRadius,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Jumlah Hari tidak boleh kosong';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Harus berupa angka';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: TextFormField(
                      controller: _expireKmController,
                      keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Kilometer Kedaluwarsa',
                  prefixIcon: const Icon(Icons.inventory, color: AppThemeColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mdRadius,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Kilometer tidak boleh kosong';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Harus berupa angka';
                  }
                  return null;
                },
              ),
              ),
                ]),
              const SizedBox(height: AppSpacing.lg),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Deskripsi (Opsional)',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.description_outlined, color: AppThemeColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mdRadius,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdRadius,
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Simpan',
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeRadio(ProductType type) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppThemeColors.primary : Colors.white,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(
            color: isSelected ? AppThemeColors.primary : AppThemeColors.border,
          ),
        ),
        child: Center(
          child: Text(
            type.displayName,
            style: AppTypography.labelMedium.copyWith(
              color: isSelected ? Colors.white : AppThemeColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
