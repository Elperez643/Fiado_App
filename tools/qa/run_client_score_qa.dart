import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

Future<void> main(List<String> args) async {
  final output = _stringOption(args, 'output', 'qa_data/client_score_qa.db');
  _guardQaPath(output);

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final file = File(output);
  await file.parent.create(recursive: true);
  if (await file.exists()) await file.delete();

  final db = await databaseFactory.openDatabase(file.absolute.path);
  try {
    await _createSchema(db);
    await _seed(db);

    final scenarios = await _loadScenarios(db);
    final results = <_ScoreResult>[];
    for (final scenario in scenarios) {
      final result = await _calculate(db, scenario);
      await _saveSnapshot(db, result);
      results.add(result);
    }

    stdout.writeln('CLIENT_SCORE_QA_RESULTS');
    stdout.writeln('cliente,score,riesgo,limite_sugerido,motivos_principales');
    for (final result in results) {
      stdout.writeln(
        [
          result.clientName,
          result.score,
          result.riskLevel,
          result.suggestedCreditLimit.toStringAsFixed(2),
          result.reasons.take(3).join(' | '),
        ].join(','),
      );
    }

    final top = [...results]..sort((a, b) => b.score.compareTo(a.score));
    final risk = [...results]..sort((a, b) => a.score.compareTo(b.score));
    final clientScoreRows = _firstInt(
      await db.rawQuery(
        'SELECT COUNT(*) AS total FROM ${DatabaseSchema.clientScoresTable}',
      ),
    );
    final queueRows = _firstInt(
      await db.rawQuery(
        'SELECT COUNT(*) AS total FROM ${DatabaseSchema.syncQueueTable} '
        'WHERE entity_type = ? AND status = ?',
        [DatabaseSchema.clientScoresTable, 'pending'],
      ),
    );

    stdout.writeln('');
    stdout.writeln('top_best: ${top.map((item) => item.caseId).join(' > ')}');
    stdout.writeln('top_risk: ${risk.map((item) => item.caseId).join(' > ')}');
    stdout.writeln('client_scores_rows: $clientScoreRows');
    stdout.writeln('sync_queue_pending_client_scores: $queueRows');
    stdout.writeln('database: ${file.absolute.path}');

    _assert(
      results.firstWhere((r) => r.caseId == 'A').score >= 70,
      'Caso A debe quedar en score alto.',
    );
    _assert(
      results.firstWhere((r) => r.caseId == 'A').riskLevel == 'Bajo riesgo',
      'Caso A debe ser bajo riesgo.',
    );
    _assert(
      results.firstWhere((r) => r.caseId == 'B').riskLevel == 'Riesgo medio',
      'Caso B debe ser riesgo medio.',
    );
    _assert(
      results.firstWhere((r) => r.caseId == 'D').riskLevel == 'Riesgo alto',
      'Caso D debe ser riesgo alto.',
    );
    _assert(
      results.firstWhere((r) => r.caseId == 'D').suggestedCreditLimit <= 250,
      'Caso D debe tener limite sugerido muy bajo.',
    );
    _assert(clientScoreRows == 5, 'Deben persistirse 5 scores.');
    _assert(queueRows == 5, 'Deben encolarse 5 scores.');
  } finally {
    await db.close();
  }
}

