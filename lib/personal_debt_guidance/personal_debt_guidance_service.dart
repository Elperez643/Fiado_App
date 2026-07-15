import '../core/database/database_helper.dart';
import '../core/database/database_schema.dart';
import '../data/models/credito_ciclo_sqlite_model.dart';
import '../data/models/usuario_sqlite_model.dart';
import '../data/repositories/credito_ciclo_repository.dart';
import 'personal_debt_reminder.dart';

class PersonalDebtGuidanceService {
  final DatabaseHelper databaseHelper;
  final CreditoCicloRepository creditoCicloRepository;

  const PersonalDebtGuidanceService({
    required this.databaseHelper,
    required this.creditoCicloRepository,
  });

  Future<List<PersonalDebtReminder>> getRemindersForPersonal({
    required String phone,
  }) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) return const <PersonalDebtReminder>[];

    final db = await databaseHelper.database;
    final businessRows = await db.rawQuery(
      '''
SELECT DISTINCT cc.negocio_id
FROM ${DatabaseSchema.creditoCiclosTable} cc
INNER JOIN ${DatabaseSchema.clientesTable} c ON c.id = cc.cliente_id
WHERE c.telefono = ?
  AND c.is_active = 1
  AND cc.saldo_pendiente > 0
  AND cc.estado != ?
''',
      [normalizedPhone, CreditoCicloEstado.saldado],
    );

    for (final row in businessRows) {
      final businessId = (row['negocio_id'] as num?)?.toInt();
      if (businessId != null) {
        await creditoCicloRepository.actualizarEstadosPorFecha(businessId);
      }
    }

    final rows = await db.rawQuery(
      '''
SELECT cc.*, c.nombre AS cliente_nombre, c.telefono AS cliente_telefono,
       u.nombre AS negocio_nombre
FROM ${DatabaseSchema.creditoCiclosTable} cc
INNER JOIN ${DatabaseSchema.clientesTable} c ON c.id = cc.cliente_id
INNER JOIN ${DatabaseSchema.usuariosTable} u ON u.id = cc.negocio_id
WHERE c.telefono = ?
  AND c.is_active = 1
  AND u.tipo_usuario = ?
  AND cc.saldo_pendiente > 0
  AND cc.estado != ?
ORDER BY cc.negocio_id ASC, cc.fecha_inicio ASC
''',
      [
        normalizedPhone,
        UsuarioSqliteModel.tipoNegocio,
        CreditoCicloEstado.saldado,
      ],
    );

    final cycles = rows.map(CreditoCicloSqliteModel.fromMap).toList();
    final grouped = <int, List<CreditoCicloSqliteModel>>{};
    for (final cycle in cycles) {
      grouped.putIfAbsent(cycle.negocioId, () => []).add(cycle);
    }

    final reminders = <PersonalDebtReminder>[];
    for (final entry in grouped.entries) {
      final cycles = entry.value;
      final businessId = entry.key;
      final businessName = cycles.first.negocioNombre ?? 'Negocio';
      final lastPaymentDate = await _lastPaymentDate(
        businessId: businessId,
        phone: normalizedPhone,
      );
      reminders.add(
        _buildReminder(
          businessId: businessId,
          businessName: businessName,
          phone: normalizedPhone,
          cycles: cycles,
          lastPaymentDate: lastPaymentDate,
        ),
      );
    }

    reminders.sort((a, b) {
      final priority =
          _priorityWeight(b.priority) - _priorityWeight(a.priority);
      if (priority != 0) return priority;
      return b.totalPendingAmount.compareTo(a.totalPendingAmount);
    });
    return reminders;
  }

  Future<PersonalDebtReminderDetailData> getReminderDetail(
    PersonalDebtReminder reminder,
  ) async {
    final db = await databaseHelper.database;
    final movementsRows = await db.rawQuery(
      '''
SELECT tipo, monto, fecha, concepto
FROM ${DatabaseSchema.movimientosTable}
WHERE negocio_id = ?
  AND cliente_telefono = ?
  AND is_active = 1
ORDER BY fecha DESC
LIMIT 20
''',
      [reminder.businessId, reminder.clientPhone],
    );
    final receiptRows = await db.rawQuery(
      '''
SELECT codigo_comprobante, tipo, total, fecha
FROM ${DatabaseSchema.comprobantesTable}
WHERE negocio_id = ?
  AND cliente_telefono = ?
ORDER BY fecha DESC
LIMIT 20
''',
      [reminder.businessId, reminder.clientPhone],
    );

    return PersonalDebtReminderDetailData(
      reminder: reminder,
      recentMovements: movementsRows
          .map(
            (row) => PersonalDebtMovementSummary(
              type: row['tipo'] as String? ?? 'movimiento',
              amount: (row['monto'] as num? ?? 0).toDouble(),
              date: _parseDate(row['fecha']) ?? DateTime.now(),
              concept: row['concepto'] as String?,
            ),
          )
          .toList(),
      receipts: receiptRows
          .map(
            (row) => PersonalDebtReceiptSummary(
              code: row['codigo_comprobante'] as String? ?? 'Sin codigo',
              type: row['tipo'] as String? ?? 'comprobante',
              total: (row['total'] as num? ?? 0).toDouble(),
              date: _parseDate(row['fecha']) ?? DateTime.now(),
            ),
          )
          .toList(),
      nextSteps: _nextSteps(reminder),
    );
  }

  PersonalDebtReminder _buildReminder({
    required int businessId,
    required String businessName,
    required String phone,
    required List<CreditoCicloSqliteModel> cycles,
    required DateTime? lastPaymentDate,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pending = cycles.fold<double>(
      0,
      (total, cycle) => total + cycle.saldoPendiente,
    );
    final oldest = cycles
        .map((cycle) => cycle.fechaInicio)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final nextDue = cycles
        .map((cycle) => cycle.fechaLimite30)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final daysSinceOldest = today.difference(_dateOnly(oldest)).inDays;
    final daysToDue = _dateOnly(nextDue).difference(today).inDays;
    final daysOverdue = daysToDue < 0 ? daysToDue.abs() : 0;
    final status = _statusFor(cycles, daysToDue);
    final priority = _priorityFor(status, daysToDue, daysOverdue);

    return PersonalDebtReminder(
      businessId: businessId,
      businessName: businessName,
      clientPhone: phone,
      totalPendingAmount: pending,
      oldestDebtDate: oldest,
      daysSinceOldestDebt: daysSinceOldest,
      nextDueDate: nextDue,
      daysToDue: daysToDue,
      daysOverdue: daysOverdue,
      status: status,
      priority: priority,
      recommendation: _recommendation(status, daysToDue),
      scoreImpactAdvice: _scoreAdvice(status),
      lastPaymentDate: lastPaymentDate,
      lastUpdatedAt: now,
    );
  }

  Future<DateTime?> _lastPaymentDate({
    required int businessId,
    required String phone,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.movimientosTable,
      columns: ['fecha'],
      where:
          'negocio_id = ? AND cliente_telefono = ? AND tipo = ? AND is_active = 1',
      whereArgs: [businessId, phone, 'pago'],
      orderBy: 'fecha DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _parseDate(rows.first['fecha']);
  }

  String _statusFor(List<CreditoCicloSqliteModel> cycles, int daysToDue) {
    if (cycles.any((cycle) => cycle.estado == CreditoCicloEstado.bloqueado60)) {
      return PersonalDebtStatus.bloqueado60;
    }
    if (cycles.any((cycle) => cycle.estado == CreditoCicloEstado.mora45)) {
      return PersonalDebtStatus.mora45;
    }
    if (cycles.any((cycle) => cycle.estado == CreditoCicloEstado.vencido30)) {
      return PersonalDebtStatus.vencido30;
    }
    if (daysToDue >= 0 && daysToDue <= 5) {
      return PersonalDebtStatus.porVencer;
    }
    return PersonalDebtStatus.alDia;
  }

  String _priorityFor(String status, int daysToDue, int daysOverdue) {
    if (status == PersonalDebtStatus.bloqueado60) {
      return PersonalDebtPriority.critica;
    }
    if (status == PersonalDebtStatus.mora45) {
      return PersonalDebtPriority.alta;
    }
    if (status == PersonalDebtStatus.vencido30 || daysOverdue > 0) {
      return PersonalDebtPriority.alta;
    }
    if (daysToDue >= 0 && daysToDue <= 2) {
      return PersonalDebtPriority.alta;
    }
    if (daysToDue >= 0 && daysToDue <= 5) {
      return PersonalDebtPriority.media;
    }
    return PersonalDebtPriority.baja;
  }

  String _recommendation(String status, int daysToDue) {
    return switch (status) {
      PersonalDebtStatus.bloqueado60 =>
        'Fiado App recomienda acordar un pago o abono para recuperar confianza con este negocio.',
      PersonalDebtStatus.mora45 =>
        'Fiado App recomienda priorizar esta deuda y hacer un abono tan pronto sea posible.',
      PersonalDebtStatus.vencido30 =>
        'Fiado App recomienda revisar esta deuda hoy y evitar que siga avanzando.',
      PersonalDebtStatus.porVencer =>
        'Fiado App recomienda preparar el pago antes del vencimiento para mantener buen historial.',
      _ when daysToDue > 5 =>
        'Fiado App recomienda planificar este pago con tiempo y guardar tus comprobantes.',
      _ =>
        'Fiado App recomienda mantener este saldo visible dentro de tu presupuesto.',
    };
  }

  String _scoreAdvice(String status) {
    return switch (status) {
      PersonalDebtStatus.bloqueado60 =>
        'Resolver esta deuda puede ayudar a recuperar una mejor relacion de credito con el negocio.',
      PersonalDebtStatus.mora45 =>
        'Un abono o pago completo puede mejorar tu historial visible con este negocio.',
      PersonalDebtStatus.vencido30 =>
        'Pagar o abonar pronto ayuda a cuidar tu historial de cumplimiento.',
      PersonalDebtStatus.porVencer =>
        'Pagar antes de la fecha limite ayuda a mantener una lectura positiva de cumplimiento.',
      _ =>
        'Mantener pagos ordenados ayuda a sostener buenas recomendaciones futuras.',
    };
  }

  List<String> _nextSteps(PersonalDebtReminder reminder) {
    final steps = <String>[
      'Revisa el monto pendiente y la fecha limite mas cercana.',
      'Guarda cualquier comprobante de pago que recibas.',
    ];
    if (reminder.priority == PersonalDebtPriority.critica ||
        reminder.priority == PersonalDebtPriority.alta) {
      steps.insert(1, 'Prioriza un abono parcial o pago completo esta semana.');
    } else {
      steps.insert(
        1,
        'Reserva el pago dentro de tu presupuesto antes de vencer.',
      );
    }
    return steps;
  }

  static int _priorityWeight(String priority) {
    return switch (priority) {
      PersonalDebtPriority.critica => 4,
      PersonalDebtPriority.alta => 3,
      PersonalDebtPriority.media => 2,
      _ => 1,
    };
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
