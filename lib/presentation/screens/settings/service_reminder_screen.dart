import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kreatif_otopart/core/theme/app_theme.dart';
import 'package:kreatif_otopart/data/models/service_reminder.dart';
import 'package:kreatif_otopart/logic/cubits/service_reminder/service_reminder_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/settings/settings_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/settings/settings_state.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:kreatif_otopart/logic/cubits/pengumuman_template/pengumuman_template_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/pengumuman_template/pengumuman_template_state.dart';
import 'package:kreatif_otopart/data/models/pengumuman_template.dart';

class ServiceReminderScreen extends StatefulWidget {
  const ServiceReminderScreen({super.key});

  @override
  State<ServiceReminderScreen> createState() => _ServiceReminderScreenState();
}

class _ServiceReminderScreenState extends State<ServiceReminderScreen> {
  String _selectedFilter = 'active';

  @override
  void initState() {
    super.initState();
    context.read<ServiceReminderCubit>().loadReminders(status: _selectedFilter);
  }

  Future<void> _sendReminder(ServiceReminder reminder, String token) async {
    final templatesState = context.read<PengumumanTemplateCubit>().state;
    List<PengumumanTemplate> templates = [];
    if (templatesState is PengumumanTemplateLoaded) {
      templates = templatesState.templates;
    }

    if (templates.isEmpty) {
      // Default message if no templates
      final defaultMessage = 'Halo ${reminder.customerName}, kendaran dengan No.Pol ${reminder.noPol ?? "-"} sudah waktunya service berkala untuk ${reminder.productName}. Terakhir service di KM ${reminder.lastServiceKm}. Silakan datang ke bengkel kami. Terima kasih.';
      await _processSend(reminder, defaultMessage, token);
    } else {
      // Show template picker
      _showTemplatePicker(reminder, templates, token);
    }
  }

  void _showTemplatePicker(ServiceReminder reminder, List<PengumumanTemplate> templates, String token) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Template Pesan',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    return ListTile(
                      title: Text(template.judul),
                      subtitle: Text(
                        template.isi,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        String finalMessage = template.isi
                            .replaceAll('[NAMA]', reminder.customerName)
                            .replaceAll('[NOPOL]', reminder.noPol ?? '-')
                            .replaceAll('[PRODUK]', reminder.productName)
                            .replaceAll('[KM_LAST]', reminder.lastServiceKm?.toString() ?? '0')
                            .replaceAll('[KM_NEXT]', reminder.reminderKm.toString());
                        
                        _processSend(reminder, finalMessage, token);
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.message_outlined),
                title: const Text('Gunakan Pesan Default'),
                onTap: () {
                  Navigator.pop(context);
                  final defaultMessage = 'Halo ${reminder.customerName}, kendaran dengan No.Pol ${reminder.noPol ?? "-"} sudah waktunya service berkala untuk ${reminder.productName}. Terakhir service di KM ${reminder.lastServiceKm}. Silakan datang ke bengkel kami. Terima kasih.';
                  _processSend(reminder, defaultMessage, token);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processSend(ServiceReminder reminder, String message, String token) async {
    final phone = reminder.customerPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer tidak memiliki nomor HP.')),
      );
      return;
    }

    String formattedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '62${formattedPhone.substring(1)}';
    } else if (!formattedPhone.startsWith('62')) {
      formattedPhone = '62$formattedPhone';
    }

    if (token.isNotEmpty) {
      // Use Fonnte
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final url = Uri.parse('https://api.fonnte.com/send');
        final response = await http.post(
          url,
          headers: {'Authorization': token},
          body: {
            'target': formattedPhone,
            'message': message,
          },
        );

        if (mounted) Navigator.pop(context); // hide loading

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder berhasil dikirim via Fonnte.')),
          );
          context.read<ServiceReminderCubit>().markAsSent(reminder.id!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengirim via Fonnte: ${response.body}')),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } else {
      // Fallback to WhatsApp
      final whatsappUrl = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
        context.read<ServiceReminderCubit>().markAsSent(reminder.id!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        String token = '';
        if (settingsState is SettingsLoaded) {
          token = settingsState.storeInfo.fonnteToken ?? '';
        }

        return Scaffold(
          backgroundColor: AppThemeColors.background,
          appBar: AppBar(
            title: const Text('Reminder Service Berkala'),
            backgroundColor: AppThemeColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: BlocBuilder<ServiceReminderCubit, ServiceReminderState>(
                  builder: (context, state) {
                    if (state is ServiceReminderLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is ServiceReminderError) {
                      return Center(child: Text(state.message));
                    }

                    if (state is ServiceReminderLoaded) {
                      if (state.reminders.isEmpty) {
                        return const Center(child: Text('Tidak ada reminder.'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.reminders.length,
                        itemBuilder: (context, index) {
                          final reminder = state.reminders[index];
                          return _buildReminderCard(reminder, token);
                        },
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          _filterChip('Aktif', 'active'),
          const SizedBox(width: 8),
          _filterChip('Terkirim', 'sent'), // This is handled via isSent? No, I use status.
          // Wait, I used isSent and status. Let's filter by status.
          const SizedBox(width: 8),
          _filterChip('Semua', null),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value ?? '';
          });
          context.read<ServiceReminderCubit>().loadReminders(status: value);
        }
      },
      selectedColor: AppThemeColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppThemeColors.textPrimary,
      ),
    );
  }

  Widget _buildReminderCard(ServiceReminder reminder, String token) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                color: reminder.isSent ? AppThemeColors.success : AppThemeColors.warning,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              reminder.customerName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppThemeColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppThemeColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              reminder.noPol ?? '-',
                              style: const TextStyle(
                                color: AppThemeColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reminder.productName,
                        style: TextStyle(
                          color: AppThemeColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildKmInfo('Terakhir', '${reminder.lastServiceKm} KM'),
                          const SizedBox(width: 24),
                          _buildKmInfo('Reminder', '${reminder.reminderKm} KM', color: AppThemeColors.error),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!reminder.isSent)
                            TextButton.icon(
                              onPressed: () => _sendReminder(reminder, token),
                              icon: Icon(token.isNotEmpty ? Icons.flash_on : Icons.message, size: 18),
                              label: Text(token.isNotEmpty ? 'Kirim Fonnte' : 'Buka WA'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppThemeColors.primary,
                              ),
                            ),
                          if (reminder.isSent)
                             const Text(
                               'Terkirim',
                               style: TextStyle(color: AppThemeColors.success, fontWeight: FontWeight.bold),
                             ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              context.read<ServiceReminderCubit>().deleteReminder(reminder.id!);
                            },
                            icon: const Icon(Icons.delete_outline, color: AppThemeColors.error),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKmInfo(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppThemeColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color ?? AppThemeColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
