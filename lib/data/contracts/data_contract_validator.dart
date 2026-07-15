import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../models/sync_outbox_item.dart';
import '../services/sync_endpoint_registry.dart';
import 'data_contract_registry.dart';

class DataContractValidator {
  static Future<void> validate(LocalDatabase databaseHelper) async {
    if (!kDebugMode) return;
    DataContractRegistry.validateDefinitions();
    final db = await databaseHelper.database;
    await validateDatabase(db);
  }

  static Future<void> validateDatabase(Database db) async {
    DataContractRegistry.validateDefinitions();
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final actualTables = tableRows
        .map((row) => row['name']?.toString())
        .whereType<String>()
        .toSet();
    final missingTables = DatabaseSchema.allTables.difference(actualTables);
    if (missingTables.isNotEmpty) {
      final table = missingTables.first;
      final contract = DataContractRegistry.forTable(table);
      throw StateError(
        'Contrato de datos incompleto: modulo=${contract.entity}; '
        'tabla esperada=$table; endpoint=${contract.outboxModule ?? contract.legacyHandler ?? 'local-only'}; '
        'archivo probable=${contract.repositoryFile}; accion recomendada: '
        'agregar/ejecutar migracion SQLite sin borrar datos.',
      );
    }

    final queuedTypes = await db.rawQuery(
      'SELECT DISTINCT entity_type FROM ${DatabaseSchema.syncQueueTable} '
      'WHERE status IN (?, ?, ?)',
      ['pending', 'failed', 'retry'],
    );
    final unknownQueueTypes = queuedTypes
        .map((row) => row['entity_type']?.toString())
        .whereType<String>()
        .where(
          (entityType) =>
              !DataContractRegistry.knownQueueEntityTypes.contains(entityType),
        )
        .toSet();
    if (unknownQueueTypes.isNotEmpty) {
      throw StateError(
        'sync_queue contiene entidades sin handler: $unknownQueueTypes; '
        'tabla esperada=sync_queue; archivo probable='
        'lib/data/contracts/data_contract_registry.dart; accion recomendada: '
        'registrar handler o declarar local-only sin borrar payloads.',
      );
    }

    final outboxModules = await db.rawQuery(
      'SELECT DISTINCT module FROM ${DatabaseSchema.syncOutboxTable} '
      'WHERE status IN (?, ?, ?)',
      [
        SyncOutboxItem.statusPending,
        SyncOutboxItem.statusSyncing,
        SyncOutboxItem.statusFailed,
      ],
    );
    for (final row in outboxModules) {
      final module = row['module']?.toString();
      if (module == null) continue;
      try {
        SyncEndpointRegistry.forModule(module);
      } on UnsupportedError {
        throw StateError(
          'sync_outbox contiene modulo sin endpoint: module=$module; '
          'tabla esperada=sync_outbox; archivo probable='
          'lib/data/services/sync_endpoint_registry.dart; accion recomendada: '
          'registrar endpoint/transformador conservando payload pendiente.',
        );
      }
    }
  }
}