Future<void> _createSchema(Database db) async {
  final statements = <String>[
    DatabaseSchema.createUsuariosTable,
    DatabaseSchema.createSesionesTable,
    DatabaseSchema.createSubscriptionsTable,
    DatabaseSchema.createClientesTable,
    DatabaseSchema.createProductosTable,
    DatabaseSchema.createProductoImagenesTable,
    DatabaseSchema.createInventoryProductMetricsTable,
    DatabaseSchema.createBusinessRecommendationsCacheTable,
    DatabaseSchema.createMovimientosTable,
    DatabaseSchema.createPagosTable,
    DatabaseSchema.createDeudaItemsTable,
    DatabaseSchema.createComprobantesTable,
    DatabaseSchema.createCreditoCiclosTable,
    DatabaseSchema.createCreditoCicloMovimientosTable,
    DatabaseSchema.createCreditoRecordatoriosTable,
    DatabaseSchema.createCreditoExcepcionesTable,
    DatabaseSchema.createSolicitudesAutorizacionTable,
    DatabaseSchema.createAuditoriasTable,
    DatabaseSchema.createAuditoriaItemsTable,
    DatabaseSchema.createClientScoresTable,
    DatabaseSchema.createUserOnboardingTable,
    DatabaseSchema.createSyncQueueTable,
    ...DatabaseSchema.initialIndexes,
  ];
  for (final statement in statements) {
    await db.execute(statement);
  }
}

Future<void> _seed(Database db) async {
  final now = DateTime.now();
  final isoNow = now.toIso8601String();
  await db.insert(DatabaseSchema.usuariosTable, {
    'id': 1,
    'remote_id': 'qa-score-business',
    'nombre': 'QA Score Business',
    'telefono': '8097000000',
    'tipo_usuario': 'negocio',
    'password_hash': 'qa-only',
    'activo': 1,
    'created_at': isoNow,
    'updated_at': isoNow,
    'sync_status': 'synced',
  });

  final cases = <({String id, int clientId, String name, String phone})>[
    (id: 'A', clientId: 1, name: 'Caso A Excelente', phone: '8097000001'),
    (id: 'B', clientId: 2, name: 'Caso B Regular', phone: '8097000002'),
    (id: 'C', clientId: 3, name: 'Caso C Mora', phone: '8097000003'),
    (id: 'D', clientId: 4, name: 'Caso D Bloqueado', phone: '8097000004'),
    (id: 'E', clientId: 5, name: 'Caso E Nuevo', phone: '8097000005'),
  ];

  for (final item in cases) {
    await db.insert(DatabaseSchema.clientesTable, {
      'id': item.clientId,
      'negocio_id': 1,
      'nombre': item.name,
      'telefono': item.phone,
      'deuda': item.id == 'D' ? 1500.0 : 0.0,
      'is_active': 1,
      'created_at': isoNow,
      'updated_at': isoNow,
      'sync_status': 'synced',
      'remote_id': 'qa-score-client-${item.id}',
    });
  }

  var movementId = 1;
  var cycleId = 1;

  Future<void> addMovement(
    int clientId,
    String type,
    double amount,
    int daysAgo,
  ) async {
    final date = now.subtract(Duration(days: daysAgo)).toIso8601String();
    final client = cases.firstWhere((item) => item.clientId == clientId);
    await db.insert(DatabaseSchema.movimientosTable, {
      'id': movementId++,
      'negocio_id': 1,
      'cliente_nombre': client.name,
      'cliente_telefono': client.phone,
      'tipo': type,
      'monto': amount,
      'concepto': type == 'pago' ? 'Pago QA' : 'Deuda QA',
      'fecha': date,
      'created_at': date,
      'updated_at': date,
      'is_active': 1,
      'sync_status': 'synced',
      'remote_id': 'qa-score-movement-${movementId - 1}',
    });
  }

  Future<void> addCycle({
    required int clientId,
    required String status,
    required double total,
    required double paid,
    required int startDaysAgo,
    int? settledDaysAfterStart,
    bool blocked = false,
  }) async {
    final start = now.subtract(Duration(days: startDaysAgo));
    await db.insert(DatabaseSchema.creditoCiclosTable, {
      'id': cycleId++,
      'remote_id': 'qa-score-cycle-${cycleId - 1}',
      'negocio_id': 1,
      'cliente_id': clientId,
      'fecha_inicio': start.toIso8601String(),
      'fecha_limite_30': start.add(const Duration(days: 30)).toIso8601String(),
      'fecha_limite_45': start.add(const Duration(days: 45)).toIso8601String(),
      'fecha_bloqueo_60': start.add(const Duration(days: 60)).toIso8601String(),
      'estado': status,
      'monto_total': total,
      'monto_pagado': paid,
      'saldo_pendiente': total - paid,
      'bloqueado': blocked ? 1 : 0,
      'fecha_saldado': settledDaysAfterStart == null
          ? null
          : start.add(Duration(days: settledDaysAfterStart)).toIso8601String(),
      'created_at': start.toIso8601String(),
      'updated_at': isoNow,
      'sync_status': 'synced',
    });
  }

  for (var i = 0; i < 4; i++) {
    await addMovement(1, 'deuda', 1000.0, 180 - (i * 20));
    await addMovement(1, 'pago', 1000.0, 170 - (i * 20));
    await addCycle(
      clientId: 1,
      status: 'saldado',
      total: 1000.0,
      paid: 1000.0,
      startDaysAgo: 180 - (i * 20),
      settledDaysAfterStart: 10,
    );
  }

  await addMovement(2, 'deuda', 1000.0, 100);
  await addMovement(2, 'pago', 450.0, 62);
  await addMovement(2, 'deuda', 800.0, 55);
  await addMovement(2, 'pago', 300.0, 18);
  await addCycle(
    clientId: 2,
    status: 'saldado',
    total: 1000.0,
    paid: 1000.0,
    startDaysAgo: 100,
    settledDaysAfterStart: 38,
  );
  await addCycle(
    clientId: 2,
    status: 'activo',
    total: 800.0,
    paid: 300.0,
    startDaysAgo: 55,
  );

  await addMovement(3, 'deuda', 1500.0, 80);
  await addMovement(3, 'pago', 300.0, 20);
  await addCycle(
    clientId: 3,
    status: 'vencido_30',
    total: 700.0,
    paid: 100.0,
    startDaysAgo: 35,
  );
  await addCycle(
    clientId: 3,
    status: 'mora_45',
    total: 800.0,
    paid: 200.0,
    startDaysAgo: 50,
  );

  await addMovement(4, 'deuda', 2000.0, 90);
  await addMovement(4, 'pago', 100.0, 40);
  await addCycle(
    clientId: 4,
    status: 'bloqueado_60',
    total: 2000.0,
    paid: 100.0,
    startDaysAgo: 70,
    blocked: true,
  );
}

