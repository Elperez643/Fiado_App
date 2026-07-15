import 'dart:math';

import '../models/producto.dart';
import '../utils/auditoria_helper.dart';

class PlanAuditoria {
  final DateTime fecha;
  final List<Producto> productos;
  final bool esPlanDeLunes;

  const PlanAuditoria({
    required this.fecha,
    required this.productos,
    required this.esPlanDeLunes,
  });

  int get cantidadObjetivo => esPlanDeLunes ? 5 : 3;
}

class InventarioService {
  final List<Producto> _productos;
  final Random _random;

  InventarioService({List<Producto> productos = const [], Random? random})
    : _productos = List<Producto>.from(productos),
      _random = random ?? Random();

  List<Producto> get productos => List<Producto>.unmodifiable(_productos);

  void reemplazarProductos(List<Producto> productos) {
    _productos
      ..clear()
      ..addAll(productos);
  }

  void agregarProducto(Producto producto) {
    _productos.add(producto);
  }

  bool eliminarProductoPorId(String id) {
    final indice = _productos.indexWhere((producto) => producto.id == id);

    if (indice == -1) {
      return false;
    }

    _productos.removeAt(indice);
    return true;
  }

  List<Producto> obtenerProductosAleatorios(int cantidad) {
    final disponibles = _productos
        .where(AuditoriaHelper.tieneDisponibilidadEnInventario)
        .toList(growable: false);
    return _seleccionarAleatorios(disponibles, cantidad);
  }

  List<Producto> obtenerProductosClaveAleatorios(int cantidad) {
    final productosClave = _productos
        .where(
          (producto) =>
              producto.esClave &&
              AuditoriaHelper.tieneDisponibilidadEnInventario(producto),
        )
        .toList(growable: false);
    return _seleccionarAleatorios(productosClave, cantidad);
  }

  PlanAuditoria generarPlanAuditoria({DateTime? fecha}) {
    final referencia = fecha ?? DateTime.now();
    final esLunes = AuditoriaHelper.esLunes(referencia);
    final cantidadObjetivo = esLunes ? 5 : 3;

    final candidatosBase = esLunes
        ? _productos
              .where(
                (producto) =>
                    producto.esClave &&
                    AuditoriaHelper.tieneDisponibilidadEnInventario(producto),
              )
              .toList()
        : _productos
              .where(AuditoriaHelper.tieneDisponibilidadEnInventario)
              .toList();

    final seleccion = _seleccionarParaAuditoria(
      candidatosBase,
      cantidadObjetivo,
      referencia: referencia,
    );

    return PlanAuditoria(
      fecha: referencia,
      productos: seleccion,
      esPlanDeLunes: esLunes,
    );
  }

  List<Producto> _seleccionarParaAuditoria(
    List<Producto> candidatos,
    int cantidad, {
    required DateTime referencia,
  }) {
    if (cantidad <= 0 || candidatos.isEmpty) {
      return const [];
    }

    final candidatosNoRecientes = candidatos
        .where(
          (producto) =>
              !_fueAuditadoRecientemente(producto, referencia: referencia),
        )
        .toList();

    final poolPrimario = candidatosNoRecientes.isNotEmpty
        ? candidatosNoRecientes
        : List<Producto>.from(candidatos);

    final ordenados = _ordenarPorPrioridadAuditoria(
      poolPrimario,
      referencia: referencia,
    );

    if (cantidad >= ordenados.length) {
      return ordenados;
    }

    return ordenados.take(cantidad).toList(growable: false);
  }

  List<Producto> _ordenarPorPrioridadAuditoria(
    List<Producto> candidatos, {
    required DateTime referencia,
  }) {
    final copia = List<Producto>.from(candidatos);
    copia.shuffle(_random);
    copia.sort((a, b) {
      final prioridadA = _calcularPrioridadAuditoria(a, referencia: referencia);
      final prioridadB = _calcularPrioridadAuditoria(b, referencia: referencia);

      return prioridadB.compareTo(prioridadA);
    });
    return copia;
  }

  int _calcularPrioridadAuditoria(
    Producto producto, {
    required DateTime referencia,
  }) {
    var prioridad = 0;

    if (producto.esClave) {
      prioridad += 100;
    }

    if (producto.ultimaVerificacion == null) {
      prioridad += 1000;
    } else {
      prioridad += referencia.difference(producto.ultimaVerificacion!).inHours;
    }

    return prioridad;
  }

  bool _fueAuditadoRecientemente(
    Producto producto, {
    required DateTime referencia,
  }) {
    if (producto.esClave && AuditoriaHelper.esLunes(referencia)) {
      return AuditoriaHelper.fueAuditadoEnUltimos15DiasConCierre(
        producto,
        referencia: referencia,
      );
    }

    return AuditoriaHelper.fueAuditadoEsteMesConCierre(
      producto,
      referencia: referencia,
    );
  }

  List<Producto> _seleccionarAleatorios(List<Producto> origen, int cantidad) {
    if (cantidad <= 0 || origen.isEmpty) {
      return const [];
    }

    if (cantidad >= origen.length) {
      final copia = List<Producto>.from(origen);
      copia.shuffle(_random);
      return copia;
    }

    final copia = List<Producto>.from(origen);
    copia.shuffle(_random);
    return copia.take(cantidad).toList(growable: false);
  }
}
