import 'package:sqflite/sqflite.dart';

import '../../core/constants/subscription_plans.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/local_database.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../models/subscription_sqlite_model.dart';
import '../models/usuario_sqlite_model.dart';

class SubscriptionAccess {
  final bool hasAccess;
  final int trialDaysLeft;
  final String status;

  const SubscriptionAccess({
    required this.hasAccess,
    required this.trialDaysLeft,
    required this.status,
  });
}

class CollaboratorLimitStatus {
  final int usados;
  final int limite;
  final bool puedeCrear;

  const CollaboratorLimitStatus({
    required this.usados,
    required this.limite,
    required this.puedeCrear,
  });
}

class SubscriptionRepository {
  static const offlineGrace = Duration(hours: 72);

  final LocalDatabase databaseHelper;

  SubscriptionRepository({LocalDatabase? databaseHelper})
    : databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  List<SubscriptionPlan> obtenerPlanesDisponibles() {
    return SubscriptionPlans.all;
  }

  double calcularPrecioFinal(String planId, String billingCycle) {
    validarDuracionSuscripcion(billingCycle);
    return SubscriptionPlans.byId(planId).priceFor(billingCycle).finalPrice;
  }

  List<SubscriptionPlanPrice> obtenerPlanesPorCiclo(String billingCycle) {
    validarDuracionSuscripcion(billingCycle);
    return SubscriptionPlans.pricesForCycle(billingCycle);
  }

  double obtenerAhorro(String planId, String billingCycle) {
    validarDuracionSuscripcion(billingCycle);
    return SubscriptionPlans.byId(planId).priceFor(billingCycle).ahorro;
  }

  void validarDuracionSuscripcion(String billingCycle) {
    if (!SubscriptionPlans.validarDuracionSuscripcion(billingCycle)) {
      throw ArgumentError.value(
        billingCycle,
        'billingCycle',
        'Duracion de suscripcion no soportada.',
      );
    }
  }

  Future<SubscriptionSqliteModel> crearTrialParaNegocio(int usuarioId) async {
    final db = await databaseHelper.database;
    final now = DateTime.now();
    final subscription = SubscriptionSqliteModel.trialBasico(
      usuarioId: usuarioId,
      now: now,
    );
    final id = await db.insert(
      DatabaseSchema.subscriptionsTable,
      subscription.toMap(),
    );
    final saved = subscription.copyWith(id: id);
    return saved;
  }

  Future<void> seleccionarPlan(
    int usuarioNegocioId,
    String planId, {
    String billingCycle = BillingCycle.mensual,
  }) async {
    validarDuracionSuscripcion(billingCycle);
    final plan = SubscriptionPlans.byId(planId);
    final price = plan.priceFor(billingCycle);
    final db = await databaseHelper.database;
    final now = DateTime.now();
    final current = await obtenerSuscripcionPorUsuario(usuarioNegocioId);

    if (current == null) {
      await db.insert(
        DatabaseSchema.subscriptionsTable,
        SubscriptionSqliteModel.fromPlan(
          usuarioId: usuarioNegocioId,
          plan: plan,
          status: 'trial',
          now: now,
          billingCycle: billingCycle,
        ).toMap(),
      );
      return;
    }

    await db.update(
      DatabaseSchema.subscriptionsTable,
      {
        'plan_id': plan.id,
        'plan_nombre': plan.nombre,
        'precio_mensual': plan.precioMensual,
        'max_colaboradores': plan.maxColaboradores,
        'billing_cycle': price.billingCycle,
        'discount_percent': price.discountPercent,
        'original_price': price.originalPrice,
        'final_price': price.finalPrice,
        'currency_code': price.currencyCode,
        'updated_at': now.toIso8601String(),
        'sync_status': SyncStatus.updated,
      },
      where: 'id = ?',
      whereArgs: [current.id],
    );
  }

  Future<SubscriptionSqliteModel?> obtenerPlanActual(int usuarioNegocioId) {
    return obtenerSuscripcionPorUsuario(usuarioNegocioId);
  }

