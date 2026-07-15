import 'dart:math';

import '../../models/movimiento.dart';

class MovimientoSqliteModel {
  final int? id;
  final int? negocioId;
  final int? personalUserId;
  final int? clienteId;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? clienteNombreSnapshot;
  final String? clienteTelefonoSnapshot;
  final String tipo;
  final double monto;
  final String? concepto;
  final DateTime fecha;
  final DateTime createdAt;
  final String syncStatus;
  final String? localUuid;
  final String? remoteId;

  const MovimientoSqliteModel({
    this.id,
    this.negocioId,
    this.personalUserId,
    this.clienteId,
    required this.clienteNombre,
    this.clienteTelefono,
    this.clienteNombreSnapshot,
    this.clienteTelefonoSnapshot,
    required this.tipo,
    required this.monto,
    this.concepto,
    required this.fecha,
    required this.createdAt,
    this.syncStatus = 'pending',
    this.localUuid,
    this.remoteId,
  });

  factory MovimientoSqliteModel.fromLegacy(
    Movimiento movimiento, {
    int? negocioId,
    int? personalUserId,
    int? clienteId,
    String? clienteTelefono,
    String? clienteNombreSnapshot,
    String? clienteTelefonoSnapshot,
  }) {
    return MovimientoSqliteModel(
      negocioId: negocioId,
      personalUserId: personalUserId,
      clienteId: clienteId ?? movimiento.clienteId,
      clienteNombre: movimiento.nombreCliente,
      clienteTelefono: clienteTelefono ?? movimiento.clienteTelefono,
      clienteNombreSnapshot:
          clienteNombreSnapshot ??
          movimiento.clienteNombreSnapshot ??
          movimiento.nombreCliente,
      clienteTelefonoSnapshot:
          clienteTelefonoSnapshot ??
          movimiento.clienteTelefonoSnapshot ??
          clienteTelefono ??
          movimiento.clienteTelefono,
      tipo: movimiento.tipo,
      monto: movimiento.monto,
      concepto: movimiento.concepto?.trim().isEmpty ?? true
          ? null
          : movimiento.concepto!.trim(),
      fecha: movimiento.fecha,
      createdAt: DateTime.now(),
      localUuid: _newLocalUuid(),
    );
  }

  factory MovimientoSqliteModel.fromMap(Map<String, Object?> map) {
    return MovimientoSqliteModel(
      id: map['id'] as int?,
      negocioId: (map['negocio_id'] as num?)?.toInt(),
      personalUserId: (map['personal_user_id'] as num?)?.toInt(),
      clienteId: (map['cliente_id'] as num?)?.toInt(),
      clienteNombre: map['cliente_nombre'] as String,
      clienteTelefono: map['cliente_telefono'] as String?,
      clienteNombreSnapshot: map['cliente_nombre_snapshot'] as String?,
      clienteTelefonoSnapshot: map['cliente_telefono_snapshot'] as String?,
      tipo: map['tipo'] as String,
      monto: (map['monto'] as num).toDouble(),
      concepto: map['concepto'] as String?,
      fecha: DateTime.parse(map['fecha'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
      localUuid: map['local_uuid'] as String?,
      remoteId: map['remote_id'] as String?,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'negocio_id': negocioId,
      'personal_user_id': personalUserId,
      'cliente_id': clienteId,
      'cliente_nombre': clienteNombre,
      'cliente_telefono': clienteTelefono,
      'cliente_nombre_snapshot': clienteNombreSnapshot ?? clienteNombre,
      'cliente_telefono_snapshot': clienteTelefonoSnapshot ?? clienteTelefono,
      'tipo': tipo,
      'monto': monto,
      'concepto': concepto,
      'fecha': fecha.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus,
      'local_uuid': localUuid,
      'remote_id': remoteId,
    };
  }

  Movimiento toLegacyModel() {
    return Movimiento(
      nombreCliente: clienteNombre,
      clienteId: clienteId,
      clienteTelefono: clienteTelefono,
      clienteNombreSnapshot: clienteNombreSnapshot ?? clienteNombre,
      clienteTelefonoSnapshot: clienteTelefonoSnapshot ?? clienteTelefono,
      tipo: tipo,
      monto: monto,
      fecha: fecha,
      concepto: concepto,
      id: id,
    );
  }
}

String _newLocalUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  return 'movement-${hex.join()}';
}
