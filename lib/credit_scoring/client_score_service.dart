import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_schema.dart';
import '../core/sync/sync_status.dart';
import '../core/utils/money_formatter.dart';
import '../data/models/client_score_sync_model.dart';
import '../data/models/credito_ciclo_sqlite_model.dart';
import '../data/repositories/credito_ciclo_repository.dart';
import '../data/repositories/movimiento_repository.dart';
import '../data/repositories/sync_queue_repository.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import 'client_score.dart';

class ClientScoreService {
  final MovimientoRepository movimientoRepository;
  final CreditoCicloRepository creditoCicloRepository;
  final DatabaseHelper databaseHelper;
  final SyncQueueRepository syncQueueRepository;

  const ClientScoreService({
    required this.movimientoRepository,
    required this.creditoCicloRepository,
    required this.databaseHelper,
    required this.syncQueueRepository,
  });

  Future<ClientScore> calculateClientScore({
    required Cliente cliente,
    required int businessId,
  }) async {
    final movimientos = await movimientoRepository.obtenerPorCliente(
      negocioId: businessId,
      nombreCliente: cliente.nombre,
      clienteTelefono: cliente.telefono,
      limit: 1000,
    );
    final clienteId = await creditoCicloRepository.resolverClienteId(
      negocioId: businessId,
      telefono: cliente.telefono,
      nombre: cliente.nombre,
    );
    final ciclos = clienteId == null
        ? const <CreditoCicloSqliteModel>[]
        : await creditoCicloRepository.obtenerCiclosPorCliente(
            clienteId,
            businessId,
          );

    final score = calculateFromData(
      cliente: cliente,
      businessId: businessId,
      clientId: clienteId,
      movimientos: movimientos,
      ciclos: ciclos,
    );
    if (clienteId != null) {
      await saveScoreSnapshot(score, clienteId: clienteId);
    }
    return score;
  }

