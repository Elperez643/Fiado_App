import 'package:share_plus/share_plus.dart';

import '../../core/utils/money_formatter.dart';
import '../models/credito_ciclo_sqlite_model.dart';

class CreditoMensajeService {
  static String mensajeAviso30({
    required String nombreCliente,
    required String nombreNegocio,
    required double montoPendiente,
    String currency = 'US\$',
  }) {
    return 'Hola $nombreCliente, tienes un credito pendiente en $nombreNegocio. '
        'Ya se cumplieron 30 dias desde tu primer fiado de este ciclo. '
        'Monto pendiente: ${MoneyFormatter.formatCurrency(montoPendiente, symbol: currency)}. '
        'Por favor pasa por el negocio para saldar.';
  }

  static String mensajeAviso45({
    required String nombreCliente,
    required String nombreNegocio,
    required double montoPendiente,
    String currency = 'US\$',
  }) {
    return 'Hola $nombreCliente, tu credito pendiente en $nombreNegocio ya esta '
        'en mora. Monto pendiente: ${MoneyFormatter.formatCurrency(montoPendiente, symbol: currency)}. '
        'Por favor pasa por el negocio cuanto antes.';
  }

  static String mensajeBloqueo60({
    required String nombreCliente,
    required String nombreNegocio,
    required double montoPendiente,
    String currency = 'US\$',
  }) {
    return 'Hola $nombreCliente, tu credito en $nombreNegocio supero 60 dias y '
        'el fiado esta bloqueado para nuevas compras. Monto pendiente: '
        '${MoneyFormatter.formatCurrency(montoPendiente, symbol: currency)}.';
  }

  static String mensajeToqueManual({
    required String nombreCliente,
    required String nombreNegocio,
    required double montoPendiente,
    String currency = 'US\$',
  }) {
    return 'Hola $nombreCliente, te recordamos que tienes un credito pendiente '
        'en $nombreNegocio por ${MoneyFormatter.formatCurrency(montoPendiente, symbol: currency)}.';
  }

  static String mensajePorEstado({
    required CreditoCicloSqliteModel ciclo,
    required String nombreCliente,
    required String nombreNegocio,
  }) {
    switch (ciclo.estado) {
      case CreditoCicloEstado.bloqueado60:
        return mensajeBloqueo60(
          nombreCliente: nombreCliente,
          nombreNegocio: nombreNegocio,
          montoPendiente: ciclo.saldoPendiente,
        );
      case CreditoCicloEstado.mora45:
        return mensajeAviso45(
          nombreCliente: nombreCliente,
          nombreNegocio: nombreNegocio,
          montoPendiente: ciclo.saldoPendiente,
        );
      default:
        return mensajeAviso30(
          nombreCliente: nombreCliente,
          nombreNegocio: nombreNegocio,
          montoPendiente: ciclo.saldoPendiente,
        );
    }
  }

  static String normalizarTelefonoRD(String telefono) {
    final digits = telefono.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return digits;
    return digits;
  }

  static Uri whatsappUri({required String telefono, required String mensaje}) {
    return Uri.https('wa.me', '/${normalizarTelefonoRD(telefono)}', {
      'text': mensaje,
    });
  }

  static Future<void> abrirWhatsAppConMensaje({
    required String telefono,
    required String mensaje,
  }) async {
    final uri = whatsappUri(telefono: telefono, mensaje: mensaje);
    await SharePlus.instance.share(ShareParams(text: uri.toString()));
  }
}
