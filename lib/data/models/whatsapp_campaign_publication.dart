class WhatsappCampaignPublicationStatus {
  static const pendiente = 'pendiente';
  static const enviadoAWhatsapp = 'enviado_a_whatsapp';
  static const confirmadoPorUsuario = 'confirmado_por_usuario';
  static const canceladoPorUsuario = 'cancelado_por_usuario';
  static const expiradoEstimado = 'expirado_estimado';
  static const fallidoAntesDeAbrirWhatsapp = 'fallido_antes_de_abrir_whatsapp';

  static const usadosDelDia = {
    enviadoAWhatsapp,
    confirmadoPorUsuario,
    canceladoPorUsuario,
  };
}

class WhatsappCampaignStatus {
  static const activo = 'activo';
  static const pausado = 'pausado';
  static const finalizado = 'finalizado';
}

class WhatsappCampaignPublication {
  final String id;
  final int? localId;
  final String? remoteId;
  final int negocioId;
  final String dateKey;
  final String mode;
  final List<String> productIds;
  final List<String> renderedImagePaths;
  final List<String> statusTexts;
  final String status;
  final bool consumesQuota;
  final int quotaUnits;
  final DateTime fechaInicio;
  final int duracionDias;
  final String campaignStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? openedWhatsappAt;
  final DateTime? confirmedByUserAt;
  final DateTime? canceledByUserAt;
  final DateTime? failedAt;
  final DateTime? estimatedExpiresAt;
  final String? error;
  final bool isActive;
  final DateTime? deletedAt;
  final DateTime? lastSyncedAt;
  final String syncStatus;

  const WhatsappCampaignPublication({
    required this.id,
    this.localId,
    this.remoteId,
    required this.negocioId,
    required this.dateKey,
    required this.mode,
    required this.productIds,
    required this.renderedImagePaths,
    required this.statusTexts,
    required this.status,
    required this.consumesQuota,
    this.quotaUnits = 1,
    DateTime? fechaInicio,
    this.duracionDias = 7,
    this.campaignStatus = WhatsappCampaignStatus.activo,
    required this.createdAt,
    this.updatedAt,
    this.openedWhatsappAt,
    this.confirmedByUserAt,
    this.canceledByUserAt,
    this.failedAt,
    this.estimatedExpiresAt,
    this.error,
    this.isActive = true,
    this.deletedAt,
    this.lastSyncedAt,
    this.syncStatus = 'pending',
  }) : fechaInicio = fechaInicio ?? createdAt;

  bool get puedeReintentarMismaPublicacion {
    return status == WhatsappCampaignPublicationStatus.enviadoAWhatsapp ||
        status == WhatsappCampaignPublicationStatus.canceladoPorUsuario;
  }

  WhatsappCampaignPublication copyWith({
    int? localId,
    String? remoteId,
    String? status,
    String? campaignStatus,
    bool? consumesQuota,
    int? quotaUnits,
    DateTime? fechaInicio,
    int? duracionDias,
    DateTime? updatedAt,
    DateTime? openedWhatsappAt,
    DateTime? confirmedByUserAt,
    DateTime? canceledByUserAt,
    DateTime? failedAt,
    DateTime? estimatedExpiresAt,
    String? error,
    bool? isActive,
    DateTime? deletedAt,
    DateTime? lastSyncedAt,
    String? syncStatus,
  }) {
    return WhatsappCampaignPublication(
      id: id,
      localId: localId ?? this.localId,
      remoteId: remoteId ?? this.remoteId,
      negocioId: negocioId,
      dateKey: dateKey,
      mode: mode,
      productIds: productIds,
      renderedImagePaths: renderedImagePaths,
      statusTexts: statusTexts,
      status: status ?? this.status,
      consumesQuota: consumesQuota ?? this.consumesQuota,
      quotaUnits: quotaUnits ?? this.quotaUnits,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      duracionDias: duracionDias ?? this.duracionDias,
      campaignStatus: campaignStatus ?? this.campaignStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      openedWhatsappAt: openedWhatsappAt ?? this.openedWhatsappAt,
      confirmedByUserAt: confirmedByUserAt ?? this.confirmedByUserAt,
      canceledByUserAt: canceledByUserAt ?? this.canceledByUserAt,
      failedAt: failedAt ?? this.failedAt,
      estimatedExpiresAt: estimatedExpiresAt ?? this.estimatedExpiresAt,
      error: error ?? this.error,
      isActive: isActive ?? this.isActive,
      deletedAt: deletedAt ?? this.deletedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'localId': localId,
      'remoteId': remoteId,
      'negocioId': negocioId,
      'dateKey': dateKey,
      'mode': mode,
      'productIds': productIds,
      'renderedImagePaths': renderedImagePaths,
      'statusTexts': statusTexts,
      'status': status,
      'consumesQuota': consumesQuota,
      'quotaUnits': quotaUnits,
      'fechaInicio': fechaInicio.toIso8601String(),
      'duracionDias': duracionDias,
      'campaignStatus': campaignStatus,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'openedWhatsappAt': openedWhatsappAt?.toIso8601String(),
      'confirmedByUserAt': confirmedByUserAt?.toIso8601String(),
      'canceledByUserAt': canceledByUserAt?.toIso8601String(),
      'failedAt': failedAt?.toIso8601String(),
      'estimatedExpiresAt': estimatedExpiresAt?.toIso8601String(),
      'error': error,
      'isActive': isActive,
      'deletedAt': deletedAt?.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'syncStatus': syncStatus,
    };
  }

  factory WhatsappCampaignPublication.fromJson(Map<String, Object?> json) {
    return WhatsappCampaignPublication(
      id: json['id'] as String,
      localId: (json['localId'] as num?)?.toInt(),
      remoteId: json['remoteId'] as String?,
      negocioId: (json['negocioId'] as num).toInt(),
      dateKey: json['dateKey'] as String,
      mode: json['mode'] as String? ?? 'catalogo',
      productIds: (json['productIds'] as List<dynamic>? ?? const [])
          .map((value) => '$value')
          .toList(),
      renderedImagePaths:
          (json['renderedImagePaths'] as List<dynamic>? ?? const [])
              .map((value) => '$value')
              .toList(),
      statusTexts: (json['statusTexts'] as List<dynamic>? ?? const [])
          .map((value) => '$value')
          .toList(),
      status: json['status'] as String,
      consumesQuota: json['consumesQuota'] as bool? ?? false,
      quotaUnits: (json['quotaUnits'] as num?)?.toInt() ?? 1,
      fechaInicio: _dateOrNull(json['fechaInicio']),
      duracionDias: (json['duracionDias'] as num?)?.toInt() ?? 7,
      campaignStatus:
          json['campaignStatus'] as String? ?? WhatsappCampaignStatus.activo,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: _dateOrNull(json['updatedAt']),
      openedWhatsappAt: _dateOrNull(json['openedWhatsappAt']),
      confirmedByUserAt: _dateOrNull(json['confirmedByUserAt']),
      canceledByUserAt: _dateOrNull(json['canceledByUserAt']),
      failedAt: _dateOrNull(json['failedAt']),
      estimatedExpiresAt: _dateOrNull(json['estimatedExpiresAt']),
      error: json['error'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      deletedAt: _dateOrNull(json['deletedAt']),
      lastSyncedAt: _dateOrNull(json['lastSyncedAt']),
      syncStatus: json['syncStatus'] as String? ?? 'pending',
    );
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value == null) return null;
    final text = '$value';
    if (text.isEmpty) return null;
    return DateTime.parse(text);
  }
}