Future<List<_Scenario>> _loadScenarios(Database db) async {
  final rows = await db.query(
    DatabaseSchema.clientesTable,
    where: 'negocio_id = ?',
    whereArgs: [1],
    orderBy: 'id ASC',
  );
  return rows.map(_Scenario.fromMap).toList();
}

Future<_ScoreResult> _calculate(Database db, _Scenario scenario) async {
  final movements = await db.query(
    DatabaseSchema.movimientosTable,
    where: 'negocio_id = ? AND cliente_telefono = ?',
    whereArgs: [scenario.businessId, scenario.phone],
    orderBy: 'fecha DESC',
    limit: 1000,
  );
  final cycles = await db.query(
    DatabaseSchema.creditoCiclosTable,
    where: 'negocio_id = ? AND cliente_id = ?',
    whereArgs: [scenario.businessId, scenario.clientId],
  );

  double amountSum(String type) => movements
      .where((row) => row['tipo'] == type)
      .fold<double>(
        0,
        (sum, row) => sum + ((row['monto'] as num?)?.toDouble() ?? 0),
      );
  final totalCredits = amountSum('deuda');
  final totalPayments = amountSum('pago');
  final creditCount = movements.where((row) => row['tipo'] == 'deuda').length;
  final paymentCount = movements.where((row) => row['tipo'] == 'pago').length;
  final completedCycles = cycles
      .where((row) => row['estado'] == 'saldado')
      .length;
  final overdue30 = cycles.where((row) => row['estado'] == 'vencido_30').length;
  final overdue45 = cycles.where((row) => row['estado'] == 'mora_45').length;
  final blocked60 = cycles
      .where(
        (row) =>
            row['estado'] == 'bloqueado_60' ||
            ((row['bloqueado'] as num?)?.toInt() ?? 0) == 1,
      )
      .length;
  final paidBefore30 = cycles.where((row) => _settledWithin(row, 0, 30)).length;
  final paid30To45 = cycles.where((row) => _settledWithin(row, 31, 45)).length;
  final paid45To60 = cycles.where((row) => _settledWithin(row, 46, 60)).length;
  final compliance = totalCredits <= 0
      ? 100.0
      : ((totalPayments / totalCredits) * 100).clamp(0, 100).toDouble();
  final oldestMovement = movements.isEmpty
      ? DateTime.now()
      : movements
            .map((row) => DateTime.parse(row['fecha'] as String))
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
      ? 'Bajo riesgo'
      : score >= 40
      ? 'Riesgo medio'
      : 'Riesgo alto';
  final averageCredit = creditCount == 0 ? 0 : totalCredits / creditCount;
  final paidHistoryFactor = totalPayments <= 0 ? 0.6 : 1.0;
  final baseSuggestedLimit =
      averageCredit * (0.8 + score / 100) * paidHistoryFactor;
  final riskCap = blocked60 > 0
      ? averageCredit * 0.1
      : overdue45 > 0
      ? averageCredit * 0.25
      : overdue30 > 0
      ? averageCredit * 0.4
      : riskLevel == 'Riesgo alto'
      ? averageCredit * 0.3
      : totalPayments + averageCredit;
  final suggestedLimit = _roundMoney(baseSuggestedLimit.clamp(0, riskCap));

  return _ScoreResult(
    caseId: scenario.caseId,
    clientId: scenario.clientId,
    businessId: scenario.businessId,
    clientName: scenario.name,
    score: score,
    riskLevel: riskLevel,
    suggestedCreditLimit: suggestedLimit,
    paymentCompliancePercent: compliance,
    totalCredits: totalCredits,
    totalPayments: totalPayments,
    overdue30Count: overdue30,
    overdue45Count: overdue45,
    blocked60Count: blocked60,
    reasons: _reasons(
      paidBefore30: paidBefore30,
      paid30To45: paid30To45,
      paid45To60: paid45To60,
      overdue30: overdue30,
      overdue45: overdue45,
      blocked60: blocked60,
      compliance: compliance,
      ageDays: ageDays,
      totalCredits: totalCredits,
      totalPayments: totalPayments,
    ),
  );
}

