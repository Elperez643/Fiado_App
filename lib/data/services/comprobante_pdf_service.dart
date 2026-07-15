import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/money_formatter.dart';
import '../models/comprobante_sqlite_model.dart';

class ComprobantePdfService {
  Future<Uint8List> generarPdf(ComprobanteSqliteModel comprobante) async {
    final payload = jsonDecode(comprobante.payloadJson) as Map<String, dynamic>;
    final productos = (payload['productos'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final registradoPor =
        (payload['registrado_por'] as Map<String, dynamic>?)?['nombre']
            as String?;
    final concepto = payload['concepto'] as String?;
    final subtotalMercancias =
        (payload['subtotal_mercancias'] as num?)?.toDouble() ??
        comprobante.subtotal;
    final ajusteManual =
        (payload['ajuste_manual'] as num?)?.toDouble() ??
        (comprobante.tipo == ComprobanteSqliteModel.tipoDeuda
            ? comprobante.total - subtotalMercancias
            : 0);
    final abonoInicial = (payload['abono_inicial'] as num?)?.toDouble() ?? 0;
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _header(comprobante),
          pw.SizedBox(height: 20),
          _datosGenerales(comprobante, registradoPor, concepto),
          pw.SizedBox(height: 18),
          if (comprobante.tipo == ComprobanteSqliteModel.tipoDeuda)
            _tablaProductos(productos),
          pw.SizedBox(height: 18),
          _resumenFinanciero(
            comprobante,
            productos: productos,
            subtotalMercancias: subtotalMercancias,
            ajusteManual: ajusteManual,
            abonoInicial: abonoInicial,
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Comprobante generado por Fiado App',
            style: pw.TextStyle(
              color: PdfColors.grey700,
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  String resumenTexto(ComprobanteSqliteModel comprobante) {
    final buffer = StringBuffer()
      ..writeln('Fiado App')
      ..writeln('Comprobante: ${comprobante.codigoComprobante}')
      ..writeln('Tipo: ${comprobante.tipo}')
      ..writeln('Cliente: ${comprobante.clienteNombre}')
      ..writeln('Fecha: ${_formatDate(comprobante.fecha)}')
      ..writeln('Total: ${MoneyFormatter.formatCurrency(comprobante.total)}');
    if (comprobante.saldoAnterior != null) {
      buffer.writeln(
        'Saldo anterior: ${MoneyFormatter.formatCurrency(comprobante.saldoAnterior!)}',
      );
    }
    if (comprobante.saldoNuevo != null) {
      buffer.writeln(
        'Saldo nuevo: ${MoneyFormatter.formatCurrency(comprobante.saldoNuevo!)}',
      );
    }
    return buffer.toString();
  }

  pw.Widget _header(ComprobanteSqliteModel comprobante) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#17322C'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Fiado App',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                comprobante.negocioNombre ?? 'Negocio',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                comprobante.tipo == ComprobanteSqliteModel.tipoPago
                    ? 'Comprobante de pago'
                    : 'Comprobante de deuda',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                comprobante.codigoComprobante,
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _datosGenerales(
    ComprobanteSqliteModel comprobante,
    String? registradoPor,
    String? concepto,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          _filaDato('Cliente', comprobante.clienteNombre),
          _filaDato('Telefono', comprobante.clienteTelefono ?? 'No registrado'),
          _filaDato('Fecha', _formatDate(comprobante.fecha)),
          _filaDato(
            'Concepto',
            concepto?.trim().isNotEmpty ?? false
                ? concepto!.trim()
                : comprobante.tipo == ComprobanteSqliteModel.tipoPago
                ? 'Pago de deuda'
                : 'Deuda registrada',
          ),
          _filaDato('Registrado por', registradoPor ?? 'No registrado'),
        ],
      ),
    );
  }

  pw.Widget _tablaProductos(List<Map<String, dynamic>> productos) {
    if (productos.isEmpty) {
      return pw.Text('Esta deuda no tiene detalle de mercancias registrado.');
    }

    return pw.TableHelper.fromTextArray(
      headers: ['Producto', 'Codigo', 'Cant.', 'Precio', 'Subtotal'],
      data: productos.map((item) {
        return [
          item['nombre_producto']?.toString() ?? '',
          item['codigo_referencia']?.toString() ?? '',
          item['cantidad']?.toString() ?? '',
          MoneyFormatter.formatCurrency(
            (item['precio_unitario'] as num?)?.toDouble() ?? 0,
          ),
          MoneyFormatter.formatCurrency(
            (item['subtotal'] as num?)?.toDouble() ?? 0,
          ),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      border: pw.TableBorder.all(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _resumenFinanciero(
    ComprobanteSqliteModel comprobante, {
    required List<Map<String, dynamic>> productos,
    required double subtotalMercancias,
    required double ajusteManual,
    required double abonoInicial,
  }) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 240,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            if (comprobante.saldoAnterior != null)
              _filaDato(
                'Deuda anterior',
                MoneyFormatter.formatCurrency(comprobante.saldoAnterior!),
              ),
            if (comprobante.tipo == ComprobanteSqliteModel.tipoDeuda &&
                productos.isNotEmpty) ...[
              _filaDato(
                'Subtotal mercancias',
                MoneyFormatter.formatCurrency(subtotalMercancias),
              ),
              if (abonoInicial > 0.01)
                _filaDato(
                  'Abono inicial',
                  MoneyFormatter.formatCurrency(abonoInicial),
                ),
              if (ajusteManual.abs() > 0.01)
                _filaDato(
                  ajusteManual > 0 ? 'Ajuste adicional' : 'Ajuste manual',
                  MoneyFormatter.formatCurrency(ajusteManual),
                ),
            ],
            _filaDato(
              comprobante.tipo == ComprobanteSqliteModel.tipoPago
                  ? 'Monto pagado'
                  : 'Monto final',
              MoneyFormatter.formatCurrency(comprobante.total),
            ),
            if (comprobante.saldoNuevo != null)
              _filaDato(
                'Saldo pendiente',
                MoneyFormatter.formatCurrency(comprobante.saldoNuevo!),
              ),
          ],
        ),
      ),
    );
  }

  pw.Widget _filaDato(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Text(value, textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