  Future<SubscriptionSqliteModel?> obtenerSuscripcionPorUsuario(
    int usuarioId,
  ) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.subscriptionsTable,
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return SubscriptionSqliteModel.fromMap(rows.first);
  }

  Future<CollaboratorLimitStatus> validarLimiteColaboradores(
    int usuarioNegocioId,
  ) async {
    final plan = await obtenerPlanActual(usuarioNegocioId);
    final usados = await contarColaboradoresActivos(usuarioNegocioId);
    final limite = plan?.maxColaboradores ?? 0;
    return CollaboratorLimitStatus(
      usados: usados,
      limite: limite,
      puedeCrear: usados < limite,
    );
  }

  Future<int> contarColaboradoresActivos(int usuarioNegocioId) async {
    final db = await databaseHelper.database;
    final result = await db.rawQuery(
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.usuariosTable}
WHERE negocio_id = ? AND tipo_usuario = ? AND activo = 1
''',
      [usuarioNegocioId, UsuarioSqliteModel.tipoColaborador],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> puedeCrearColaborador(int usuarioNegocioId) async {
    final access = await validarAccesoNegocio(usuarioNegocioId);
    final limit = await validarLimiteColaboradores(usuarioNegocioId);
    return access.hasAccess && limit.puedeCrear;
  }

  Future<SubscriptionAccess> validarAccesoNegocio(int usuarioNegocioId) async {
    final subscription = await obtenerSuscripcionPorUsuario(usuarioNegocioId);
    if (subscription == null) {
      return const SubscriptionAccess(
        hasAccess: false,
        trialDaysLeft: 0,
        status: 'missing',
      );
    }

    final now = DateTime.now();
    final trialActive =
        (subscription.status == SubscriptionSqliteModel.statusTrial ||
            subscription.status == SubscriptionSqliteModel.statusTrialActive ||
            subscription.status ==
                SubscriptionSqliteModel.statusTrialLocalPendingValidation) &&
        subscription.trialEndsAt.isAfter(now);
    final paidActive =
        subscription.status == 'active' &&
        (subscription.currentPeriodEndsAt == null ||
            subscription.currentPeriodEndsAt!.isAfter(now));

    final expiredWhileOfflineGrace =
        (subscription.status == SubscriptionSqliteModel.statusTrialActive ||
            subscription.status == SubscriptionSqliteModel.statusActive) &&
        (subscription.currentPeriodEndsAt ?? subscription.trialEndsAt)
            .add(offlineGrace)
            .isAfter(now);

    return SubscriptionAccess(
      hasAccess: trialActive || paidActive || expiredWhileOfflineGrace,
      trialDaysLeft: await diasRestantesTrial(usuarioNegocioId),
      status: subscription.status,
    );
  }

  Future<SubscriptionAccess> validarAccesoColaborador(int colaboradorId) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.usuariosTable,
      where: 'id = ? AND tipo_usuario = ? AND activo = 1',
      whereArgs: [colaboradorId, UsuarioSqliteModel.tipoColaborador],
      limit: 1,
    );

    if (rows.isEmpty) {
      return const SubscriptionAccess(
        hasAccess: false,
        trialDaysLeft: 0,
        status: 'collaborator_inactive',
      );
    }

    final colaborador = UsuarioSqliteModel.fromMap(rows.first);
    if (colaborador.negocioId == null) {
      return const SubscriptionAccess(
        hasAccess: false,
        trialDaysLeft: 0,
        status: 'missing_business',
      );
    }

    return validarAccesoNegocio(colaborador.negocioId!);
  }

  Future<int> diasRestantesTrial(int usuarioNegocioId) async {
    final subscription = await obtenerSuscripcionPorUsuario(usuarioNegocioId);
    if (subscription == null ||
        (subscription.status != SubscriptionSqliteModel.statusTrial &&
            subscription.status != SubscriptionSqliteModel.statusTrialActive &&
            subscription.status !=
                SubscriptionSqliteModel.statusTrialLocalPendingValidation)) {
      return 0;
    }
    final days = subscription.trialEndsAt.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  Future<void> marcarComoActiva(int usuarioNegocioId) async {
    final db = await databaseHelper.database;
    final now = DateTime.now();
    final current = await obtenerSuscripcionPorUsuario(usuarioNegocioId);
    final periodDays = switch (current?.billingCycle) {
      BillingCycle.trimestral => 90,
      BillingCycle.anual => 365,
      _ => 30,
    };
    await db.update(
      DatabaseSchema.subscriptionsTable,
      {
        'status': 'active',
        'current_period_started_at': now.toIso8601String(),
        'current_period_ends_at': now
            .add(Duration(days: periodDays))
            .toIso8601String(),
        'updated_at': now.toIso8601String(),
        'sync_status': SyncStatus.updated,
      },
      where: 'usuario_id = ?',
      whereArgs: [usuarioNegocioId],
    );
  }

  Future<void> aplicarEstadoRemoto({
    required int usuarioNegocioId,
    required String planId,
    required String billingCycle,
    required String status,
    DateTime? trialEndsAt,
  }) async {
    final db = await databaseHelper.database;
    final now = DateTime.now();
    final plan = SubscriptionPlans.byId(planId);
    final price = plan.priceFor(billingCycle);
    final current = await obtenerSuscripcionPorUsuario(usuarioNegocioId);
    final values = <String, Object?>{
      'plan_id': plan.id,
      'plan_nombre': plan.nombre,
      'precio_mensual': plan.precioMensual,
      'max_colaboradores': plan.maxColaboradores,
      'billing_cycle': price.billingCycle,
      'discount_percent': price.discountPercent,
      'original_price': price.originalPrice,
      'final_price': price.finalPrice,
      'currency_code': price.currencyCode,
      'status': status,
      'trial_started_at':
          current?.trialStartedAt.toIso8601String() ?? now.toIso8601String(),
      'trial_ends_at':
          trialEndsAt?.toIso8601String() ??
          current?.trialEndsAt.toIso8601String() ??
          now.add(const Duration(days: 30)).toIso8601String(),
      'current_period_started_at':
          current?.currentPeriodStartedAt?.toIso8601String() ??
          now.toIso8601String(),
      'current_period_ends_at':
          trialEndsAt?.toIso8601String() ??
          current?.currentPeriodEndsAt?.toIso8601String(),
      'payment_provider': 'stripe',
      'updated_at': now.toIso8601String(),
      'sync_status': SyncStatus.synced,
    };

    if (current == null) {
      await db.insert(DatabaseSchema.subscriptionsTable, {
        'usuario_id': usuarioNegocioId,
        'created_at': now.toIso8601String(),
        ...values,
      });
      return;
    }

    await db.update(
      DatabaseSchema.subscriptionsTable,
      values,
      where: 'id = ?',
      whereArgs: [current.id],
    );
  }

  Future<void> marcarComoVencida(int usuarioNegocioId) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.subscriptionsTable,
      {
        'status': 'expired',
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': SyncStatus.updated,
      },
      where: 'usuario_id = ?',
      whereArgs: [usuarioNegocioId],
    );
  }
}
