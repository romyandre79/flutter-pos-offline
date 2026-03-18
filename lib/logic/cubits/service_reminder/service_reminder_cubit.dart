import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:kreatif_otopart/data/models/service_reminder.dart';
import 'package:kreatif_otopart/data/repositories/service_reminder_repository.dart';

abstract class ServiceReminderState extends Equatable {
  const ServiceReminderState();

  @override
  List<Object?> get props => [];
}

class ServiceReminderInitial extends ServiceReminderState {}

class ServiceReminderLoading extends ServiceReminderState {}

class ServiceReminderLoaded extends ServiceReminderState {
  final List<ServiceReminder> reminders;

  const ServiceReminderLoaded(this.reminders);

  @override
  List<Object?> get props => [reminders];
}

class ServiceReminderError extends ServiceReminderState {
  final String message;

  const ServiceReminderError(this.message);

  @override
  List<Object?> get props => [message];
}

class ServiceReminderOperationSuccess extends ServiceReminderState {
  final String message;

  const ServiceReminderOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ServiceReminderCubit extends Cubit<ServiceReminderState> {
  final ServiceReminderRepository _repository;

  ServiceReminderCubit({required ServiceReminderRepository repository})
      : _repository = repository,
        super(ServiceReminderInitial());

  Future<void> loadReminders({String? status}) async {
    emit(ServiceReminderLoading());
    try {
      final reminders = await _repository.getAll(status: status);
      emit(ServiceReminderLoaded(reminders));
    } catch (e) {
      emit(ServiceReminderError(e.toString()));
    }
  }

  Future<void> markAsSent(int id) async {
    try {
      await _repository.markAsSent(id);
      final currentState = state;
      if (currentState is ServiceReminderLoaded) {
        final updatedReminders = currentState.reminders.map((r) {
          if (r.id == id) {
            return r.copyWith(isSent: true);
          }
          return r;
        }).toList();
        emit(ServiceReminderLoaded(updatedReminders));
      }
    } catch (e) {
      emit(ServiceReminderError(e.toString()));
    }
  }

  Future<void> cancelReminder(int id) async {
    try {
      await _repository.cancelReminder(id);
      loadReminders();
    } catch (e) {
      emit(ServiceReminderError(e.toString()));
    }
  }

  Future<void> deleteReminder(int id) async {
    try {
      await _repository.delete(id);
      loadReminders();
    } catch (e) {
      emit(ServiceReminderError(e.toString()));
    }
  }
}
