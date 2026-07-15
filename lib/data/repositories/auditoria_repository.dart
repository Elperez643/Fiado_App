import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../../models/producto.dart';
import '../models/auditoria_item_sqlite_model.dart';
import '../models/auditoria_sqlite_model.dart';
import 'producto_repository.dart';
import 'sync_queue_repository.dart';

class AuditoriaDetalleItem {
  final AuditoriaItemSqliteModel item;
  final String productoNombre;
  final String ubicacion;
  final String legacyId;
  final bool esClave;

  const AuditoriaDetalleItem({
    required this.item,
    required this.productoNombre,
    required this.ubicacion,
    required this.legacyId,
    required this.esClave,
  });

  int? get diferencia =>
      item.stockFisico == null ? null : item.stockFisico! - item.stockSistema;
}

class AuditoriaResumen {
  final AuditoriaSqliteModel auditoria;
  final String ejecutadaPor;
  final int diferencias;

  const AuditoriaResumen({
    required this.auditoria,
    required this.ejecutadaPor,
    required this.diferencias,
  });
}

class AuditoriaRepository {
  final DatabaseHelper databaseHelper;
  final ProductoRepository productoRepository;
  final SyncQueueRepository syncQueueRepository;

  AuditoriaRepository({
    DatabaseHelper? databaseHelper,
    ProductoRepository? productoRepository,
    SyncQueueRepository? syncQueueRepository,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       productoRepository = productoRepository ?? ProductoRepository(),
       syncQueueRepository = syncQueueRepository ?? SyncQueueRepository();

  Future<AuditoriaSqliteModel> crearAuditoriaDiaria({
    required int negocioId,
    int? colaboradorId,
    required List<Producto> productos,
    int cantidadObjetivo = 3,
  }) {
    final seleccion = _seleccionarDiaria(productos, cantidadObjetivo);
    return _crearAuditoria(
      negocioId: negocioId,
      colaboradorId: colaboradorId,
      tipo: AuditoriaSqliteModel.tipoDiaria,
      productos: seleccion,
    );
  }

  Future<AuditoriaSqliteModel> crearAuditoriaSemanal({
    required int negocioId,
    int? colaboradorId,
    required List<Producto> productos,
    int cantidadObjetivo = 5,
  }) {
    final claves = productos
        .where((producto) => producto.esClave && producto.cantidad > 0)
        .toList(growable: false);
    final base = claves.length >= cantidadObjetivo
        ? claves
        : productos.where((producto) => producto.cantidad > 0).toList();
    final seleccion = List<Producto>.from(base)
      ..sort(
        (a, b) => b.rotacionSemanaAnterior.compareTo(a.rotacionSemanaAnterior),
      );
    return _crearAuditoria(
      negocioId: negocioId,
      colaboradorId: colaboradorId,
      tipo: AuditoriaSqliteModel.tipoSemanal,
      productos: seleccion.take(cantidadObjetivo).toList(growable: false),
    );
  }

  Future<AuditoriaSqliteModel?> obtenerAuditoriaActual({
    required int negocioId,
    int? colaboradorId,
    required String tipo,
  }) async {
    final db = await databaseHelper.database;
    final fecha = _inicioPeriodo(DateTime.now(), tipo);
    final whereParts = [
      'negocio_id = ?',
      'tipo = ?',
      'fecha >= ?',
      'estado != ?',
    ];
    final whereArgs = <Object?>[
      negocioId,
      tipo,
      fecha.toIso8601String(),
      AuditoriaSqliteModel.estadoFinalizada,
    ];
    if (colaboradorId != null) {
      whereParts.add('colaborador_id = ?');
      whereArgs.add(colaboradorId);
    }

    final rows = await db.query(
      DatabaseSchema.auditoriasTable,
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AuditoriaSqliteModel.fromMap(rows.first);
  }

  Future<List<AuditoriaResumen>> obtenerAuditoriasPorNegocio(
    int negocioId, {
    int limit = 100,
  }) async {
    return _obtenerAuditorias(where: 'a.negocio_id = ?', args: [negocioId]);
  }

  Future<List<AuditoriaResumen>> obtenerAuditoriasPorColaborador(
    int colaboradorId, {
    int limit = 100,
  }) async {
    return _obtenerAuditorias(
      where: 'a.colaborador_id = ?',
      args: [colaboradorId],
    );
  }

  Future<void> validarItem({
    required int auditoriaId,
    required int productoSqliteId,
    required int stockFisico,
    String? observacion,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.auditoriaItemsTable,
      where: 'auditoria_id = ? AND producto_id = ?',
      whereArgs: [auditoriaId, productoSqliteId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final item = AuditoriaItemSqliteModel.fromMap(rows.first);
    final estado = stockFisico == item.stockSistema
        ? AuditoriaItemSqliteModel.estadoCorrecto
        : AuditoriaItemSqliteModel.estadoDiferencia;
    final now = DateTime.now();
    await db.update(
      DatabaseSchema.auditoriaItemsTable,
      {
        'stock_fisico': stockFisico,
        'estado_validacion': estado,
        'observacion': observacion,
        'updated_at': now.toIso8601String(),
        'sync_status': SyncStatus.updated,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
    final updatedRows = await db.query(
      DatabaseSchema.auditoriaItemsTable,
      where: 'id = ?',
      whereArgs: [item.id],
      limit: 1,
    );
    if (updatedRows.isNotEmpty) {
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.auditoriaItemsTable,
        entityId: item.id!,
        payload: updatedRows.first,
      );
    }
    await _actualizarConteo(auditoriaId);
  }

  Future<void> finalizarAuditoria(
    int auditoriaId, {
    String? observaciones,
  }) async {
    final db = await databaseHelper.database;
    await _actualizarConteo(auditoriaId);
    await db.update(
      DatabaseSchema.auditoriasTable,
      {
        'estado': AuditoriaSqliteModel.estadoFinalizada,
        'observaciones': observaciones,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': SyncStatus.updated,
      },
      where: 'id = ?',
      whereArgs: [auditoriaId],
    );
    final rows = await db.query(
      DatabaseSchema.auditoriasTable,
      where: 'id = ?',
      whereArgs: [auditoriaId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.auditoriasTable,
        entityId: auditoriaId,
        payload: rows.first,
      );
    }
  }

  Future<List<AuditoriaDetalleItem>> obtenerItemsPorAuditoria(
    int auditoriaId,
  ) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      '''
SELECT i.*, p.nombre AS producto_nombre, p.ubicacion, p.legacy_id, p.es_clave
FROM ${DatabaseSchema.auditoriaItemsTable} i
INNER JOIN ${DatabaseSchema.productosTable} p
  ON p.id = i.producto_id AND p.negocio_id = i.negocio_id
WHERE i.auditoria_id = ?
ORDER BY i.id ASC
''',
      [auditoriaId],
    );
    return rows.map((row) {
      return AuditoriaDetalleItem(
        item: AuditoriaItemSqliteModel.fromMap(row),
        productoNombre: row['producto_nombre'] as String,
        ubicacion: row['ubicacion'] as String? ?? 'Sin ubicacion',
        legacyId: row['legacy_id'] as String? ?? '${row['producto_id']}',
        esClave: (row['es_clave'] as num? ?? 0).toInt() == 1,
      );
    }).toList();
  }

  Future<int> contarPendientes(int negocioId) async {
    final db = await databaseHelper.database;
    final result = await db.rawQuery(
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.auditoriasTable}
WHERE negocio_id = ? AND estado != ?
''',
      [negocioId, AuditoriaSqliteModel.estadoFinalizada],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<DateTime?> obtenerUltimaFinalizada({
    required int negocioId,
    required String tipo,
    int? colaboradorId,
  }) async {
    final db = await databaseHelper.database;
    final whereParts = ['negocio_id = ?', 'tipo = ?', 'estado = ?'];
    final args = <Object?>[
      negocioId,
      tipo,
      AuditoriaSqliteModel.estadoFinalizada,
    ];
    if (colaboradorId != null) {
      whereParts.add('colaborador_id = ?');
      args.add(colaboradorId);
    }
    final rows = await db.query(
      DatabaseSchema.auditoriasTable,
      columns: ['fecha'],
      where: whereParts.join(' AND '),
      whereArgs: args,
      orderBy: 'fecha DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['fecha'] as String);
  }

  Future<AuditoriaSqliteModel> _crearAuditoria({
    required int negocioId,
    int? colaboradorId,
    required String tipo,
    required List<Producto> productos,
  }) async {
    final now = DateTime.now();
    final created = await databaseHelper.runInTransaction((transaction) async {
      final auditoria = AuditoriaSqliteModel(
        negocioId: negocioId,
        colaboradorId: colaboradorId,
        tipo: tipo,
        fecha: now,
        estado: AuditoriaSqliteModel.estadoEnProceso,
        totalProductos: productos.length,
        createdAt: now,
        updatedAt: now,
      );
      final auditoriaId = await transaction.insert(
        DatabaseSchema.auditoriasTable,
        auditoria.toMap(),
      );
      for (final producto in productos) {
        final productoRows = await transaction.query(
          DatabaseSchema.productosTable,
          columns: ['id'],
          where: 'negocio_id = ? AND legacy_id = ? AND activo = ?',
          whereArgs: [negocioId, producto.id, 1],
          limit: 1,
        );
        var productoId = productoRows.isEmpty
            ? null
            : productoRows.first['id'] as int?;
        productoId ??= await transaction.insert(
          DatabaseSchema.productosTable,
          {
            'negocio_id': negocioId,
            'nombre': producto.nombre,
            'cantidad': producto.cantidad,
            'legacy_id': producto.id,
            'ubicacion': producto.ubicacion,
            'tipo_medida': producto.tipoMedida,
            'nivel_demanda': producto.nivelDemanda,
            'es_clave': producto.esClave ? 1 : 0,
            'activo': 1,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
            'sync_status': 'pending',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await transaction.insert(
          DatabaseSchema.auditoriaItemsTable,
          AuditoriaItemSqliteModel(
            auditoriaId: auditoriaId,
            productoId: productoId,
            stockSistema: producto.cantidad,
            createdAt: now,
            updatedAt: now,
          ).toMap(),
        );
      }
      return auditoria.copyWith(id: auditoriaId);
    });
    await syncQueueRepository.enqueueCreate(
      entityType: DatabaseSchema.auditoriasTable,
      entityId: created.id!,
      payload: created.toMap(includeId: true),
    );
    final db = await databaseHelper.database;
    final itemRows = await db.query(
      DatabaseSchema.auditoriaItemsTable,
      where: 'auditoria_id = ?',
      whereArgs: [created.id],
    );
    for (final row in itemRows) {
      await syncQueueRepository.enqueueCreate(
        entityType: DatabaseSchema.auditoriaItemsTable,
        entityId: row['id'] as int,
        payload: row,
      );
    }
    return created;
  }

  List<Producto> _seleccionarDiaria(
    List<Producto> productos,
    int cantidadObjetivo,
  ) {
    final disponibles = productos
        .where((producto) => producto.cantidad > 0)
        .toList();
    final seleccion = List<Producto>.from(disponibles)..shuffle(Random());
    return seleccion.take(cantidadObjetivo).toList(growable: false);
  }

  DateTime _inicioPeriodo(DateTime fecha, String tipo) {
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    if (tipo == AuditoriaSqliteModel.tipoSemanal) {
      return dia.subtract(Duration(days: dia.weekday - 1));
    }
    return dia;
  }

  Future<void> _actualizarConteo(int auditoriaId) async {
    final db = await databaseHelper.database;
    final result = await db.rawQuery(
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.auditoriaItemsTable}
WHERE auditoria_id = ? AND estado_validacion != ?
''',
      [auditoriaId, AuditoriaItemSqliteModel.estadoPendiente],
    );
    await db.update(
      DatabaseSchema.auditoriasTable,
      {
        'productos_validados': Sqflite.firstIntValue(result) ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': SyncStatus.updated,
      },
      where: 'id = ?',
      whereArgs: [auditoriaId],
    );
  }

  Future<List<AuditoriaResumen>> _obtenerAuditorias({
    required String where,
    required List<Object?> args,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      '''
SELECT a.*, COALESCE(u.nombre, 'Negocio') AS ejecutada_por,
  (
    SELECT COUNT(*)
    FROM ${DatabaseSchema.auditoriaItemsTable} i
    WHERE i.auditoria_id = a.id
      AND i.estado_validacion = ?
  ) AS diferencias
FROM ${DatabaseSchema.auditoriasTable} a
LEFT JOIN ${DatabaseSchema.usuariosTable} u ON u.id = a.colaborador_id
WHERE $where
ORDER BY a.fecha DESC
LIMIT 100
''',
      [AuditoriaItemSqliteModel.estadoDiferencia, ...args],
    );
    return rows.map((row) {
      return AuditoriaResumen(
        auditoria: AuditoriaSqliteModel.fromMap(row),
        ejecutadaPor: row['ejecutada_por'] as String,
        diferencias: (row['diferencias'] as num? ?? 0).toInt(),
      );
    }).toList();
  }
}
