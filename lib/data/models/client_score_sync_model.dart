import 'dart:convert';

import '../../core/sync/sync_status.dart';
import '../../credit_scoring/client_score.dart';

class ClientScoreSyncModel {
  final int? id;
  final String? remoteId;
  final int negocioId;
  final int clienteId;
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
  final DateTime lastCalculatedAt;
  final DateTime? deletedAt;
  final DateTime? lastSyncedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  const ClientScoreSyncModel({
    this.id,
    this.remoteId,
    required this.negocioId,
    required this.clienteId,
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
    required this.lastCalculatedAt,
    this.deletedAt,
    this.lastSyncedAt,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  factory ClientScoreSyncModel.fromScore(
    ClientScore score, {
    required int clienteId,
    int? id,
    String? remoteId,
    String syncStatus = SyncStatus.pending,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
  }) {
    final now = DateTime.now();
    return ClientScoreSyncModel(
      id: id,
      remoteId: remoteId,
      negocioId: score.businessId,
      clienteId: clienteId,
      score: score.score,
      riskLevel: score.riskLevel,
      suggestedCreditLimit: score.suggestedCreditLimit,
      paymentCompliancePercent: score.paymentCompliancePercent,
      totalCredits: score.totalCredits,
      totalPayments: score.totalPayments,
      overdue30Count: score.overdue30Count,
      overdue45Count: score.overdue45Count,
      blocked60Count: score.blocked60Count,
      reasons: score.reasons,
      lastCalculatedAt: score.lastCalculatedAt,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      lastSyncedAt: lastSyncedAt,
      syncStatus: syncStatus,
    );
  }

  factory ClientScoreSyncModel.fromMap(Map<String, Object?> map) {
    DateTime parseDate(Object? value, DateTime fallback) {
      final text = value?.toString();
      return text == null ? fallback : DateTime.tryParse(text) ?? fallback;
    }

    DateTime? parseNullableDate(Object? value) {
      final text = value?.toString();
      return text == null || text.isEmpty ? null : DateTime.tryParse(text);
    }

    List<String> parseReasons(Object? value) {
      final text = value?.toString();
      if (text == null || text.isEmpty) return const <String>[];
      final decoded = jsonDecode(text);
      return (decoded as List<dynamic>).map((item) => '$item').toList();
    }

    final now = DateTime.now();
    return ClientScoreSyncModel(
      id: (map['id'] as num?)?.toInt(),
      remoteId: map['remote_id'] as String?,
      negocioId: (map['negocio_id'] as num).toInt(),
      clienteId: (map['cliente_id'] as num).toInt(),
      score: (map['score'] as num? ?? 0).toInt(),
      riskLevel: map['risk_level'] as String? ?? ClientRiskLevel.medium,
      suggestedCreditLimit: (map['suggested_credit_limit'] as num? ?? 0)
          .toDouble(),
      paymentCompliancePercent: (map['payment_compliance_percent'] as num? ?? 0)
          .toDouble(),
      totalCredits: (map['total_credits'] as num? ?? 0).toDouble(),
      totalPayments: (map['total_payments'] as num? ?? 0).toDouble(),
      overdue30Count: (map['overdue_30_count'] as num? ?? 0).toInt(),
      overdue45Count: (map['overdue_45_count'] as num? ?? 0).toInt(),
      blocked60Count: (map['blocked_60_count'] as num? ?? 0).toInt(),
      reasons: parseReasons(map['reasons_json']),
      lastCalculatedAt: parseDate(map['last_calculated_at'], now),
      deletedAt: parseNullableDate(map['deleted_at']),
      lastSyncedAt: parseNullableDate(map['last_synced_at']),
      createdAt: parseDate(map['created_at'], now),
      updatedAt: parseDate(map['updated_at'], now),
      syncStatus: map['sync_status'] as String? ?? SyncStatus.pending,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'remote_id': remoteId,
      'negocio_id': negocioId,
      'cliente_id': clienteId,
      'score': score,
      'risk_level': riskLevel,
      'suggested_credit_limit': suggestedCreditLimit,
      'payment_compliance_percent': paymentCompliancePercent,
      'total_credits': totalCredits,
      'total_payments': totalPayments,
      'overdue_30_count': overdue30Count,
      'overdue_45_count': overdue45Count,
      'blocked_60_count': blocked60Count,
      'reasons_json': jsonEncode(reasons),
      'last_calculated_at': lastCalculatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  ClientScore toScore({
    required String clientName,
    required String clientPhone,
  }) {
    return ClientScore(
      clientId: clienteId,
      businessId: negocioId,
      clientName: clientName,
      clientPhone: clientPhone,
      score: score,
      riskLevel: riskLevel,
      suggestedCreditLimit: suggestedCreditLimit,
      paymentCompliancePercent: paymentCompliancePercent,
      totalCredits: totalCredits,
      totalPayments: totalPayments,
      overdue30Count: overdue30Count,
      overdue45Count: overdue45Count,
      blocked60Count: blocked60Count,
      lastCalculatedAt: lastCalculatedAt,
      reasons: reasons,
    );
  }
}
