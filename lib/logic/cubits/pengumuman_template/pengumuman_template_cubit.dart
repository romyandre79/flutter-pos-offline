import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/data/models/pengumuman_template.dart';
import 'package:kreatif_otopart/data/repositories/pengumuman_template_repository.dart';
import 'package:kreatif_otopart/logic/cubits/pengumuman_template/pengumuman_template_state.dart';

class PengumumanTemplateCubit extends Cubit<PengumumanTemplateState> {
  final PengumumanTemplateRepository _repository;

  PengumumanTemplateCubit(this._repository) : super(PengumumanTemplateInitial());

  Future<void> loadTemplates() async {
    emit(PengumumanTemplateLoading());
    try {
      final templates = await _repository.getAll();
      emit(PengumumanTemplateLoaded(templates));
    } catch (e) {
      emit(PengumumanTemplateError('Gagal memuat template: $e'));
    }
  }

  Future<void> addTemplate(PengumumanTemplate template) async {
    // emit(PengumumanTemplateLoading()); // Optional: don't show loading overlay if it interrupts user flow
    try {
      await _repository.insert(template);
      emit(const PengumumanTemplateOperationSuccess('Template berhasil disimpan'));
      await loadTemplates(); // Reload the list
    } catch (e) {
      emit(PengumumanTemplateError('Gagal menyimpan template: $e'));
      await loadTemplates(); // Ensure we're back in a valid state
    }
  }

  Future<void> deleteTemplate(int id) async {
    // emit(PengumumanTemplateLoading());
    try {
      await _repository.delete(id);
      emit(const PengumumanTemplateOperationSuccess('Template berhasil dihapus'));
      await loadTemplates();
    } catch (e) {
      emit(PengumumanTemplateError('Gagal menghapus template: $e'));
      await loadTemplates();
    }
  }
}
