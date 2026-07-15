class ClientRiskLevel {
  static const low = 'Bajo riesgo';
  static const medium = 'Riesgo medio';
  static const high = 'Riesgo alto';
}

class ClientScore {
  final int? clientId;
  final int businessId;
  final String clientName;
  final String clientPhone;
  final int score;
  final String riskLevel;
  final double suggestedCreditLimit;
  final double paymentCompliancePercent;
  final double totalCredits;
  final double totalPayments;
  final int overdue30Count;
  final int overdue45Count;
  final int blocked60Count;
  final DateTime lastCalculatedAt;
  final List<String> reasons;

  const ClientScore({
    required this.clientId,
    required this.businessId,
    required this.clientName,
    required this.clientPhone,
    required this.score,
    required this.riskLevel,
    required this.suggestedCreditLimit,
    required this.paymentCompliancePercent,
    required this.totalCredits,
    required this.totalPayments,
    required this.overdue30Count,
    required this.overdue45Count,
    required this.blocked60Count,
    required this.lastCalculatedAt,
    required this.reasons,
  });
}

class BusinessClientScoreReport {
  final List<ClientScore> bestClients;
  final List<ClientScore> riskyClients;

  const BusinessClientScoreReport({
    required this.bestClients,
    required this.riskyClients,
  });
}
