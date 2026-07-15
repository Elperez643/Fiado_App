import '../core/database/database_helper.dart';
import '../core/database/database_schema.dart';
import '../core/utils/money_formatter.dart';
import '../credit_scoring/client_score.dart';
import '../data/models/credito_ciclo_sqlite_model.dart';
import '../data/repositories/credito_ciclo_repository.dart';
import 'collection_insight.dart';

class CollectionsIntelligenceService {
  final DatabaseHelper databaseHelper;
  final CreditoCicloRepository creditoCicloRepository;

  const CollectionsIntelligenceService({
    required this.databaseHelper,
    required this.creditoCicloRepository,
  });

  Future<List<CollectionInsight>> calculateInsights({
    required int businessId,
  }) async {
    await creditoCicloRepository.actualizarEstadosPorFecha(businessId);
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      '''
SELECT
  c.id AS client_id,
  c.nombre AS client_name,
  c.telefono AS client_phone,
  SUM(cc.saldo_pendiente) AS total_pending_amount,
  MIN(cc.fecha_inicio) AS oldest_cycle_start_date,
  MIN(cc.fecha_limite_30) AS next_due_date,
  MAX(CASE WHEN cc.estado = ? THEN 1 ELSE 0 END) AS has_blocked_60,
  MAX(CASE WHEN cc.estado = ? THEN 1 ELSE 0 END) AS has_overdue_45,
  MAX(CASE WHEN cc.estado = ? THEN 1 ELSE 0 END) AS has_overdue_30,
  (
    SELECT MAX(m.fecha)
    FROM ${DatabaseSchema.movimientosTable} m
    WHERE m.negocio_id = c.negocio_id
      AND m.tipo = 'pago'
      AND (
        m.cliente_id = c.id
        OR (m.cliente_id IS NULL AND c.telefono IS NOT NULL AND m.cliente_telefono = c.telefono)
        OR (m.cliente_id IS NULL AND m.cliente_nombre = c.nombre)
      )
  ) AS last_payment_date,
  (
    SELECT MAX(m.fecha)
    FROM ${DatabaseSchema.movimientosTable} m
    WHERE m.negocio_id = c.negocio_id
      AND m.tipo = 'deuda'
      AND (
        m.cliente_id = c.id
        OR (m.cliente_id IS NULL AND c.telefono IS NOT NULL AND m.cliente_telefono = c.telefono)
        OR (m.cliente_id IS NULL AND m.cliente_nombre = c.nombre)
      )
  ) AS last_credit_date,
  cs.score AS client_score,
  cs.risk_level AS risk_level,
  u.nombre AS business_name
FROM ${DatabaseSchema.clientesTable} c
INNER JOIN ${DatabaseSchema.creditoCiclosTable} cc
  ON cc.cliente_id = c.id
  AND cc.negocio_id = c.negocio_id
LEFT JOIN ${DatabaseSchema.clientScoresTable} cs
  ON cs.negocio_id = c.negocio_id
  AND cs.cliente_id = c.id
  AND cs.deleted_at IS NULL
LEFT JOIN ${DatabaseSchema.usuariosTable} u
  ON u.id = c.negocio_id
WHERE c.negocio_id = ?
  AND c.is_active = 1
  AND cc.estado != ?
  AND cc.saldo_pendiente > 0
GROUP BY c.id, c.nombre, c.telefono, cs.score, cs.risk_level, u.nombre
ORDER BY has_blocked_60 DESC,
         has_overdue_45 DESC,
         has_overdue_30 DESC,
         next_due_date ASC,
         total_pending_amount DESC
''',
      [
        CreditoCicloEstado.bloqueado60,
        CreditoCicloEstado.mora45,
        CreditoCicloEstado.vencido30,
        businessId,
        CreditoCicloEstado.saldado,
      ],
    );

