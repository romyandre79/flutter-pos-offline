class PengumumanTemplate {
  final int? id;
  final String judul;
  final String isi;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PengumumanTemplate({
    this.id,
    required this.judul,
    required this.isi,
    this.createdAt,
    this.updatedAt,
  });

  factory PengumumanTemplate.fromMap(Map<String, dynamic> map) {
    return PengumumanTemplate(
      id: map['id'],
      judul: map['judul'] ?? '',
      isi: map['isi'] ?? '',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'judul': judul,
      'isi': isi,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  PengumumanTemplate copyWith({
    int? id,
    String? judul,
    String? isi,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PengumumanTemplate(
      id: id ?? this.id,
      judul: judul ?? this.judul,
      isi: isi ?? this.isi,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
