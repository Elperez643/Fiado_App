class PersonalDebtStatus {
  static const alDia = 'al_dia';
  static const porVencer = 'por_vencer';
  static const vencido30 = 'vencido_30';
  static const mora45 = 'mora_45';
  static const bloqueado60 = 'bloqueado_60';
  static const saldoPendiente = 'saldo_pendiente';
}

class PersonalDebtPriority {
  static const baja = 'baja';
  static const media = 'media';
  static const alta = 'alta';
  static const critica = 'critica';
}

class PersonalDebtReminder {
  final int businessId;
  final String businessName;
  final String clientPhone;
  final double totalPendingAmount;
  final DateTime? oldestDebtDate;
  final int? daysSinceOldestDebt;
  final DateTime? nextDueDate;
  final int? daysToDue;
  final int? daysOverdue;
  final String status;
  final String priority;
  final String recommendation;
  final String scoreImpactAdvice;
  final DateTime? lastPaymentDate;
  final DateTime lastUpdatedAt;

  const PersonalDebtReminder({
    required this.businessId,
    required this.businessName,
    required this.clientPhone,
    required this.totalPendingAmount,
    required this.oldestDebtDate,
    required this.daysSinceOldestDebt,
    required this.nextDueDate,
    required this.daysToDue,
    required this.daysOverdue,
    required this.status,
    required this.priority,
    required this.recommendation,
    required this.scoreImpactAdvice,
    required this.lastPaymentDate,
    required this.lastUpdatedAt,
  });

  String get statusLabel {
    return switch (status) {
      PersonalDebtStatus.alDia => 'Al dia',
      PersonalDebtStatus.porVencer => 'Por vencer',
      PersonalDebtStatus.vencido30 => 'Vencido 30',
      PersonalDebtStatus.mora45 => 'Mora 45',
      PersonalDebtStatus.bloqueado60 => 'Bloqueo 60',
      _ => 'Saldo pendiente',
    };
  }

  String get priorityLabel {
    return switch (priority) {
      PersonalDebtPriority.critica => 'Critica',
      PersonalDebtPriority.alta => 'Alta',
      PersonalDebtPriority.media => 'Media',
      _ => 'Baja',
    };
  }
}

class PersonalDebtReminderDetailData {
  final PersonalDebtReminder reminder;
  final List<PersonalDebtMovementSummary> recentMovements;
  final List<PersonalDebtReceiptSummary> receipts;
  final List<String> nextSteps;

  const PersonalDebtReminderDetailData({
    required this.reminder,
    required this.recentMovements,
    required this.receipts,
    required this.nextSteps,
  });
}

class PersonalDebtMovementSummary {
  final String type;
  final double amount;
  final DateTime date;
  final String? concept;

  const PersonalDebtMovementSummary({
    required this.type,
    required this.amount,
    required this.date,
    this.concept,
  });
}

class PersonalDebtReceiptSummary {
  final String code;
  final String type;
  final double total;
  final DateTime date;

  const PersonalDebtReceiptSummary({
    required this.code,
    required this.type,
    required this.total,
    required this.date,
  });
}
