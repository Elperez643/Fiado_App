import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/money_formatter.dart';
import '../data/models/comprobante_sqlite_model.dart';
import '../data/models/deuda_item_sqlite_model.dart';
import '../data/services/comprobante_pdf_service.dart';
import '../presentation/providers/fiado_data_providers.dart';

class ComprobanteScreen extends ConsumerWidget {
  final ComprobanteSqliteModel comprobante;

  const ComprobanteScreen({super.key, required this.comprobante});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = jsonDecode(comprobante.payloadJson) as Map<String, dynamic>;
    final productos = (payload['productos'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    if (comprobante.tipo == ComprobanteSqliteModel.tipoDeuda &&
        productos.isEmpty) {
      return FutureBuilder<List<DeudaItemSqliteModel>>(
        future: ref
            .read(deudaItemRepositoryProvider)
            .obtenerItemsPorMovimiento(
              comprobante.movimientoId,
              negocioId: comprobante.negocioId,
            ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final items = snapshot.data ?? const <DeudaItemSqliteModel>[];
          final resolved = items.isEmpty
              ? comprobante
              : _comprobanteConProductos(comprobante, items);
          return _ComprobanteContent(comprobante: resolved);
        },
      );
    }

    return _ComprobanteContent(comprobante: comprobante);
  }

  ComprobanteSqliteModel _comprobanteConProductos(
    ComprobanteSqliteModel comprobante,
    List<DeudaItemSqliteModel> items,
  ) {
    final payload = jsonDecode(comprobante.payloadJson) as Map<String, dynamic>;
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    payload['productos'] = items
        .map((item) => item.toMap(includeId: true))
        .toList();
    payload['subtotal_mercancias'] = subtotal;
    payload['monto_final'] = comprobante.total;
    payload['ajuste_manual'] = comprobante.total - subtotal;
    payload['abono_inicial'] = subtotal > comprobante.total
        ? subtotal - comprobante.total
        : 0;
    return comprobante.copyWith(
      subtotal: subtotal,
      payloadJson: jsonEncode(payload),
    );
  }
}

class _ComprobanteContent extends StatelessWidget {
  final ComprobanteSqliteModel comprobante;

  const _ComprobanteContent({required this.comprobante});