  ClientScore calculateFromData({
    required Cliente cliente,
    required int businessId,
    required int? clientId,
    required List<Movimiento> movimientos,
    required List<CreditoCicloSqliteModel> ciclos,
  }) {
    final totalCredits = movimientos
        .where((m) => m.tipo == 'deuda')
        .fold<double>(0, (sum, item) => sum + item.monto);
    final totalPayments = movimientos
        .where((m) => m.tipo == 'pago')
        .fold<double>(0, (sum, item) => sum + item.monto);
    final creditCount = movimientos.where((m) => m.tipo == 'deuda').length;
    final paymentCount = movimientos.where((m) => m.tipo == 'pago').length;
    final completedCycles = ciclos
        .where((c) => c.estado == CreditoCicloEstado.saldado)
        .length;
    final overdue30 = ciclos
        .where((c) => c.estado == CreditoCicloEstado.vencido30)
        .length;
    final overdue45 = ciclos
        .where((c) => c.estado == CreditoCicloEstado.mora45)
        .length;
    final blocked60 = ciclos
        .where((c) => c.estado == CreditoCicloEstado.bloqueado60 || c.bloqueado)
        .length;

    final paidBefore30 = ciclos.where((c) {
      final settledAt = c.fechaSaldado;
      return settledAt != null &&
          settledAt.difference(c.fechaInicio).inDays <= 30;
    }).length;
    final paid30To45 = ciclos.where((c) {
      final settledAt = c.fechaSaldado;
      if (settledAt == null) return false;
      final days = settledAt.difference(c.fechaInicio).inDays;
      return days > 30 && days <= 45;
    }).length;
    final paid45To60 = ciclos.where((c) {
      final settledAt = c.fechaSaldado;
      if (settledAt == null) return false;
      final days = settledAt.difference(c.fechaInicio).inDays;
      return days > 45 && days <= 60;
    }).length;

    final compliance = totalCredits <= 0
        ? 100.0
        : ((totalPayments / totalCredits) * 100).clamp(0, 100).toDouble();
    final oldestMovement = movimientos.isEmpty
        ? DateTime.now()
        : movimientos
              .map((m) => m.fecha)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    final ageDays = DateTime.now().difference(oldestMovement).inDays;

    var score = 50;
    score += (paidBefore30 * 7).clamp(0, 21).toInt();
    score += (paid30To45 * 3).clamp(0, 12).toInt();
    score += (completedCycles * 4).clamp(0, 16).toInt();
    score += paymentCount > 0 ? 6 : 0;
    score += ageDays >= 180 ? 8 : (ageDays >= 60 ? 4 : 0);
    score -= (paid45To60 * 4).clamp(0, 16).toInt();
    score -= (overdue30 * 5).clamp(0, 20).toInt();
    score -= (overdue45 * 9).clamp(0, 27).toInt();
    score -= (blocked60 * 18).clamp(0, 54).toInt();
    if (compliance < 50) score -= 12;
    if (compliance >= 90 && totalCredits > 0) score += 8;
    score = score.clamp(0, 100).toInt();

    final riskLevel = score >= 70
        ? ClientRiskLevel.low
        : score >= 40
        ? ClientRiskLevel.medium
        : ClientRiskLevel.high;
    final averageCredit = creditCount == 0 ? 0 : totalCredits / creditCount;
    final paidHistoryFactor = totalPayments <= 0 ? 0.6 : 1.0;
    final scoreFactor = score / 100;
    final baseSuggestedLimit =
        averageCredit * (0.8 + scoreFactor) * paidHistoryFactor;
    final riskCap = blocked60 > 0
        ? averageCredit * 0.1
        : overdue45 > 0
        ? averageCredit * 0.25
        : overdue30 > 0
        ? averageCredit * 0.4
        : riskLevel == ClientRiskLevel.high
        ? averageCredit * 0.3
        : totalPayments + averageCredit;
    final suggestedLimit = _roundMoney(baseSuggestedLimit.clamp(0, riskCap));

    return ClientScore(
      clientId: clientId,
      businessId: businessId,
      clientName: cliente.nombre,
      clientPhone: cliente.telefono,
      score: score,
      riskLevel: riskLevel,
      suggestedCreditLimit: suggestedLimit,
      paymentCompliancePercent: compliance,
      totalCredits: totalCredits,
      totalPayments: totalPayments,
      overdue30Count: overdue30,
      overdue45Count: overdue45,
      blocked60Count: blocked60,
      lastCalculatedAt: DateTime.now(),
      reasons: _reasons(
        score: score,
        compliance: compliance,
        paidBefore30: paidBefore30,
        paid30To45: paid30To45,
        paid45To60: paid45To60,
        overdue30: overdue30,
        overdue45: overdue45,
        blocked60: blocked60,
        ageDays: ageDays,
        totalCredits: totalCredits,
        totalPayments: totalPayments,
      ),
    );
  }

  Future<BusinessClientScoreReport> buildBusinessReport({
    required int businessId,
    required List<Cliente> clientes,
  }) async {
    final scores = <ClientScore>[];
    for (final cliente in clientes) {
      final stored = await loadStoredScore(
        cliente: cliente,
        businessId: businessId,
      );
      final score =
          stored ??
          await calculateClientScore(cliente: cliente, businessId: businessId);
      scores.add(score);
    }
    final best = [...scores]..sort((a, b) => b.score.compareTo(a.score));
    final risky = [...scores]..sort((a, b) => a.score.compareTo(b.score));
    return BusinessClientScoreReport(
      bestClients: best.take(10).toList(),
      riskyClients: risky.take(10).toList(),
    );
  }

  static double _roundMoney(num value) {
    return ((value * 100).round()) / 100;
  }