Future<void> _saveSnapshot(Database db, _ScoreResult result) async {
  final now = DateTime.now().toIso8601String();
  final id = await db.insert(DatabaseSchema.clientScoresTable, {
    'negocio_id': result.businessId,
    'cliente_id': result.clientId,
    'score': result.score,
    'risk_level': result.riskLevel,
    'suggested_credit_limit': result.suggestedCreditLimit,
    'payment_compliance_percent': result.paymentCompliancePercent,
    'total_credits': result.totalCredits,
    'total_payments': result.totalPayments,
    'overdue_30_count': result.overdue30Count,
    'overdue_45_count': result.overdue45Count,
    'blocked_60_count': result.blocked60Count,
    'reasons_json': jsonEncode(result.reasons),
    'last_calculated_at': now,
    'created_at': now,
    'updated_at': now,
    'sync_status': 'pending',
  });
  await db.insert(DatabaseSchema.syncQueueTable, {
    'entity_type': DatabaseSchema.clientScoresTable,
    'entity_id': id,
    'operation': 'create',
    'payload': jsonEncode({'id': id, 'cliente_id': result.clientId}),
    'status': 'pending',
    'attempts': 0,
    'created_at': now,
    'updated_at': now,
  });
}

bool _settledWithin(Map<String, Object?> row, int minDays, int maxDays) {
  final settledText = row['fecha_saldado'] as String?;
  if (settledText == null) return false;
  final start = DateTime.parse(row['fecha_inicio'] as String);
  final settled = DateTime.parse(settledText);
  final days = settled.difference(start).inDays;
  return days >= minDays && days <= maxDays;
}

