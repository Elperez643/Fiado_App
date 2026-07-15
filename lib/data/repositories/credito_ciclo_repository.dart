import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../models/credito_ciclo_sqlite_model.dart';
import '../models/credito_excepcion_sqlite_model.dart';
import '../models/credito_recordatorio_sqlite_model.dart';
import '../models/usuario_sqlite_model.dart';
import '../services/credito_mensaje_service.dart';
import 'sync_queue_repository.dart';

class CreditoBloqueadoException implements Exception {
  final CreditoCicloSqliteModel ciclo;

  const CreditoBloqueadoException(this.ciclo);

  @override
  String toString() {
    return 'Este cliente tiene un ciclo de credito vencido por mas de 60 dias en este negocio. El fiado esta bloqueado.';
  }
}

class CreditoCicloRepository {
  final DatabaseHelper databaseHelper;
  final SyncQueueRepository syncQueueRepository;

  CreditoCicloRepository({
    DatabaseHelper? databaseHelper,
    SyncQueueRepository? syncQueueRepository,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       syncQueueRepository = syncQueueRepository ?? SyncQueueRepository();

  Future<CreditoCicloSqliteModel> obtenerOCrearCicloActivo(
    int clienteId,
    int negocioId,
    DateTime fechaDeuda, {
    Transaction? transaction,
  }) async {
    final executor = transaction ?? await databaseHelper.database;
    await _actualizarEstadosPorFechaEnExecutor(executor, negocioId, fechaDeuda);
    final rows = await executor.query(
      DatabaseSchema.creditoCiclosTable,
      where:
          'negocio_id = ? AND cliente_id = ? AND estado != ? AND saldo_pendiente > 0 AND ? >= fecha_inicio AND ? <= fecha_limite_30',
      whereArgs: [
        negocioId,
        clienteId,
        CreditoCicloEstado.saldado,
        fechaDeuda.toIso8601String(),
        fechaDeuda.toIso8601String(),
      ],
      orderBy: 'fecha_inicio DESC',
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return CreditoCicloSqliteModel.fromMap(rows.first);
    }

    final ciclo = CreditoCicloSqliteModel.nuevo(
      negocioId: negocioId,
      clienteId: clienteId,
      fechaInicio: fechaDeuda,
    );
    final id = await executor.insert(
      DatabaseSchema.creditoCiclosTable,
      ciclo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    final saved = CreditoCicloSqliteModel.fromMap({
      ...ciclo.toMap(includeId: true),
      'id': id,
    });

    if (transaction == null) {
      await syncQueueRepository.enqueueCreate(
        entityType: DatabaseSchema.creditoCiclosTable,
        entityId: id,
        payload: saved.toMap(includeId: true),
      );
    }

    return saved;
  }

  Future<CreditoCicloSqliteModel> asignarDeudaACiclo({
    required int movimientoId,
    required int clienteId,
    required int negocioId,
    required double monto,
    required DateTime fecha,
    Transaction? transaction,
  }) async {
    final executor = transaction ?? await databaseHelper.database;
    final ciclo = await obtenerOCrearCicloActivo(
      clienteId,
      negocioId,
      fecha,
      transaction: transaction,
    );
    final now = DateTime.now();
    final nuevoTotal = ciclo.montoTotal + monto;
    final nuevoSaldo = ciclo.saldoPendiente + monto;
    final updated = _estadoParaFecha(
      ciclo: ciclo,
      fecha: fecha,
      saldoPendiente: nuevoSaldo,
      montoTotal: nuevoTotal,
      montoPagado: ciclo.montoPagado,
    );

    await executor.update(
      DatabaseSchema.creditoCiclosTable,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [ciclo.id],
    );
    final movimientoCiclo = {
      'ciclo_id': ciclo.id,
      'movimiento_id': movimientoId,
      'tipo': 'deuda',
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    await executor.insert(
      DatabaseSchema.creditoCicloMovimientosTable,
      movimientoCiclo,
    );

    if (transaction == null) {
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.creditoCiclosTable,
        entityId: updated.id!,
        payload: updated.toMap(includeId: true),
      );
    }

    return updated;
  }

  Future<void> registrarPagoEnCiclos({
    required int clienteId,
    required int negocioId,
    required int movimientoId,
    required double montoPago,
    required DateTime fecha,
    Transaction? transaction,
  }) async {
    final executor = transaction ?? await databaseHelper.database;
    await _actualizarEstadosPorFechaEnExecutor(executor, negocioId, fecha);
    var restante = montoPago;
    final rows = await executor.query(
      DatabaseSchema.creditoCiclosTable,
      where:
          'negocio_id = ? AND cliente_id = ? AND estado != ? AND saldo_pendiente > 0',
      whereArgs: [negocioId, clienteId, CreditoCicloEstado.saldado],
      orderBy: 'fecha_inicio ASC',
    );

    for (final row in rows) {
      if (restante <= 0) break;
      final ciclo = CreditoCicloSqliteModel.fromMap(row);
      final aplicado = restante > ciclo.saldoPendiente
          ? ciclo.saldoPendiente
          : restante;
      restante -= aplicado;
      final nuevoPagado = ciclo.montoPagado + aplicado;
      final nuevoSaldo = ciclo.saldoPendiente - aplicado;
      final updated = _estadoParaFecha(
        ciclo: ciclo,
        fecha: fecha,
        saldoPendiente: nuevoSaldo,
        montoTotal: ciclo.montoTotal,
        montoPagado: nuevoPagado,
      );

      await executor.update(
        DatabaseSchema.creditoCiclosTable,
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [ciclo.id],
      );
      await executor.insert(DatabaseSchema.creditoCicloMovimientosTable, {
        'ciclo_id': ciclo.id,
        'movimiento_id': movimientoId,
        'tipo': 'pago',
        'monto': aplicado,
        'fecha': fecha.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (transaction == null) {
        await syncQueueRepository.enqueueUpdate(
          entityType: DatabaseSchema.creditoCiclosTable,
          entityId: updated.id!,
          payload: updated.toMap(includeId: true),
        );
      }
    }
  }

  Future<void> actualizarEstadosPorFecha(
    int negocioId, {
    DateTime? fecha,
  }) async {
    final db = await databaseHelper.database;
    await _actualizarEstadosPorFechaEnExecutor(
      db,
      negocioId,
      fecha ?? DateTime.now(),
    );
  }

  Future<List<CreditoCicloSqliteModel>> obtenerCiclosPorCliente(
    int clienteId,
    int negocioId,
  ) async {
    await actualizarEstadosPorFecha(negocioId);
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.creditoCiclosTable,
      where: 'negocio_id = ? AND cliente_id = ?',
      whereArgs: [negocioId, clienteId],
      orderBy: 'fecha_inicio DESC',
    );
    return rows.map(CreditoCicloSqliteModel.fromMap).toList();
  }

  Future<CreditoCicloSqliteModel?> obtenerCicloActual(
    int clienteId,
    int negocioId,
  ) async {
    await actualizarEstadosPorFecha(negocioId);
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.creditoCiclosTable,
      where:
          'negocio_id = ? AND cliente_id = ? AND estado != ? AND saldo_pendiente > 0',
      whereArgs: [negocioId, clienteId, CreditoCicloEstado.saldado],
      orderBy: 'fecha_inicio ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CreditoCicloSqliteModel.fromMap(rows.first);
  }

  Future<CreditoCicloSqliteModel?> obtenerUltimoCiclo(
    int clienteId,
    int negocioId,
  ) async {
    await actualizarEstadosPorFecha(negocioId);
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.creditoCiclosTable,
      where: 'negocio_id = ? AND cliente_id = ?',
      whereArgs: [negocioId, clienteId],
      orderBy: 'fecha_inicio DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CreditoCicloSqliteModel.fromMap(rows.first);
  }

  Future<List<CreditoCicloSqliteModel>> obtenerCiclosVencidos30(int negocioId) {
    return _obtenerCiclosPorEstado(negocioId, CreditoCicloEstado.vencido30);
  }

  Future<List<CreditoCicloSqliteModel>> obtenerCiclosMora45(int negocioId) {
    return _obtenerCiclosPorEstado(negocioId, CreditoCicloEstado.mora45);
  }

  Future<List<CreditoCicloSqliteModel>> obtenerCiclosBloqueados60(
    int negocioId,
  ) {
    return _obtenerCiclosPorEstado(negocioId, CreditoCicloEstado.bloqueado60);
  }

  Future<bool> clienteTieneBloqueoFiado(int clienteId, int negocioId) async {
    await actualizarEstadosPorFecha(negocioId);
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.creditoCiclosTable,
      columns: ['id'],
      where:
          'negocio_id = ? AND cliente_id = ? AND estado = ? AND saldo_pendiente > 0',
      whereArgs: [negocioId, clienteId, CreditoCicloEstado.bloqueado60],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<CreditoExcepcionSqliteModel> registrarExcepcionFiarDeTodosModos({
    required int cicloId,
    required int negocioId,
    required int clienteId,
    required int usuarioId,
    required double montoFiado,
    int? movimientoId,
    String? motivo,
    DateTime? fecha,
    Transaction? transaction,
  }) async {
    final executor = transaction ?? await databaseHelper.database;
    final now = DateTime.now();
    final model = CreditoExcepcionSqliteModel(
      cicloId: cicloId,
      negocioId: negocioId,
      clienteId: clienteId,
      usuarioId: usuarioId,
      motivo: motivo,
      montoFiado: montoFiado,
      movimientoId: movimientoId,
      fecha: fecha ?? now,
      createdAt: now,
      updatedAt: now,
    );
    final id = await executor.insert(
      DatabaseSchema.creditoExcepcionesTable,
      model.toMap(),
    );
    final saved = CreditoExcepcionSqliteModel.fromMap({
      ...model.toMap(includeId: true),
      'id': id,
    });
    if (transaction == null) {
      await syncQueueRepository.enqueueCreate(
        entityType: DatabaseSchema.creditoExcepcionesTable,
        entityId: id,
        payload: saved.toMap(includeId: true),
      );
    }
    return saved;
  }

  Future<void> saldarCicloSiCorresponde(int cicloId) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.creditoCiclosTable,
      where: 'id = ?',
      whereArgs: [cicloId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final ciclo = CreditoCicloSqliteModel.fromMap(rows.first);
    if (ciclo.saldoPendiente > 0) return;
    final now = DateTime.now();
    await db.update(
      DatabaseSchema.creditoCiclosTable,
      {
        'estado': CreditoCicloEstado.saldado,
        'bloqueado': 0,
        'saldo_pendiente': 0,
        'fecha_saldado': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'sync_status': SyncStatus.updated,
      },
      where: 'id = ?',
      whereArgs: [cicloId],
    );
  }

  Future<int?> resolverClienteId({
    required int negocioId,
    String? telefono,
    String? nombre,
  }) async {
    final db = await databaseHelper.database;
    final where = telefono != null && telefono.trim().isNotEmpty
        ? 'negocio_id = ? AND telefono = ?'
        : 'negocio_id = ? AND nombre = ?';
    final args = telefono != null && telefono.trim().isNotEmpty
        ? [negocioId, telefono.trim()]
        : [negocioId, nombre?.trim()];
    final rows = await db.query(
      DatabaseSchema.clientesTable,
      columns: ['id'],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<List<CreditoRecordatorioSqliteModel>> obtenerRecordatoriosPorTelefono(
    String telefono,
  ) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      '''
SELECT r.*, c.nombre AS cliente_nombre, c.telefono AS cliente_telefono,
       u.nombre AS negocio_nombre, cc.saldo_pendiente, cc.fecha_limite_30
FROM ${DatabaseSchema.creditoRecordatoriosTable} r
INNER JOIN ${DatabaseSchema.clientesTable} c ON c.id = r.cliente_id
INNER JOIN ${DatabaseSchema.usuariosTable} u ON u.id = r.negocio_id
INNER JOIN ${DatabaseSchema.creditoCiclosTable} cc ON cc.id = r.ciclo_id
WHERE c.telefono = ? AND r.canal = ? AND r.estado = ?
ORDER BY r.fecha_generado DESC
''',
      [telefono, CreditoRecordatorioCanal.interno, 'pendiente'],
    );
    return rows.map(CreditoRecordatorioSqliteModel.fromMap).toList();
  }

  Future<void> generarToqueManual({
    required CreditoCicloSqliteModel ciclo,
    required String nombreCliente,
    required String nombreNegocio,
    String canal = CreditoRecordatorioCanal.whatsapp,
  }) async {
    final mensaje = CreditoMensajeService.mensajeToqueManual(
      nombreCliente: nombreCliente,
      nombreNegocio: nombreNegocio,
      montoPendiente: ciclo.saldoPendiente,
    );
    await _crearRecordatorio(
      ciclo: ciclo,
      tipo: CreditoRecordatorioTipo.toqueManual,
      canal: canal,
      mensaje: mensaje,
    );
  }

  Future<List<CreditoCicloSqliteModel>> _obtenerCiclosPorEstado(
    int negocioId,
    String estado,
  ) async {
    await actualizarEstadosPorFecha(negocioId);
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      '''
SELECT cc.*, c.nombre AS cliente_nombre, c.telefono AS cliente_telefono,
       u.nombre AS negocio_nombre
FROM ${DatabaseSchema.creditoCiclosTable} cc
INNER JOIN ${DatabaseSchema.clientesTable} c ON c.id = cc.cliente_id
INNER JOIN ${DatabaseSchema.usuariosTable} u ON u.id = cc.negocio_id
WHERE cc.negocio_id = ? AND cc.estado = ? AND cc.saldo_pendiente > 0
ORDER BY cc.fecha_inicio ASC
''',
      [negocioId, estado],
    );
    return rows.map(CreditoCicloSqliteModel.fromMap).toList();
  }

  Future<void> _actualizarEstadosPorFechaEnExecutor(
    DatabaseExecutor executor,
    int negocioId,
    DateTime fecha,
  ) async {
    final rows = await executor.query(
      DatabaseSchema.creditoCiclosTable,
      where: 'negocio_id = ? AND estado != ? AND saldo_pendiente > 0',
      whereArgs: [negocioId, CreditoCicloEstado.saldado],
    );
    for (final row in rows) {
      final ciclo = CreditoCicloSqliteModel.fromMap(row);
      final updated = _estadoParaFecha(
        ciclo: ciclo,
        fecha: fecha,
        saldoPendiente: ciclo.saldoPendiente,
        montoTotal: ciclo.montoTotal,
        montoPagado: ciclo.montoPagado,
      );
      if (updated.estado == ciclo.estado &&
          updated.bloqueado == ciclo.bloqueado) {
        continue;
      }
      await executor.update(
        DatabaseSchema.creditoCiclosTable,
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [ciclo.id],
      );
      await _crearRecordatoriosAutomaticos(executor, updated);
    }
  }

  CreditoCicloSqliteModel _estadoParaFecha({
    required CreditoCicloSqliteModel ciclo,
    required DateTime fecha,
    required double saldoPendiente,
    required double montoTotal,
    required double montoPagado,
  }) {
    final now = DateTime.now();
    if (saldoPendiente <= 0.009) {
      return CreditoCicloSqliteModel(
        id: ciclo.id,
        remoteId: ciclo.remoteId,
        negocioId: ciclo.negocioId,
        clienteId: ciclo.clienteId,
        fechaInicio: ciclo.fechaInicio,
        fechaLimite30: ciclo.fechaLimite30,
        fechaLimite45: ciclo.fechaLimite45,
        fechaBloqueo60: ciclo.fechaBloqueo60,
        estado: CreditoCicloEstado.saldado,
        montoTotal: montoTotal,
        montoPagado: montoPagado,
        saldoPendiente: 0,
        bloqueado: false,
        fechaSaldado: fecha,
        createdAt: ciclo.createdAt,
        updatedAt: now,
        syncStatus: SyncStatus.updated,
      );
    }

    var estado = CreditoCicloEstado.activo;
    var bloqueado = false;
    if (!fecha.isBefore(ciclo.fechaBloqueo60)) {
      estado = CreditoCicloEstado.bloqueado60;
      bloqueado = true;
    } else if (!fecha.isBefore(ciclo.fechaLimite45)) {
      estado = CreditoCicloEstado.mora45;
    } else if (!fecha.isBefore(ciclo.fechaLimite30)) {
      estado = CreditoCicloEstado.vencido30;
    }

    return CreditoCicloSqliteModel(
      id: ciclo.id,
      remoteId: ciclo.remoteId,
      negocioId: ciclo.negocioId,
      clienteId: ciclo.clienteId,
      fechaInicio: ciclo.fechaInicio,
      fechaLimite30: ciclo.fechaLimite30,
      fechaLimite45: ciclo.fechaLimite45,
      fechaBloqueo60: ciclo.fechaBloqueo60,
      estado: estado,
      montoTotal: montoTotal,
      montoPagado: montoPagado,
      saldoPendiente: saldoPendiente,
      bloqueado: bloqueado,
      fechaSaldado: null,
      createdAt: ciclo.createdAt,
      updatedAt: now,
      syncStatus: SyncStatus.updated,
    );
  }

  Future<void> _crearRecordatoriosAutomaticos(
    DatabaseExecutor executor,
    CreditoCicloSqliteModel ciclo,
  ) async {
    final tipo = switch (ciclo.estado) {
      CreditoCicloEstado.bloqueado60 => CreditoRecordatorioTipo.bloqueo60,
      CreditoCicloEstado.mora45 => CreditoRecordatorioTipo.aviso45,
      CreditoCicloEstado.vencido30 => CreditoRecordatorioTipo.aviso30,
      _ => null,
    };
    if (tipo == null) return;

    final existing = await executor.query(
      DatabaseSchema.creditoRecordatoriosTable,
      columns: ['id'],
      where: 'ciclo_id = ? AND tipo = ? AND canal = ?',
      whereArgs: [ciclo.id, tipo, CreditoRecordatorioCanal.interno],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final rows = await executor.rawQuery(
      '''
SELECT c.nombre AS cliente_nombre, c.telefono AS cliente_telefono,
       u.nombre AS negocio_nombre
FROM ${DatabaseSchema.clientesTable} c
INNER JOIN ${DatabaseSchema.usuariosTable} u ON u.id = ?
WHERE c.id = ?
''',
      [ciclo.negocioId, ciclo.clienteId],
    );
    if (rows.isEmpty) return;
    final row = rows.first;
    final telefono = row['cliente_telefono'] as String;
    final personal = await executor.query(
      DatabaseSchema.usuariosTable,
      columns: ['id'],
      where: 'telefono = ? AND tipo_usuario = ? AND activo = 1',
      whereArgs: [telefono, UsuarioSqliteModel.tipoPersonal],
      limit: 1,
    );
    if (personal.isEmpty) return;

    final mensaje = CreditoMensajeService.mensajePorEstado(
      ciclo: ciclo,
      nombreCliente: row['cliente_nombre'] as String,
      nombreNegocio: row['negocio_nombre'] as String,
    );
    await _insertRecordatorio(
      executor,
      ciclo: ciclo,
      tipo: tipo,
      canal: CreditoRecordatorioCanal.interno,
      mensaje: mensaje,
    );
  }

  Future<void> _crearRecordatorio({
    required CreditoCicloSqliteModel ciclo,
    required String tipo,
    required String canal,
    required String mensaje,
  }) async {
    final db = await databaseHelper.database;
    final id = await _insertRecordatorio(
      db,
      ciclo: ciclo,
      tipo: tipo,
      canal: canal,
      mensaje: mensaje,
    );
    final rows = await db.query(
      DatabaseSchema.creditoRecordatoriosTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await syncQueueRepository.enqueueCreate(
        entityType: DatabaseSchema.creditoRecordatoriosTable,
        entityId: id,
        payload: rows.first,
      );
    }
  }

  Future<int> _insertRecordatorio(
    DatabaseExecutor executor, {
    required CreditoCicloSqliteModel ciclo,
    required String tipo,
    required String canal,
    required String mensaje,
  }) {
    final now = DateTime.now();
    return executor.insert(DatabaseSchema.creditoRecordatoriosTable, {
      'ciclo_id': ciclo.id,
      'negocio_id': ciclo.negocioId,
      'cliente_id': ciclo.clienteId,
      'tipo': tipo,
      'mensaje': mensaje,
      'canal': canal,
      'estado': 'pendiente',
      'fecha_generado': now.toIso8601String(),
      'fecha_enviado': null,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'sync_status': SyncStatus.pending,
    });
  }
}
