import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/cliente_repository.dart';
import '../data/repositories/movimiento_repository.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../models/producto.dart';

class StorageService {
  static final ClienteRepository _clienteRepository = ClienteRepository();
  static final MovimientoRepository _movimientoRepository =
      MovimientoRepository();

  static const String clientesKey = 'clientes';
  static const String historialKey = 'historial';
  static const String productosKey = 'productos';
  static const String auditoriaPendienteIdsKey = 'auditoria_pendiente_ids';
  static const String auditoriaPendienteFechaKey = 'auditoria_pendiente_fecha';
  static const String auditoriaDiariaCompletadaFechaKey =
      'auditoria_diaria_completada_fecha';
  static const String auditoriaSemanalCompletadaFechaKey =
      'auditoria_semanal_completada_fecha';
  static const String auditoriaProductosDelDiaIdsKey =
      'auditoria_productos_del_dia_ids';
  static const String auditoriaProductosDelDiaFechaKey =
      'auditoria_productos_del_dia_fecha';

  // Guardar clientes
  static Future<void> guardarClientes(
    List<Cliente> clientes, {
    int? negocioId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> lista = clientes.map((c) => jsonEncode(c.toJson())).toList();
    try {
      if (negocioId != null) {
        await _clienteRepository.guardarClientes(
          clientes,
          negocioId: negocioId,
        );
      }
    } catch (_) {
      // Si SQLite no esta disponible en una plataforma de prueba, el respaldo
      // legacy conserva el funcionamiento offline mientras se completa la
      // migracion total.
    }

    // SharedPreferences se mantiene temporalmente como respaldo durante la
    // migracion gradual. Cuando todas las pantallas usen repositorios SQLite,
    // este espejo puede retirarse con una migracion controlada.
    await prefs.setStringList(clientesKey, lista);
  }

  // Cargar clientes
  static Future<List<Cliente>> cargarClientes({int? negocioId}) async {
    try {
      if (negocioId != null) {
        final sqliteClientes = await _clienteRepository.obtenerClientes(
          negocioId: negocioId,
          limit: 10000,
        );
        if (sqliteClientes.isNotEmpty) {
          return sqliteClientes;
        }
      }
    } catch (_) {
      // Continua hacia SharedPreferences para mantener compatibilidad gradual.
    }

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(clientesKey) ?? [];
    final clientes = data.map((e) => Cliente.fromJson(jsonDecode(e))).toList();
    if (clientes.isNotEmpty) {
      try {
        if (negocioId != null) {
          await _clienteRepository.guardarClientes(
            clientes,
            negocioId: negocioId,
          );
        }
      } catch (_) {
        // La siembra SQLite se reintentara en la proxima carga.
      }
    }
    return clientes;
  }

  // Guardar historial
  static Future<void> guardarHistorial(
    List<Movimiento> historial, {
    int? negocioId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> lista = historial.map((m) => jsonEncode(m.toJson())).toList();
    try {
      if (negocioId != null) {
        await _movimientoRepository.guardarMovimientos(
          historial,
          negocioId: negocioId,
        );
      }
    } catch (_) {
      // El historial legacy sigue activo hasta retirar SharedPreferences.
    }

    // Espejo legacy para permitir rollback y convivencia durante la migracion.
    await prefs.setStringList(historialKey, lista);
  }

  // Cargar historial
  static Future<List<Movimiento>> cargarHistorial({int? negocioId}) async {
    try {
      if (negocioId != null) {
        final sqliteHistorial = await _movimientoRepository.obtenerMovimientos(
          negocioId: negocioId,
          limit: 10000,
        );
        if (sqliteHistorial.isNotEmpty) {
          return sqliteHistorial;
        }
      }
    } catch (_) {
      // Continua hacia SharedPreferences para mantener compatibilidad gradual.
    }

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(historialKey) ?? [];
    final historial = data
        .map((e) => Movimiento.fromJson(jsonDecode(e)))
        .toList();
    if (historial.isNotEmpty) {
      try {
        if (negocioId != null) {
          await _movimientoRepository.guardarMovimientos(
            historial,
            negocioId: negocioId,
          );
        }
      } catch (_) {
        // La siembra SQLite se reintentara en la proxima carga.
      }
    }
    return historial;
  }

  static Future<void> guardarProductos(List<Producto> productos) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = productos.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(productosKey, lista);
  }

  static Future<List<Producto>> cargarProductos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(productosKey) ?? [];
    return data.map((e) => Producto.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> guardarAuditoriaPendiente(
    List<String> productoIds,
    DateTime fecha,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(auditoriaPendienteIdsKey, productoIds);
    await prefs.setString(auditoriaPendienteFechaKey, fecha.toIso8601String());
  }

  static Future<List<String>> cargarAuditoriaPendienteIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(auditoriaPendienteIdsKey) ?? [];
  }

  static Future<DateTime?> cargarAuditoriaPendienteFecha() async {
    final prefs = await SharedPreferences.getInstance();
    final fecha = prefs.getString(auditoriaPendienteFechaKey);
    return fecha == null ? null : DateTime.parse(fecha);
  }

  static Future<void> limpiarAuditoriaPendiente() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(auditoriaPendienteIdsKey);
    await prefs.remove(auditoriaPendienteFechaKey);
  }

  static Future<void> guardarAuditoriaDiariaCompletada(DateTime fecha) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      auditoriaDiariaCompletadaFechaKey,
      fecha.toIso8601String(),
    );
  }

  static Future<DateTime?> cargarAuditoriaDiariaCompletadaFecha() async {
    final prefs = await SharedPreferences.getInstance();
    final fecha = prefs.getString(auditoriaDiariaCompletadaFechaKey);
    return fecha == null ? null : DateTime.parse(fecha);
  }

  static Future<void> guardarAuditoriaSemanalCompletada(DateTime fecha) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      auditoriaSemanalCompletadaFechaKey,
      fecha.toIso8601String(),
    );
  }

  static Future<DateTime?> cargarAuditoriaSemanalCompletadaFecha() async {
    final prefs = await SharedPreferences.getInstance();
    final fecha = prefs.getString(auditoriaSemanalCompletadaFechaKey);
    return fecha == null ? null : DateTime.parse(fecha);
  }

  static Future<void> guardarAuditoriaProductosDelDia(
    List<String> productoIds,
    DateTime fecha,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(auditoriaProductosDelDiaIdsKey, productoIds);
    await prefs.setString(
      auditoriaProductosDelDiaFechaKey,
      fecha.toIso8601String(),
    );
  }

  static Future<List<String>> cargarAuditoriaProductosDelDiaIds() async {
    final prefs = await SharedPreferences.getInstance();
    final fechaTexto = prefs.getString(auditoriaProductosDelDiaFechaKey);
    final fecha = fechaTexto == null ? null : DateTime.parse(fechaTexto);
    final hoy = DateTime.now();

    if (fecha == null ||
        fecha.year != hoy.year ||
        fecha.month != hoy.month ||
        fecha.day != hoy.day) {
      await prefs.remove(auditoriaProductosDelDiaIdsKey);
      await prefs.remove(auditoriaProductosDelDiaFechaKey);
      return const [];
    }

    return prefs.getStringList(auditoriaProductosDelDiaIdsKey) ?? const [];
  }
}