List<String> _reasons({
  required int paidBefore30,
  required int paid30To45,
  required int paid45To60,
  required int overdue30,
  required int overdue45,
  required int blocked60,
  required double compliance,
  required int ageDays,
  required double totalCredits,
  required double totalPayments,
}) {
  final reasons = <String>[];
  if (paidBefore30 > 0) reasons.add('Pagos antes de 30 dias: $paidBefore30.');
  if (paid30To45 > 0) reasons.add('Pagos entre 30 y 45 dias: $paid30To45.');
  if (paid45To60 > 0) reasons.add('Pagos entre 45 y 60 dias: $paid45To60.');
  if (overdue30 > 0) reasons.add('Ciclos vencidos a 30 dias: $overdue30.');
  if (overdue45 > 0) reasons.add('Ciclos en mora 45 dias: $overdue45.');
  if (blocked60 > 0) reasons.add('Bloqueos 60 dias detectados: $blocked60.');
  reasons.add('Cumplimiento de pago: ${compliance.toStringAsFixed(1)}%.');
  if (ageDays >= 60) reasons.add('Antiguedad registrada: $ageDays dias.');
  if (totalCredits <= 0) {
    reasons.add('Sin historial de creditos; recomendacion conservadora.');
  } else {
    reasons.add(
      'Historial: RD\$${totalCredits.toStringAsFixed(2)} fiado y RD\$${totalPayments.toStringAsFixed(2)} pagado.',
    );
  }
  reasons.add(
    'Fiado App recomienda revisar este score junto al contexto del negocio.',
  );
  return reasons;
}

double _roundMoney(num value) => ((value * 100).round()) / 100;

int _firstInt(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) return 0;
  return (rows.first.values.first as num? ?? 0).toInt();
}

String _stringOption(List<String> args, String name, String fallback) {
  final prefix = '--$name=';
  return args
      .firstWhere(
        (arg) => arg.startsWith(prefix),
        orElse: () => prefix + fallback,
      )
      .substring(prefix.length);
}

void _guardQaPath(String output) {
  final normalized = output.replaceAll('\\', '/').toLowerCase();
  if (!normalized.contains('qa_data/') && !normalized.contains('qa_data/')) {
    stderr.writeln('Refusing to write outside qa_data: $output');
    exitCode = 64;
    throw StateError('Output path must be inside qa_data.');
  }
}

void _assert(bool condition, String message) {
  if (!condition) {
    stderr.writeln('QA assertion failed: $message');
    exitCode = 1;
    throw StateError(message);
  }
}

class _Scenario {
  final String caseId;
  final int clientId;
  final int businessId;
  final String name;
  final String phone;

  const _Scenario({
    required this.caseId,
    required this.clientId,
    required this.businessId,
    required this.name,
    required this.phone,
  });

  factory _Scenario.fromMap(Map<String, Object?> map) {
    return _Scenario(
      caseId: (map['nombre'] as String).split(' ')[1],
      clientId: (map['id'] as num).toInt(),
      businessId: (map['negocio_id'] as num).toInt(),
      name: map['nombre'] as String,
      phone: map['telefono'] as String,
    );
  }
}

class _ScoreResult {
  final String caseId;
  final int clientId;
  final int businessId;
  final String clientName;
  final int score;
  final String riskLevel;
  final double suggestedCreditLimit;
  final double paymentCompliancePercent;
  final double totalCredits;
  final double totalPayments;
  final int overdue30Count;
  final int overdue45Count;
  final int blocked60Count;
  final List<String> reasons;

  const _ScoreResult({
    required this.caseId,
    required this.clientId,
    required this.businessId,
    required this.clientName,
    required this.score,
    required this.riskLevel,
    required this.suggestedCreditLimit,
    required this.paymentCompliancePercent,
    required this.totalCredits,
    required this.totalPayments,
    required this.overdue30Count,
    required this.overdue45Count,
    required this.blocked60Count,
    required this.reasons,
  });
}
