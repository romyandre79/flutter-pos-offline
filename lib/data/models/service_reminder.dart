import 'package:equatable/equatable.dart';

class ServiceReminder extends Equatable {
  final int? id;
  final int? customerId;
  final String customerName;
  final String? customerPhone;
  final int? orderId;
  final String? noPol;
  final int? productId;
  final String productName;
  final int? lastServiceKm;
  final int reminderKm;
  final bool isSent;
  final String status; // active, completed, cancelled
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ServiceReminder({
    this.id,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.orderId,
    this.noPol,
    this.productId,
    required this.productName,
    this.lastServiceKm,
    required this.reminderKm,
    this.isSent = false,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'order_id': orderId,
      'no_pol': noPol,
      'product_id': productId,
      'product_name': productName,
      'last_service_km': lastServiceKm,
      'reminder_km': reminderKm,
      'is_sent': isSent ? 1 : 0,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ServiceReminder.fromMap(Map<String, dynamic> map) {
    return ServiceReminder(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String,
      customerPhone: map['customer_phone'] as String?,
      orderId: map['order_id'] as int?,
      noPol: map['no_pol'] as String?,
      productId: map['product_id'] as int?,
      productName: map['product_name'] as String,
      lastServiceKm: map['last_service_km'] as int?,
      reminderKm: map['reminder_km'] as int,
      isSent: (map['is_sent'] as int?) == 1,
      status: (map['status'] as String?) ?? 'active',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  ServiceReminder copyWith({
    int? id,
    int? customerId,
    String? customerName,
    String? customerPhone,
    int? orderId,
    String? noPol,
    int? productId,
    String? productName,
    int? lastServiceKm,
    int? reminderKm,
    bool? isSent,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceReminder(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      orderId: orderId ?? this.orderId,
      noPol: noPol ?? this.noPol,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      lastServiceKm: lastServiceKm ?? this.lastServiceKm,
      reminderKm: reminderKm ?? this.reminderKm,
      isSent: isSent ?? this.isSent,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        customerId,
        customerName,
        customerPhone,
        orderId,
        noPol,
        productId,
        productName,
        lastServiceKm,
        reminderKm,
        isSent,
        status,
        createdAt,
        updatedAt,
      ];
}