  @override
  Widget build(BuildContext context) {
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
    final abonoInicial = (payload['abono_inicial'] as num?)?.toDouble() ?? 0;
    final ajusteManual =
        (payload['ajuste_manual'] as num?)?.toDouble() ??
        (comprobante.tipo == ComprobanteSqliteModel.tipoDeuda
            ? comprobante.total - subtotalMercancias
            : 0);
    final pdfService = ComprobantePdfService();

    Future<void> compartir() async {
      try {
        final bytes = await pdfService.generarPdf(comprobante);
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                name: '${comprobante.codigoComprobante}.pdf',
                mimeType: 'application/pdf',
              ),
            ],
            fileNameOverrides: ['${comprobante.codigoComprobante}.pdf'],
            text: pdfService.resumenTexto(comprobante),
            subject: 'Comprobante ${comprobante.codigoComprobante}',
            title: 'Comprobante ${comprobante.codigoComprobante}',
          ),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo compartir: $error')));
      }
    }

    Future<void> exportarPdf() async {
      try {
        final bytes = await pdfService.generarPdf(comprobante);
        await Printing.sharePdf(
          bytes: bytes,
          filename: '${comprobante.codigoComprobante}.pdf',
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo exportar PDF: $error')),
        );
      }
    }

    Future<void> imprimir() async {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La impresion depende del navegador y las impresoras disponibles.',
            ),
          ),
        );
      }
      try {
        await Printing.layoutPdf(
          name: comprobante.codigoComprobante,
          onLayout: (_) => pdfService.generarPdf(comprobante),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo imprimir: $error')));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Comprobante')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 16 : 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF17322C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fiado App',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            comprobante.negocioNombre ?? 'Negocio',
                            style: const TextStyle(color: Color(0xFFE7F3EF)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            comprobante.codigoComprobante,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: comprobante.tipo == ComprobanteSqliteModel.tipoPago
                          ? 'Pago'
                          : 'Deuda',
                      children: [
                        _InfoRow('Cliente', comprobante.clienteNombre),
                        _InfoRow(
                          'Telefono',
                          comprobante.clienteTelefono ?? 'No registrado',
                        ),
                        _InfoRow('Fecha', _formatDate(comprobante.fecha)),
                        _InfoRow(
                          'Concepto',
                          concepto?.trim().isNotEmpty ?? false
                              ? concepto!.trim()
                              : comprobante.tipo ==
                                    ComprobanteSqliteModel.tipoPago
                              ? 'Pago de deuda'
                              : 'Deuda registrada',
                        ),
                        _InfoRow(
                          'Registrado por',
                          registradoPor ?? 'No registrado',
                        ),
                      ],
                    ),
                    if (comprobante.tipo == ComprobanteSqliteModel.tipoDeuda)
                      _Section(
                        title: 'Mercancias',
                        children: productos.isEmpty
                            ? const [
                                Text(
                                  'Esta deuda no tiene detalle de mercancias registrado.',
                                ),
                              ]
                            : productos
                                  .map(_ProductoComprobanteRow.new)
                                  .toList(),
                      ),
                    _Section(
                      title: 'Resumen',
                      children: [
                        if (comprobante.saldoAnterior != null)
                          _InfoRow(
                            'Deuda anterior',
                            MoneyFormatter.formatCurrency(
                              comprobante.saldoAnterior!,
                            ),
                          ),
                        if (comprobante.tipo ==
                                ComprobanteSqliteModel.tipoDeuda &&
                            productos.isNotEmpty) ...[
                          _InfoRow(
                            'Subtotal mercancias',
                            MoneyFormatter.formatCurrency(subtotalMercancias),
                          ),
                          if (abonoInicial > 0.01)
                            _InfoRow(
                              'Abono inicial',
                              MoneyFormatter.formatCurrency(abonoInicial),
                            ),
                          if (ajusteManual.abs() > 0.01)
                            _InfoRow(
                              ajusteManual > 0
                                  ? 'Ajuste adicional'
                                  : 'Ajuste manual',
                              MoneyFormatter.formatCurrency(ajusteManual),
                            ),
                        ],
                        _InfoRow(
                          comprobante.tipo == ComprobanteSqliteModel.tipoPago
                              ? 'Monto pagado'
                              : 'Monto final',
                          MoneyFormatter.formatCurrency(comprobante.total),
                        ),
                        if (comprobante.saldoNuevo != null)
                          _InfoRow(
                            'Saldo pendiente',
                            MoneyFormatter.formatCurrency(
                              comprobante.saldoNuevo!,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: compartir,
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Compartir'),
                        ),
                        OutlinedButton.icon(
                          onPressed: exportarPdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Exportar PDF'),
                        ),
                        OutlinedButton.icon(
                          onPressed: imprimir,
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Imprimir'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4DED2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF17322C),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF66756D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductoComprobanteRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ProductoComprobanteRow(this.item);

  @override
  Widget build(BuildContext context) {
    final cantidad = (item['cantidad'] as num?)?.toInt() ?? 0;
    final precio = (item['precio_unitario'] as num?)?.toDouble() ?? 0;
    final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0;
    final codigo = item['codigo_referencia'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            codigo == null || codigo.isEmpty
                ? item['nombre_producto']?.toString() ?? ''
                : '${item['nombre_producto']} ($codigo)',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Text('Cantidad: $cantidad'),
              Text('Precio: ${MoneyFormatter.formatCurrency(precio)}'),
              Text('Subtotal: ${MoneyFormatter.formatCurrency(subtotal)}'),
            ],
          ),
        ],
      ),
    );
  }
}
