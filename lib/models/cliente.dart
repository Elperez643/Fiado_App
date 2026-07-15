class Cliente {
  final int? id;
  String nombre;
  String telefono;
  double deuda;

  Cliente({
    this.id,
    required this.nombre,
    required this.telefono,
    this.deuda = 0,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'nombre': nombre, 'telefono': telefono, 'deuda': deuda};
  }

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: (json['id'] as num?)?.toInt(),
      nombre: json['nombre'] as String,
      telefono: json['telefono'] as String,
      deuda: (json['deuda'] as num?)?.toDouble() ?? 0,
    );
  }
}
