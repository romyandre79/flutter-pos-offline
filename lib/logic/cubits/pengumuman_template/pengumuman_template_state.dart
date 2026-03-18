import 'package:equatable/equatable.dart';
import 'package:kreatif_otopart/data/models/pengumuman_template.dart';

abstract class PengumumanTemplateState extends Equatable {
  const PengumumanTemplateState();

  @override
  List<Object?> get props => [];
}

class PengumumanTemplateInitial extends PengumumanTemplateState {}

class PengumumanTemplateLoading extends PengumumanTemplateState {}

class PengumumanTemplateLoaded extends PengumumanTemplateState {
  final List<PengumumanTemplate> templates;

  const PengumumanTemplateLoaded(this.templates);

  @override
  List<Object?> get props => [templates];
}

class PengumumanTemplateError extends PengumumanTemplateState {
  final String message;

  const PengumumanTemplateError(this.message);

  @override
  List<Object?> get props => [message];
}

class PengumumanTemplateOperationSuccess extends PengumumanTemplateState {
  final String message;

  const PengumumanTemplateOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
