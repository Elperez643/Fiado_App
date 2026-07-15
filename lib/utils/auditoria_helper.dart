import '../models/producto.dart';

class AuditoriaHelper {
  const AuditoriaHelper._();

  static const Duration ventanaDiaria = Duration(days: 30);
  static const Duration ventanaClaveLunes = Duration(days: 15);

  static bool esLunes([DateTime? fecha]) {
    final referencia = fecha ?? DateTime.now();
    return referencia.weekday == DateTime.monday;
  }

  static bool hanPasadoMasDe24Horas(DateTime fecha, {DateTime? referencia}) {
    final ahora = referencia ?? DateTime.now();
    return ahora.difference(fecha) > const Duration(hours: 24);
  }

  static bool hanPasadoMasDe(
    DateTime fecha,
    Duration duracion, {
    DateTime? referencia,
  }) {
    final ahora = referencia ?? DateTime.now();
    return ahora.difference(fecha) > duracion;
  }

  static bool tieneAuditoriaCerrada(Producto producto) {
    return producto.disponibilidadConfirmada ||
        producto.disponibilidadCorregida;
  }

  static bool tieneDisponibilidadEnInventario(Producto producto) {
    return producto.cantidad > 0;
  }

  static bool fueAuditadoDentroDe(
    Producto producto,
    Duration duracion, {
    DateTime? referencia,
  }) {
    final ultimaVerificacion = producto.ultimaVerificacion;

    if (ultimaVerificacion == null || !tieneAuditoriaCerrada(producto)) {
      return false;
    }

    return !hanPasadoMasDe(
      ultimaVerificacion,
      duracion,
      referencia: referencia,
    );
  }

  static bool fueAuditadoEsteMesConCierre(
    Producto producto, {
    DateTime? referencia,
  }) {
    return fueAuditadoDentroDe(producto, ventanaDiaria, referencia: referencia);
  }

  static bool fueAuditadoEnUltimos15DiasConCierre(
    Producto producto, {
    DateTime? referencia,
  }) {
    return fueAuditadoDentroDe(
      producto,
      ventanaClaveLunes,
      referencia: referencia,
    );
  }

  static bool necesitaAuditoria(Producto producto, {DateTime? referencia}) {
    if (!tieneDisponibilidadEnInventario(producto)) {
      return false;
    }

    if (producto.ultimaVerificacion == null) {
      return true;
    }

    if (!tieneAuditoriaCerrada(producto)) {
      return true;
    }

    final ventana = producto.esClave && esLunes(referencia)
        ? ventanaClaveLunes
        : ventanaDiaria;

    return hanPasadoMasDe(
      producto.ultimaVerificacion!,
      ventana,
      referencia: referencia,
    );
  }
}
