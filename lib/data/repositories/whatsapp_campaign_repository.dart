import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../../core/sync/sync_status.dart';
import '../models/whatsapp_campaign_publication.dart';
import 'sync_queue_repository.dart';

class WhatsappCampaignRepository {
  static const _storageKey = 'whatsapp_campaign_publications_v1';
  static const _migrationKey = 'whatsapp_campaign_publications_sqlite_v1_done';

  final LocalDatabase databaseHelper;
  final SyncQueueRepository syncQueueRepository;

  WhatsappCampaignRepository({
    LocalDatabase? databaseHelper,
    SyncQueueRepository? syncQueueRepository,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       syncQueueRepository = syncQueueRepository ?? SyncQueueRepository();

  Future<int> contarPublicacionesUsadasHoy({
    required int negocioId,
    required DateTime date,
  }) async {
    final dateKey = _dateKey(date);
    final publications = await obtenerHistorial(negocioId: negocioId);
    return publications
        .where((item) {
          return item.dateKey == dateKey &&
              item.consumesQuota &&
              WhatsappCampaignPublicationStatus.usadosDelDia.contains(
                item.status,
              );
        })
        .fold<int>(0, (total, item) => total + item.quotaUnits);
  }

  Future<bool> puedePublicarHoy({
    required int negocioId,
    required DateTime date,
    required int limiteDiario,
    int unidades = 1,
  }) async {
    final usadas = await contarPublicacionesUsadasHoy(
      negocioId: negocioId,
      date: date,
    );
    return usadas + unidades <= limiteDiario;
  }

  Future<WhatsappCampaignPublication> crearPendiente({
    required int negocioId,
    required String mode,
    required List<String> productIds,
    required List<String> renderedImagePaths,
    required List<String> statusTexts,
    int quotaUnits = 1,
    DateTime? now,
  }) async {
    final createdAt = now ?? DateTime.now();
    final publication = WhatsappCampaignPublication(
      id: _publicationId(
        negocioId: negocioId,
        dateKey: _dateKey(createdAt),
        mode: mode,
        productIds: productIds,
        renderedImagePaths: renderedImagePaths,
        statusTexts: statusTexts,
      ),
      negocioId: negocioId,
      dateKey: _dateKey(createdAt),
      mode: mode,
      productIds: productIds,
      renderedImagePaths: renderedImagePaths,
      statusTexts: statusTexts,
      status: WhatsappCampaignPublicationStatus.pendiente,
      consumesQuota: false,
      quotaUnits: quotaUnits,
      createdAt: createdAt,
    );
    await _upsert(publication, operation: SyncOperationType.create);
    return publication;
  }

  Future<WhatsappCampaignPublication> registrarEnviadoAWhatsapp(
    WhatsappCampaignPublication publication, {
    DateTime? now,
  }) async {
    final updated = publication.copyWith(
      status: WhatsappCampaignPublicationStatus.enviadoAWhatsapp,
      consumesQuota: true,
      openedWhatsappAt: now ?? DateTime.now(),
    );
    await _upsert(updated, operation: SyncOperationType.update);
    return updated;
  }

  Future<WhatsappCampaignPublication> registrarConfirmacionUsuario(
    WhatsappCampaignPublication publication, {
    DateTime? now,
  }) async {
    final confirmedAt = now ?? DateTime.now();
    final updated = publication.copyWith(
      status: WhatsappCampaignPublicationStatus.confirmadoPorUsuario,
      consumesQuota: true,
      confirmedByUserAt: confirmedAt,
      estimatedExpiresAt: confirmedAt.add(const Duration(hours: 24)),
    );
    await _upsert(updated, operation: SyncOperationType.update);
    return updated;
  }

  Future<WhatsappCampaignPublication> registrarCancelacionUsuario(
    WhatsappCampaignPublication publication, {
    DateTime? now,
  }) async {
    final updated = publication.copyWith(
      status: WhatsappCampaignPublicationStatus.canceladoPorUsuario,
      consumesQuota: true,
      canceledByUserAt: now ?? DateTime.now(),
    );
    await _upsert(updated, operation: SyncOperationType.update);
    return updated;
  }

  Future<WhatsappCampaignPublication> registrarFalloAntesDeAbrirWhatsapp(
    WhatsappCampaignPublication publication, {
    required String error,
    DateTime? now,
  }) async {
    final updated = publication.copyWith(
      status: WhatsappCampaignPublicationStatus.fallidoAntesDeAbrirWhatsapp,
      consumesQuota: false,
      failedAt: now ?? DateTime.now(),
      error: error,
    );
    await _upsert(updated, operation: SyncOperationType.update);
    return updated;
  }

  Future<bool> puedeReintentarMismaPublicacion(
    WhatsappCampaignPublication publication,
  ) async {
    final existing = await obtenerPorId(publication.id);
    if (existing == null) return false;
    return existing.puedeReintentarMismaPublicacion &&
        _sameList(existing.renderedImagePaths, publication.renderedImagePaths);
  }

  Future<WhatsappCampaignPublication?> obtenerPorId(String id) async {
    final publications = await _readAll();
    for (final publication in publications) {
      if (publication.id == id) return publication;
    }
    return null;
  }

  Future<List<WhatsappCampaignPublication>> obtenerHistorial({
    required int negocioId,
  }) async {
    await retirarProductosNoDisponibles(negocioId: negocioId);
    final publications = await _readAll();
    final result = publications
        .where((item) => item.negocioId == negocioId)
        .toList(growable: false);
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<int> retirarProductosNoDisponibles({required int negocioId}) async {
    await _migrateLegacyPrefsIfNeeded();
    final db = await databaseHelper.database;
    final productRows = await db.query(
      DatabaseSchema.productosTable,
      columns: ['id', 'legacy_id'],
      where: 'negocio_id = ? AND activo = 1 AND cantidad > 0',
      whereArgs: [negocioId],
    );
    final availableIds = <String>{
      for (final row in productRows) '${row['id']}',
      for (final row in productRows)
        if (row['legacy_id'] != null) '${row['legacy_id']}',
    };
    final campaigns = await db.query(
      DatabaseSchema.whatsappCampaignPublicationsTable,
      where:
          'negocio_id = ? AND is_active = 1 AND deleted_at IS NULL AND campaign_status != ?',
      whereArgs: [negocioId, WhatsappCampaignStatus.finalizado],
    );

    var changed = 0;
    for (final row in campaigns) {
      final publication = _fromDbMap(row);
      final filtered = publication.productIds
          .where(availableIds.contains)
          .toList(growable: false);
      if (_sameList(filtered, publication.productIds)) continue;
      final now = DateTime.now().toIso8601String();
      final localId = publication.localId;
      if (localId == null) continue;
      await db.update(
        DatabaseSchema.whatsappCampaignPublicationsTable,
        {
          'product_ids_json': jsonEncode(filtered),
          'updated_at': now,
          'sync_status': SyncStatus.updated,
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.whatsappCampaignPublicationsTable,
        entityId: localId,
        payload: {
          ...publication
              .copyWith(
                updatedAt: DateTime.parse(now),
                syncStatus: SyncStatus.updated,
              )
              .toJson(),
          'localUuid': publication.id,
          'productIds': filtered,
        },
      );
      changed++;
    }
    return changed;
  }

  Future<void> _upsert(
    WhatsappCampaignPublication publication, {
    required String operation,
  }) async {
    await _migrateLegacyPrefsIfNeeded();
    final db = await databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final map = _toDbMap(publication, updatedAt: now);
    final existing = await db.query(
      DatabaseSchema.whatsappCampaignPublicationsTable,
      columns: ['id'],
      where: 'local_uuid = ?',
      whereArgs: [publication.id],
      limit: 1,
    );
    late final int localId;
    if (existing.isEmpty) {
      localId = await db.insert(
        DatabaseSchema.whatsappCampaignPublicationsTable,
        map,
      );
    } else {
      localId = (existing.first['id'] as num).toInt();
      await db.update(
        DatabaseSchema.whatsappCampaignPublicationsTable,
        map,
        where: 'id = ?',
        whereArgs: [localId],
      );
    }
    final payload = {
      ...publication
          .copyWith(localId: localId, updatedAt: DateTime.parse(now))
          .toJson(),
      'localUuid': publication.id,
    };
    if (operation == SyncOperationType.create && existing.isEmpty) {
      await syncQueueRepository.enqueueCreate(
        entityType: DatabaseSchema.whatsappCampaignPublicationsTable,
        entityId: localId,
        payload: payload,
      );
    } else {
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.whatsappCampaignPublicationsTable,
        entityId: localId,
        payload: payload,
      );
    }
  }

  Future<List<WhatsappCampaignPublication>> _readAll() async {
    await _migrateLegacyPrefsIfNeeded();
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.whatsappCampaignPublicationsTable,
      where: 'is_active = 1 AND deleted_at IS NULL',
    );
    return rows.map(_fromDbMap).toList();
  }

  Future<List<WhatsappCampaignPublication>> _readLegacyPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <WhatsappCampaignPublication>[];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .map(WhatsappCampaignPublication.fromJson)
        .toList();
  }

  Future<void> _migrateLegacyPrefsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationKey) == true) return;
    final legacy = await _readLegacyPrefs();
    if (legacy.isNotEmpty) {
      final db = await databaseHelper.database;
      final batch = db.batch();
      for (final publication in legacy) {
        batch.insert(
          DatabaseSchema.whatsappCampaignPublicationsTable,
          _toDbMap(publication, syncStatus: SyncStatus.pending),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    }
    await prefs.setBool(_migrationKey, true);
  }

  Map<String, Object?> _toDbMap(
    WhatsappCampaignPublication publication, {
    String? updatedAt,
    String? syncStatus,
  }) {
    return {
      'local_uuid': publication.id,
      'remote_id': publication.remoteId,
      'negocio_id': publication.negocioId,
      'date_key': publication.dateKey,
      'mode': publication.mode,
      'product_ids_json': jsonEncode(publication.productIds),
      'rendered_image_paths_json': jsonEncode(publication.renderedImagePaths),
      'status_texts_json': jsonEncode(publication.statusTexts),
      'status': publication.status,
      'campaign_status': publication.campaignStatus,
      'consumes_quota': publication.consumesQuota ? 1 : 0,
      'quota_units': publication.quotaUnits,
      'fecha_inicio': publication.fechaInicio.toIso8601String(),
      'duracion_dias': publication.duracionDias,
      'created_at': publication.createdAt.toIso8601String(),
      'updated_at': updatedAt ?? publication.updatedAt?.toIso8601String(),
      'opened_whatsapp_at': publication.openedWhatsappAt?.toIso8601String(),
      'confirmed_by_user_at': publication.confirmedByUserAt?.toIso8601String(),
      'canceled_by_user_at': publication.canceledByUserAt?.toIso8601String(),
      'failed_at': publication.failedAt?.toIso8601String(),
      'estimated_expires_at': publication.estimatedExpiresAt?.toIso8601String(),
      'error': publication.error,
      'is_active': publication.isActive ? 1 : 0,
      'deleted_at': publication.deletedAt?.toIso8601String(),
      'last_synced_at': publication.lastSyncedAt?.toIso8601String(),
      'sync_status': syncStatus ?? publication.syncStatus,
    };
  }

  WhatsappCampaignPublication _fromDbMap(Map<String, Object?> map) {
    return WhatsappCampaignPublication(
      localId: (map['id'] as num?)?.toInt(),
      id: map['local_uuid'] as String,
      remoteId: map['remote_id'] as String?,
      negocioId: (map['negocio_id'] as num).toInt(),
      dateKey: map['date_key'] as String,
      mode: map['mode'] as String? ?? 'catalogo',
      productIds: _jsonStringList(map['product_ids_json']),
      renderedImagePaths: _jsonStringList(map['rendered_image_paths_json']),
      statusTexts: _jsonStringList(map['status_texts_json']),
      status:
          map['status'] as String? ??
          WhatsappCampaignPublicationStatus.pendiente,
      campaignStatus:
          map['campaign_status'] as String? ?? WhatsappCampaignStatus.activo,
      consumesQuota: (map['consumes_quota'] as num? ?? 0).toInt() == 1,
      quotaUnits: (map['quota_units'] as num? ?? 1).toInt(),
      fechaInicio: DateTime.parse(map['fecha_inicio'] as String),
      duracionDias: (map['duracion_dias'] as num? ?? 7).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: _dateOrNull(map['updated_at']),
      openedWhatsappAt: _dateOrNull(map['opened_whatsapp_at']),
      confirmedByUserAt: _dateOrNull(map['confirmed_by_user_at']),
      canceledByUserAt: _dateOrNull(map['canceled_by_user_at']),
      failedAt: _dateOrNull(map['failed_at']),
      estimatedExpiresAt: _dateOrNull(map['estimated_expires_at']),
      error: map['error'] as String?,
      isActive: (map['is_active'] as num? ?? 1).toInt() == 1,
      deletedAt: _dateOrNull(map['deleted_at']),
      lastSyncedAt: _dateOrNull(map['last_synced_at']),
      syncStatus: map['sync_status'] as String? ?? SyncStatus.pending,
    );
  }

  List<String> _jsonStringList(Object? value) {
    if (value == null) return const [];
    final decoded = jsonDecode('$value') as List<dynamic>? ?? const [];
    return decoded.map((item) => '$item').toList();
  }

  DateTime? _dateOrNull(Object? value) {
    if (value == null || '$value'.trim().isEmpty) return null;
    return DateTime.parse('$value');
  }

  String _dateKey(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  String _publicationId({
    required int negocioId,
    required String dateKey,
    required String mode,
    required List<String> productIds,
    required List<String> renderedImagePaths,
    required List<String> statusTexts,
  }) {
    final source = [
      negocioId,
      dateKey,
      mode,
      ...productIds,
      ...renderedImagePaths,
      ...statusTexts,
    ].join('|');
    return 'wcp_${source.hashCode.abs()}';
  }

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
