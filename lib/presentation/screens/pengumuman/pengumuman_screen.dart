import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/core/theme/app_theme.dart';
import 'package:kreatif_otopart/data/models/customer.dart';
import 'package:kreatif_otopart/logic/cubits/customer/customer_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/customer/customer_state.dart';
import 'package:kreatif_otopart/logic/cubits/settings/settings_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/settings/settings_state.dart';
import 'package:kreatif_otopart/data/models/pengumuman_template.dart';
import 'package:kreatif_otopart/logic/cubits/pengumuman_template/pengumuman_template_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/pengumuman_template/pengumuman_template_state.dart';
import 'package:url_launcher/url_launcher.dart';

class PengumumanScreen extends StatefulWidget {
  const PengumumanScreen({super.key});

  @override
  State<PengumumanScreen> createState() => _PengumumanScreenState();
}

class _PengumumanScreenState extends State<PengumumanScreen> {
  final TextEditingController _pesanController = TextEditingController();
  final Set<int> _selectedCustomerIds = {};
  bool _selectAll = false;
  List<Customer> _currentCustomerList = [];

  @override
  void initState() {
    super.initState();
    context.read<CustomerCubit>().loadCustomers();
    context.read<PengumumanTemplateCubit>().loadTemplates();
  }

  @override
  void dispose() {
    _pesanController.dispose();
    super.dispose();
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selectedCustomerIds.addAll(
            _currentCustomerList.where((c) => c.id != null && c.phone != null && c.phone!.isNotEmpty).map((c) => c.id!));
      } else {
        _selectedCustomerIds.clear();
      }
    });
  }

  void _toggleCustomerSelection(int customerId, bool? value) {
    setState(() {
      if (value == true) {
        _selectedCustomerIds.add(customerId);
      } else {
        _selectedCustomerIds.remove(customerId);
      }
      
      final customerWithPhoneCount = _currentCustomerList.where((c) => c.id != null && c.phone != null && c.phone!.isNotEmpty).length;
      _selectAll = _selectedCustomerIds.length == customerWithPhoneCount && _currentCustomerList.isNotEmpty;
    });
  }

  Future<void> _sendPengumuman() async {
    final pesan = _pesanController.text.trim();
    if (pesan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesan tidak boleh kosong')),
      );
      return;
    }

    if (_selectedCustomerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu pelanggan')),
      );
      return;
    }

    final selectedCustomers = _currentCustomerList
        .where((c) => c.id != null && _selectedCustomerIds.contains(c.id))
        .toList();

    // Check for fonnte token
    final settingsState = context.read<SettingsCubit>().state;
    String fonnteToken = '';
    if (settingsState is SettingsLoaded) {
      fonnteToken = settingsState.storeInfo.fonnteToken;
    } else if (settingsState is SettingsUpdated) {
      fonnteToken = settingsState.storeInfo.fonnteToken;
    } else {
      fonnteToken = context.read<SettingsCubit>().currentInfo?.fonnteToken ?? '';
    }

    if (fonnteToken.isEmpty) {
       // Fallback to manual WhatsApp opening if no token is set
       _sendManualWhatsapp(pesan, selectedCustomers);
       return;
    }

    // Direct send via Fonnte API
    _sendDirectWhatsapp(pesan, selectedCustomers, fonnteToken);
  }

  Future<void> _sendDirectWhatsapp(String pesan, List<Customer> selectedCustomers, String token) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Prepare phone numbers
    List<String> validNumbers = [];
    for (final customer in selectedCustomers) {
      if (customer.phone == null || customer.phone!.isEmpty) continue;
      
      String phone = customer.phone!.replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.startsWith('0')) {
        phone = '62${phone.substring(1)}';
      } else if (!phone.startsWith('62')) {
        phone = '62$phone';
      }
      validNumbers.add(phone);
    }

    if (validNumbers.isEmpty) {
      if (mounted) Navigator.pop(context); // hide loading
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada nomor HP valid untuk dikirim.')),
      );
      return;
    }

    try {
      // Fonnte API endpoint for sending messages
      final url = Uri.parse('https://api.fonnte.com/send');
      final target = validNumbers.join(',');

      final response = await http.post(
        url,
        headers: {
          'Authorization': token,
        },
        body: {
          'target': target,
          'message': pesan,
        }
      );

      if (mounted) Navigator.pop(context); // hide loading

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selesai. Pesan berhasil dikirim ke ${validNumbers.length} nomor.'), backgroundColor: AppThemeColors.success),
          );
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengirim via Fonnte: ${data['reason']}'), backgroundColor: AppThemeColors.error),
          );
        }
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error server Fonnte: ${response.statusCode}'), backgroundColor: AppThemeColors.error),
         );
      }

    } catch (e) {
      if (mounted) Navigator.pop(context); // hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: AppThemeColors.error),
      );
    }
  }

  Future<void> _sendManualWhatsapp(String pesan, List<Customer> selectedCustomers) async {
    int successCount = 0;

    for (final customer in selectedCustomers) {
      if (customer.phone == null || customer.phone!.isEmpty) {
        continue;
      }

      String phone = customer.phone!.replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.startsWith('0')) {
        phone = '62${phone.substring(1)}';
      } else if (!phone.startsWith('62')) {
        phone = '62$phone';
      }

      final urlString = 'https://wa.me/$phone?text=${Uri.encodeComponent(pesan)}';
      final url = Uri.parse(urlString);

      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          successCount++;
          // Add a delay between opening links so that they can be handled individually by the browser/app.
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        // Ignore error
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Selesai. Membuka WA untuk $successCount pelanggan.'),
        ),
      );
    }
  }

  void _showSaveTemplateDialog() {
    final pesan = _pesanController.text.trim();
    if (pesan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tulis pesan pengumuman terlebih dahulu')),
      );
      return;
    }

    final judulController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<PengumumanTemplateCubit>(),
        child: AlertDialog(
          title: const Text('Simpan sebagai Template'),
          content: TextField(
            controller: judulController,
            decoration: const InputDecoration(
              hintText: 'Judul Template (misal: Tagihan Servis)',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
               onPressed: () => Navigator.pop(dialogContext),
               child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final judul = judulController.text.trim();
                if (judul.isEmpty) {
                   ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Judul tidak boleh kosong')),
                   );
                   return;
                }
                final template = PengumumanTemplate(judul: judul, isi: pesan);
                context.read<PengumumanTemplateCubit>().addTemplate(template);
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppThemeColors.primary),
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      )
    );
  }

  void _showTemplatesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) {
        return BlocProvider.value(
          value: context.read<PengumumanTemplateCubit>(),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Template Tersimpan', style: AppTypography.titleLarge),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogContext),
                        )
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: BlocConsumer<PengumumanTemplateCubit, PengumumanTemplateState>(
                    listener: (context, state) {
                      if (state is PengumumanTemplateOperationSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(state.message), backgroundColor: AppThemeColors.success),
                        );
                      } else if (state is PengumumanTemplateError) {
                         ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(state.message), backgroundColor: AppThemeColors.error),
                        );
                      }
                    },
                    builder: (context, state) {
                      if (state is PengumumanTemplateLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state is PengumumanTemplateLoaded) {
                        if (state.templates.isEmpty) {
                          return const Center(child: Text('Belum ada template tersimpan'));
                        }

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: state.templates.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final template = state.templates[index];
                            return ListTile(
                              title: Text(template.judul, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                              subtitle: Text(template.isi, maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: () {
                                _pesanController.text = template.isi;
                                Navigator.pop(context);
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppThemeColors.error),
                                onPressed: () {
                                  context.read<PengumumanTemplateCubit>().deleteTemplate(template.id!);
                                },
                              ),
                            );
                          },
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                )
              ],
            );
          },
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      appBar: AppBar(
        title: const Text('Kirim Pengumuman'),
        backgroundColor: AppThemeColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
             icon: const Icon(Icons.bookmarks),
             tooltip: 'Template Tersimpan',
             onPressed: _showTemplatesModal,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: Colors.white,
            child: TextField(
              controller: _pesanController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tulis pesan pengumuman di sini...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppThemeColors.background,
                suffixIcon: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.save_outlined),
                      tooltip: 'Simpan sebagai Template',
                      color: AppThemeColors.primary,
                      onPressed: _showSaveTemplateDialog,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppThemeColors.primary.withValues(alpha: 0.05),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _selectAll,
                  onChanged: _toggleSelectAll,
                  activeColor: AppThemeColors.primary,
                ),
                Text(
                  'Pilih Semua Pelanggan',
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_selectedCustomerIds.length} Terpilih',
                  style: AppTypography.labelMedium.copyWith(color: AppThemeColors.primary),
                ),
              ],
            ),
          ),

          Expanded(
            child: BlocConsumer<CustomerCubit, CustomerState>(
              listener: (context, state) {
                if (state is CustomerLoaded) {
                  setState(() {
                    _currentCustomerList = state.customers;
                  });
                }
              },
              builder: (context, state) {
                if (state is CustomerLoading && _currentCustomerList.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: AppThemeColors.primary));
                }
                if (state is CustomerError) {
                  return Center(child: Text(state.message));
                }
                
                if (_currentCustomerList.isEmpty) {
                   return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: AppThemeColors.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text('Belum ada data pelanggan', style: AppTypography.bodyMedium.copyWith(color: AppThemeColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: _currentCustomerList.length,
                  itemBuilder: (context, index) {
                    final customer = _currentCustomerList[index];
                    final isSelected = customer.id != null && _selectedCustomerIds.contains(customer.id);
                    final hasPhone = customer.phone != null && customer.phone!.isNotEmpty;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppThemeColors.primarySurface,
                        child: const Icon(Icons.person, color: AppThemeColors.primary),
                      ),
                      title: Text(customer.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        hasPhone ? customer.phone! : 'Tidak ada no. HP',
                        style: TextStyle(color: hasPhone ? AppThemeColors.textSecondary : AppThemeColors.error),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: hasPhone ? (value) => _toggleCustomerSelection(customer.id!, value) : null,
                        activeColor: AppThemeColors.primary,
                      ),
                      onTap: hasPhone ? () => _toggleCustomerSelection(customer.id!, !isSelected) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) {
              bool hasFonnte = false;
              if (state is SettingsLoaded && state.storeInfo.fonnteToken.isNotEmpty) {
                 hasFonnte = true;
              } else if (state is SettingsUpdated && state.storeInfo.fonnteToken.isNotEmpty) {
                 hasFonnte = true;
              } else if (context.read<SettingsCubit>().currentInfo?.fonnteToken.isNotEmpty == true) {
                 hasFonnte = true;
              }

              return ElevatedButton.icon(
                onPressed: _sendPengumuman,
                icon: const Icon(Icons.send),
                label: Text(hasFonnte ? 'Kirim Langsung (Fonnte)' : 'Kirim via Aplikasi WA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
              );
            }
          ),
        ),
      ),
    );
  }
}