  Future<ClientScore?> loadStoredScore({
    required Cliente cliente,
    required int businessId,
  }) async {
    final db = await databaseHelper.database;
    final clientRow = await _clientRow(db, businessId, cliente);
    if (clientRow == null) return null;
    final rows = await db.query(
      DatabaseSchema.clientScoresTable,
      where: 'negocio_id = ? AND cliente_id = ? AND deleted_at IS NULL',
      whereArgs: [businessId, clientRow['id']],
      orderBy: 'last_calculated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ClientScoreSyncModel.fromMap(
      rows.first,
    ).toScore(clientName: cliente.nombre, clientPhone: cliente.telefono);
  }

  Future<int> saveScoreSnapshot(
    ClientScore score, {
    required int clienteId,
  }) async {
    final db = await databaseHelper.database;
    final existing = await db.query(
      DatabaseSchema.clientScoresTable,
      where: 'negocio_id = ? AND cliente_id = ?',
      whereArgs: [score.businessId, clienteId],
      limit: 1,
    );
    final now = DateTime.now();
    final model = ClientScoreSyncModel.fromScore(
      score,
      clienteId: clienteId,
      id: existing.isEmpty ? null : (existing.first['id'] as num).toInt(),
      remoteId: existing.isEmpty
          ? null
          : existing.first['remote_id'] as String?,
      createdAt: existing.isEmpty
          ? now
          : DateTime.tryParse('${existing.first['created_at'] ?? ''}') ?? now,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    final int localId;
    if (existing.isEmpty) {
      localId = await db.insert(
        DatabaseSchema.clientScoresTable,
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await syncQueueRepository.enqueueCreate(
        entityType: DatabaseSchema.clientScoresTable,
        entityId: localId,
        payload: {...model.toMap(), 'id': localId},
      );
    } else {
      localId = (existing.first['id'] as num).toInt();
      await db.update(
        DatabaseSchema.clientScoresTable,
        model.toMap(includeId: true),
        where: 'id = ?',
        whereArgs: [localId],
      );
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.clientScoresTable,
        entityId: localId,
        payload: {...model.toMap(includeId: true), 'id': localId},
      );
    }
    return localId;
  }

  Future<Map<String, Object?>?> _clientRow(
    Database db,
    int businessId,
    Cliente cliente,
  ) async {
    final rows = await db.query(
      DatabaseSchema.clientesTable,
      where:
          'negocio_id = ? AND (telefono = ? OR LOWER(nombre) = LOWER(?)) AND COALESCE(is_active, 1) = 1',
      whereArgs: [businessId, cliente.telefono, cliente.nombre],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static List<String> _reasons({
    required int score,
    required double compliance,
    required int paidBefore30,
    required int paid30To45,
    required int paid45To60,
    required int overdue30,
    required int overdue45,
    required int blocked60,
    required int ageDays,
    required double totalCredits,
    required double totalPayments,
  }) {
    final reasons = <String>[];
    if (paidBefore30 > 0) {
      reasons.add('Pagos completados antes de 30 dias: $paidBefore30.');
    }
    if (paid30To45 > 0) {
      reasons.add('Pagos completados entre 30 y 45 dias: $paid30To45.');
    }
    if (paid45To60 > 0) {
      reasons.add('Pagos completados entre 45 y 60 dias: $paid45To60.');
    }
    if (overdue30 > 0) reasons.add('Ciclos vencidos a 30 dias: $overdue30.');
    if (overdue45 > 0) reasons.add('Ciclos en mora 45 dias: $overdue45.');
    if (blocked60 > 0) reasons.add('Bloqueos 60 dias detectados: $blocked60.');
    reasons.add('Cumplimiento de pago: ${compliance.toStringAsFixed(1)}%.');
    if (ageDays >= 60) reasons.add('Antiguedad registrada: $ageDays dias.');
    if (totalCredits <= 0) {
      reasons.add('Sin historial de creditos; recomendacion conservadora.');
    } else {
      reasons.add(
        'Historial: ${MoneyFormatter.formatCurrency(totalCredits)} fiado y ${MoneyFormatter.formatCurrency(totalPayments)} pagado.',
      );
    }
    reasons.add(
      'Fiado App recomienda revisar este score junto al contexto del negocio.',
    );
    return reasons;
  }
}