    final now = DateTime.now();
    return rows.map((row) => _mapInsight(row, businessId, now)).toList()
      ..sort(_comparePriority);
  }

  CollectionsIntelligenceSummary summarize(List<CollectionInsight> insights) {
    return CollectionsIntelligenceSummary.fromInsights(insights);
  }

  List<CollectionInsight> collectToday(List<CollectionInsight> insights) {
    return insights
        .where(
          (item) =>
              item.priorityLevel == CollectionPriority.critical ||
              item.priorityLevel == CollectionPriority.high ||
              (item.daysToDue != null && item.daysToDue! <= 0),
        )
        .toList();
  }

  List<CollectionInsight> dueSoon(List<CollectionInsight> insights) {
    return insights
        .where((item) => item.collectionStatus == CollectionStatus.dueSoon)
        .toList();
  }

  List<CollectionInsight> overdue45(List<CollectionInsight> insights) {
    return insights
        .where((item) => item.collectionStatus == CollectionStatus.overdue45)
        .toList();
  }

  List<CollectionInsight> blocked60(List<CollectionInsight> insights) {
    return insights
        .where((item) => item.collectionStatus == CollectionStatus.blocked60)
        .toList();
  }

  List<CollectionInsight> upToDateWithBalance(
    List<CollectionInsight> insights,
  ) {
    return insights
        .where(
          (item) =>
              item.collectionStatus == CollectionStatus.upToDate ||
              item.collectionStatus == CollectionStatus.pendingBalance,
        )
        .toList();
  }

  List<CollectionInsight> noUrgentAction(List<CollectionInsight> insights) {
    return insights
        .where((item) => item.priorityLevel == CollectionPriority.low)
        .toList();
  }

  CollectionInsight _mapInsight(
    Map<String, Object?> row,
    int businessId,
    DateTime now,
  ) {
    DateTime? parseDate(Object? value) {
      final text = value?.toString();
      if (text == null || text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    final clientId = (row['client_id'] as num).toInt();
    final clientName = row['client_name']?.toString() ?? 'Cliente';
    final clientPhone = row['client_phone']?.toString() ?? '';
    final businessName = row['business_name']?.toString() ?? 'tu negocio';
    final totalPending = (row['total_pending_amount'] as num? ?? 0).toDouble();
    final oldestCycle = parseDate(row['oldest_cycle_start_date']);
    final nextDue = parseDate(row['next_due_date']);
    final hasBlocked = (row['has_blocked_60'] as num? ?? 0).toInt() == 1;
    final hasOverdue45 = (row['has_overdue_45'] as num? ?? 0).toInt() == 1;
    final hasOverdue30 = (row['has_overdue_30'] as num? ?? 0).toInt() == 1;
    final riskLevel = row['risk_level']?.toString();
    final score = (row['client_score'] as num?)?.toInt();
    final daysToDue = nextDue == null ? null : _daysBetween(now, nextDue);
    final daysOverdue = daysToDue == null || daysToDue >= 0
        ? null
        : daysToDue.abs();

    final status = _status(
      hasBlocked: hasBlocked,
      hasOverdue45: hasOverdue45,
      hasOverdue30: hasOverdue30,
      daysToDue: daysToDue,
      totalPendingAmount: totalPending,
    );
    final priority = _priority(
      status: status,
      totalPendingAmount: totalPending,
      riskLevel: riskLevel,
      daysToDue: daysToDue,
    );
    final action = _recommendedAction(status, priority);
    final message = suggestedMessage(
      clientName: clientName,
      businessName: businessName,
      amount: totalPending,
      status: status,
    );

    return CollectionInsight(
      clientId: clientId,
      businessId: businessId,
      clientName: clientName,
      clientPhone: clientPhone,
      totalPendingAmount: totalPending,
      oldestCycleStartDate: oldestCycle,
      nextDueDate: nextDue,
      daysToDue: daysToDue,
      daysOverdue: daysOverdue,
      collectionStatus: status,
      priorityLevel: priority,
      recommendedAction: action,
      suggestedMessage: message,
      riskLevel: riskLevel,
      clientScore: score,
      lastPaymentDate: parseDate(row['last_payment_date']),
      lastCreditDate: parseDate(row['last_credit_date']),
      lastCalculatedAt: now,
    );
  }

  String suggestedMessage({
    required String clientName,
    required String businessName,
    required double amount,
    required String status,
  }) {
    final formattedAmount = MoneyFormatter.formatCurrency(amount);
    return switch (status) {
      CollectionStatus.dueSoon =>
        'Hola $clientName, te recordamos que tienes un credito pendiente en $businessName por $formattedAmount. Tu fecha de pago esta proxima.',
      CollectionStatus.overdue30 =>
        'Hola $clientName, tu credito en $businessName ya cumplio 30 dias. Monto pendiente: $formattedAmount. Por favor pasa por el negocio.',
      CollectionStatus.overdue45 =>
        'Hola $clientName, tienes un credito vencido en $businessName. Monto pendiente: $formattedAmount. Te pedimos pasar a saldar lo antes posible.',
      CollectionStatus.blocked60 =>
        'Hola $clientName, tu credito en $businessName supero el plazo permitido y esta bloqueado para nuevos fiados. Monto pendiente: $formattedAmount.',
      _ =>
        'Hola $clientName, te recordamos que tienes un saldo pendiente en $businessName por $formattedAmount. Cuando puedas, pasa por el negocio.',
    };
  }

  String _status({
    required bool hasBlocked,
    required bool hasOverdue45,
    required bool hasOverdue30,
    required int? daysToDue,
    required double totalPendingAmount,
  }) {
    if (totalPendingAmount <= 0) return CollectionStatus.noAction;
    if (hasBlocked) return CollectionStatus.blocked60;
    if (hasOverdue45) return CollectionStatus.overdue45;
    if (hasOverdue30) return CollectionStatus.overdue30;
    if (daysToDue != null && daysToDue >= 0 && daysToDue <= 3) {
      return CollectionStatus.dueSoon;
    }
    if (daysToDue != null && daysToDue > 3) return CollectionStatus.upToDate;
    return CollectionStatus.pendingBalance;
  }

  String _priority({
    required String status,
    required double totalPendingAmount,
    required String? riskLevel,
    required int? daysToDue,
  }) {
    final highDebt = totalPendingAmount >= 10000;
    final mediumDebt = totalPendingAmount >= 3000;
    final highRisk = riskLevel == ClientRiskLevel.high;
    final mediumRisk = riskLevel == ClientRiskLevel.medium;

    if (status == CollectionStatus.blocked60 ||
        (status == CollectionStatus.overdue45 && (highDebt || highRisk)) ||
        (highRisk && (daysToDue ?? 1) < 0)) {
      return CollectionPriority.critical;
    }
    if (status == CollectionStatus.overdue45 ||
        status == CollectionStatus.overdue30 ||
        daysToDue == 0 ||
        daysToDue == 1 ||
        highDebt) {
      return CollectionPriority.high;
    }
    if (status == CollectionStatus.dueSoon || mediumRisk || mediumDebt) {
      return CollectionPriority.medium;
    }
    return CollectionPriority.low;
  }

  String _recommendedAction(String status, String priority) {
    if (status == CollectionStatus.blocked60) {
      return 'No fiar mas sin autorizacion';
    }
    if (status == CollectionStatus.overdue45) return 'Llamar al cliente';
    if (status == CollectionStatus.overdue30) return 'Dar seguimiento hoy';
    if (status == CollectionStatus.dueSoon) {
      return 'Enviar recordatorio amable';
    }
    if (priority == CollectionPriority.high ||
        priority == CollectionPriority.critical) {
      return 'Dar seguimiento hoy';
    }
    return 'Cliente al dia, sin accion urgente';
  }

  int _daysBetween(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return end.difference(start).inDays;
  }

  int _comparePriority(CollectionInsight a, CollectionInsight b) {
    final priority = {
      CollectionPriority.critical: 0,
      CollectionPriority.high: 1,
      CollectionPriority.medium: 2,
      CollectionPriority.low: 3,
    };
    final first = priority[a.priorityLevel] ?? 9;
    final second = priority[b.priorityLevel] ?? 9;
    if (first != second) return first.compareTo(second);
    final dueA = a.daysToDue ?? 9999;
    final dueB = b.daysToDue ?? 9999;
    if (dueA != dueB) return dueA.compareTo(dueB);
    return b.totalPendingAmount.compareTo(a.totalPendingAmount);
  }
}
