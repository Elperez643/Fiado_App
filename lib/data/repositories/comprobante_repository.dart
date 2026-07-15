import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../models/comprobante_sqlite_model.dart';
import '../models/deuda_item_sqlite_model.dart';
import 'sync_queue_repository.dart';

class ComprobanteRepository {
  final DatabaseHelper databaseHelper;
  final SyncQueueRepository syncQueueRepository;

  ComprobanteRepository({
    DatabaseHelper? databaseHelper,
    SyncQueueRepository? syncQueueRepository,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       syncQueueRepository = syncQueueRepository ?? SyncQueueRepository();

  Future<ComprobanteSqliteModel> crearComprobanteDeuda({
    required int negocioId,
    required int movimientoId,
    required String clienteNombre,
    String? clienteTelefono,
    String? negocioNombre,
    required DateTime fecha,
    String? concepto,
    required List<DeudaItemSqliteModel> productos,
    required double total,
    required double saldoPendiente,
    double? subtotalMercancias,
    double? ajusteManual,
    double? abonoInicial,
    int? creadoPorUsuarioId,
    String? creadoPorNombre,
  }) async {
    final subtotalCalculado =
        subtotalMercancias ??
        productos.fold<double>(0, (sum, item) => sum + item.subtotal);
    final payload = {
      'tipo': ComprobanteSqliteModel.tipoDeuda,
      'concepto': concepto,
      'cliente': {'nombre': clienteNombre, 'telefono': clienteTelefono},
      'negocio': {'nombre': negocioNombre},
      'productos': productos
          .map((item) => item.toMap(includeId: true))
          .toList(),
      'subtotal_mercancias': subtotalCalculado,
      'monto_final': total,
      'ajuste_manual': ajusteManual ?? total - subtotalCalculado,
      'abono_inicial': abonoInicial ?? 0,
      'total': total,
      'saldo_pendiente': saldoPendiente,
      'registrado_por': {
        'usuario_id': creadoPorUsuarioId,
        'nombre': creadoPorNombre,
      },
    };
    debugPrint(
      '[deuda-items] crear comprobante movimiento_id=$movimientoId items=${productos.length} subtotal=$subtotalCalculado montoFinal=$total',
    );
    return _crearComprobante(
      tipo: ComprobanteSqliteModel.tipoDeuda,
      negocioId: negocioId,
      movimientoId: movimientoId,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      negocioNombre: negocioNombre,
      fecha: fecha,
      subtotal: subtotalCalculado,
      total: total,
      saldoAnterior: null,
      saldoNuevo: saldoPendiente,
      creadoPorUsuarioId: creadoPorUsuarioId,
      payload: payload,
    );
  }

  Future<ComprobanteSqliteModel> actualizarComprobanteDeuda(
    ComprobanteSqliteModel comprobante, {
    required List<DeudaItemSqliteModel> productos,
    required double total,
    required double saldoPendiente,
    String? concepto,
    double? subtotalMercancias,
    double? ajusteManual,
    double? abonoInicial,
  }) async {
    final subtotalCalculado =
        subtotalMercancias ??
        productos.fold<double>(0, (sum, item) => sum + item.subtotal);
    final payload = jsonDecode(comprobante.payloadJson) as Map<String, dynamic>;
    payload['tipo'] = ComprobanteSqliteModel.tipoDeuda;
    payload['concepto'] = concepto ?? payload['concepto'];
    payload['productos'] = productos
        .map((item) => item.toMap(includeId: true))
        .toList();
    payload['subtotal_mercancias'] = subtotalCalculado;
    payload['monto_final'] = total;
    payload['ajuste_manual'] = ajusteManual ?? total - subtotalCalculado;
    payload['abono_inicial'] = abonoInicial ?? 0;
    payload['total'] = total;
    payload['saldo_pendiente'] = saldoPendiente;

    final actualizado = comprobante.copyWith(
      subtotal: subtotalCalculado,
      total: total,
      saldoNuevo: saldoPendiente,
      payloadJson: jsonEncode(payload),
      updatedAt: DateTime.now(),
    );
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.comprobantesTable,
      actualizado.toMap(includeId: true),
      where: 'id = ?',
      whereArgs: [comprobante.id],
    );
    debugPrint(
      '[deuda-items] comprobante actualizado movimiento_id=${comprobante.movimientoId} items=${productos.length} subtotal=$subtotalCalculado montoFinal=$total',
    );
    if (actualizado.id != null) {
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.comprobantesTable,
        entityId: actualizado.id!,
        payload: actualizado.toMap(includeId: true),
      );
    }
    return actualizado;
  }

