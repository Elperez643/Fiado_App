import 'dart:math';

import '../../models/cliente.dart';

class ClienteSqliteModel {
  final int? id;
  final int? negocioId;
  final String uuid;
  final String nombre;
  final String telefono;
  final String? address;
  final double deuda;
  final bool isActive;
  final DateTime? deletedAt;
  final DateTime? lastSyncedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncVersion;
  final String syncStatus;
  final String? remoteId;

  const ClienteSqliteModel({
    this.id,
    this.negocioId,
    required this.uuid,
    required this.nombre,
    required this.telefono,
    this.address,
    required this.deuda,
    this.isActive = true,
    this.deletedAt,
    this.lastSyncedAt,
    required this.createdAt,
    required this.updatedAt,
    this.syncVersion = 0,
    this.syncStatus = 'pending',
    this.remoteId,
  });

  factory ClienteSqliteModel.fromLegacy(Cliente cliente, {int? negocioId}) {
    final now = DateTime.now();
    return ClienteSqliteModel(
      negocioId: negocioId,
      uuid: clienteUuid(),
      nombre: cliente.nombre,
      telefono: cliente.telefono,
      deuda: cliente.deuda,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory ClienteSqliteModel.fromMap(Map<String, Object?> map) {
    return ClienteSqliteModel(
      id: map['id'] as int?,
      negocioId: (map['negocio_id'] as num?)?.toInt(),
      uuid: map['uuid'] as String? ?? 'client-local-${map['id']}',
      nombre: map['nombre'] as String,
      telefono: map['telefono'] as String,
      address: map['address'] as String?,
      deuda: (map['deuda'] as num).toDouble(),
      isActive: (map['is_active'] as num? ?? 1).toInt() == 1,
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.parse(map['deleted_at'] as String),
      lastSyncedAt: map['last_synced_at'] == null
          ? null
          : DateTime.parse(map['last_synced_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncVersion: (map['sync_version'] as num? ?? 0).toInt(),
      syncStatus: map['sync_status'] as String? ?? 'pending',
      remoteId: map['remote_id'] as String?,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'negocio_id': negocioId,
      'uuid': uuid,
      'nombre': nombre,
      'telefono': telefono,
      'address': address,
      'deuda': deuda,
      'is_active': isActive ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_version': syncVersion,
      'sync_status': syncStatus,
      'remote_id': remoteId,
    };
  }

  ClienteSqliteModel copyWith({
    int? id,
    int? negocioId,
    String? uuid,
    String? nombre,
    String? telefono,
    String? address,
    double? deuda,
    bool? isActive,
    DateTime? deletedAt,
    DateTime? lastSyncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncVersion,
    String? syncStatus,
    String? remoteId,
  }) {
    return ClienteSqliteModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      uuid: uuid ?? this.uuid,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      address: address ?? this.address,
      deuda: deuda ?? this.deuda,
      isActive: isActive ?? this.isActive,
      deletedAt: deletedAt ?? this.deletedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      syncStatus: syncStatus ?? this.syncStatus,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  Cliente toLegacyModel() {
    return Cliente(id: id, nombre: nombre, telefono: telefono, deuda: deuda);
  }
}

String clienteUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  return 'client-${hex.join()}';
}
