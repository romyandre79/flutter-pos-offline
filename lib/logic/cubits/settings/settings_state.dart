import 'package:equatable/equatable.dart';

class StoreInfo {
  final String name;
  final String address;
  final String phone;
  final String invoicePrefix;
  final String fonnteToken;

  const StoreInfo({
    required this.name,
    required this.address,
    required this.phone,
    required this.invoicePrefix,
    required this.fonnteToken,
  });

  StoreInfo copyWith({
    String? name,
    String? address,
    String? phone,
    String? invoicePrefix,
    String? fonnteToken,
  }) {
    return StoreInfo(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      fonnteToken: fonnteToken ?? this.fonnteToken,
    );
  }
}

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final StoreInfo storeInfo;

  const SettingsLoaded({required this.storeInfo});

  @override
  List<Object?> get props => [storeInfo];
}

class SettingsUpdating extends SettingsState {}

class SettingsUpdated extends SettingsState {
  final String message;
  final StoreInfo storeInfo;

  const SettingsUpdated({
    required this.message,
    required this.storeInfo,
  });

  @override
  List<Object?> get props => [message, storeInfo];
}

class SettingsError extends SettingsState {
  final String message;

  const SettingsError({required this.message});

  @override
  List<Object?> get props => [message];
}
