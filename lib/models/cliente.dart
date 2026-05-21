class Cliente {
  String nombre;
  String telefono;
  double deuda;

  Cliente({
    required this.nombre,
    required this.telefono,
    this.deuda = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'deuda': deuda,
    };
  }

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      nombre: json['nombre'],
      telefono: json['telefono'],
      deuda: json['deuda'],
    );
  }
}