  Future<ComprobanteSqliteModel> crearComprobantePago({
    required int negocioId,
    required int movimientoId,
    required String clienteNombre,
    String? clienteTelefono,
    String? negocioNombre,
    required DateTime fecha,
    required double montoPagado,
    required double deudaAnterior,
    required double saldoNuevo,
    int? creadoPorUsuarioId,
    String? creadoPorNombre,
  }) async {
    final payload = {
      'tipo': ComprobanteSqliteModel.tipoPago,
      'cliente': {'nombre': clienteNombre, 'telefono': clienteTelefono},
      'negocio': {'nombre': negocioNombre},
      'monto_pagado': montoPagado,
      'deuda_anterior': deudaAnterior,
      'saldo_nuevo': saldoNuevo,
      'registrado_por': {
        'usuario_id': creadoPorUsuarioId,
        'nombre': creadoPorNombre,
      },
    };
    return _crearComprobante(
      tipo: ComprobanteSqliteModel.tipoPago,
      negocioId: negocioId,
      movimientoId: movimientoId,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      negocioNombre: negocioNombre,
      fecha: fecha,
      subtotal: montoPagado,
      total: montoPagado,
      saldoAnterior: deudaAnterior,
      saldoNuevo: saldoNuevo,
      creadoPorUsuarioId: creadoPorUsuarioId,
      payload: payload,
    );
  }

  Future<ComprobanteSqliteModel?> obtenerComprobantePorMovimiento(
    int movimientoId, {
    int? negocioId,
  }) async {
    final db = await databaseHelper.database;
    final where = negocioId == null
        ? 'movimiento_id = ?'
        : 'negocio_id = ? AND movimiento_id = ?';
    final args = negocioId == null
        ? <Object?>[movimientoId]
        : <Object?>[negocioId, movimientoId];
    final rows = await db.query(
      DatabaseSchema.comprobantesTable,
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ComprobanteSqliteModel.fromMap(rows.first);
  }

  Future<List<ComprobanteSqliteModel>> obtenerComprobantesPorCliente({
    required int negocioId,
    required String clienteNombre,
    String? clienteTelefono,
  }) async {
    final db = await databaseHelper.database;
    final where = clienteTelefono == null || clienteTelefono.trim().isEmpty
        ? 'negocio_id = ? AND cliente_nombre = ?'
        : 'negocio_id = ? AND cliente_nombre = ? AND cliente_telefono = ?';
    final args = clienteTelefono == null || clienteTelefono.trim().isEmpty
        ? <Object?>[negocioId, clienteNombre]
        : <Object?>[negocioId, clienteNombre, clienteTelefono];
    final rows = await db.query(
      DatabaseSchema.comprobantesTable,
      where: where,
      whereArgs: args,
      orderBy: 'fecha DESC',
    );
    return rows.map(ComprobanteSqliteModel.fromMap).toList();
  }

  Future<ComprobanteSqliteModel?> obtenerComprobantePorCodigo(
    String codigo,
  ) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.comprobantesTable,
      where: 'codigo_comprobante = ?',
      whereArgs: [codigo],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ComprobanteSqliteModel.fromMap(rows.first);
  }

  Future<String> generarCodigoComprobante(String tipo) async {
    final db = await databaseHelper.database;
    final prefix = tipo == ComprobanteSqliteModel.tipoPago ? 'PAG' : 'DEU';
    final date = DateTime.now();
    final stamp =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    for (var i = 0; i < 5; i++) {
      final millis = DateTime.now().millisecondsSinceEpoch % 1000000;
      final code = '$prefix-$stamp-$millis${i == 0 ? '' : i}';
      final exists = await db.query(
        DatabaseSchema.comprobantesTable,
        columns: ['id'],
        where: 'codigo_comprobante = ?',
        whereArgs: [code],
        limit: 1,
      );
      if (exists.isEmpty) return code;
    }
    return '$prefix-$stamp-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> encolarSyncComprobante(ComprobanteSqliteModel comprobante) {
    if (comprobante.id == null) return Future.value();
    return syncQueueRepository.enqueueCreate(
      entityType: DatabaseSchema.comprobantesTable,
      entityId: comprobante.id!,
      payload: comprobante.toMap(includeId: true),
    );
  }

  Future<ComprobanteSqliteModel> _crearComprobante({
    required String tipo,
    required int negocioId,
    required int movimientoId,
    required String clienteNombre,
    String? clienteTelefono,
    String? negocioNombre,
    required DateTime fecha,
    required double subtotal,
    required double total,
    double? saldoAnterior,
    double? saldoNuevo,
    int? creadoPorUsuarioId,
    required Map<String, Object?> payload,
  }) async {
    final existente = await obtenerComprobantePorMovimiento(
      movimientoId,
      negocioId: negocioId,
    );
    if (existente != null) return existente;

    final db = await databaseHelper.database;
    final now = DateTime.now();
    final comprobante = ComprobanteSqliteModel(
      negocioId: negocioId,
      tipo: tipo,
      movimientoId: movimientoId,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      negocioNombre: negocioNombre,
      codigoComprobante: await generarCodigoComprobante(tipo),
      fecha: fecha,
      subtotal: subtotal,
      total: total,
      saldoAnterior: saldoAnterior,
      saldoNuevo: saldoNuevo,
      creadoPorUsuarioId: creadoPorUsuarioId,
      payloadJson: jsonEncode(payload),
      createdAt: now,
      updatedAt: now,
    );
    final id = await db.insert(
      DatabaseSchema.comprobantesTable,
      comprobante.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    final saved = comprobante.copyWith(id: id);
    await encolarSyncComprobante(saved);
    return saved;
  }
}
