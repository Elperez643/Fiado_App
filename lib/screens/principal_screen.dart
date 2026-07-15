import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/developer_tools.dart';
import '../core/utils/money_formatter.dart';
import '../business_copilot/business_recommendation.dart';
import '../collections_intelligence/collection_insight.dart';
import '../data/models/usuario_sqlite_model.dart';
import '../inventory_intelligence/inventory_insight.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../models/producto.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/dashboard_kpi_card.dart';
import '../widgets/dashboard_news_card.dart';
import '../widgets/dashboard_section_header.dart';
import '../widgets/fiado_action_tile.dart';
import '../widgets/fiado_gradient_card.dart';
import '../widgets/sync_cloud_indicator.dart';
import 'auditoria_reportes_screen.dart';
import 'billing_history_screen.dart';
import 'business_copilot_screen.dart';
import 'client_score_report_screen.dart';
import 'clientes_screen.dart';
import 'collections_intelligence_screen.dart';
import 'cuentas_por_cobrar_screen.dart';
import 'create_whatsapp_campaign_screen.dart';
import 'gestionar_colaboradores_screen.dart';
import 'inventory_intelligence_screen.dart';
import 'inventario_screen.dart';
import 'login_screen.dart';
import 'onboarding_assistant_screen.dart';
import 'payment_methods_screen.dart';
import 'solicitudes_pendientes_screen.dart';
import 'subscription_screen.dart';
import 'sync_advanced_settings_screen.dart';
import 'sync_diagnostics_screen.dart';
import 'sync_status_screen.dart';

class PrincipalScreen extends ConsumerWidget {
  const PrincipalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      return _buildDashboard(context, ref);
    } catch (error, stackTrace) {
      debugPrint('[principal] error build dashboard: $error');
      debugPrint('$stackTrace');
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard ejecutivo')),
        body: SafeArea(
          child: AppErrorState(
            onRetry: () {
              ref.invalidate(clientesProvider);
              ref.invalidate(movimientosProvider);
              ref.invalidate(productosProvider);
              ref.invalidate(collectionInsightsProvider);
              ref.invalidate(inventoryInsightsProvider);
              ref.invalidate(businessRecommendationsProvider);
            },
            onLogout: () => _confirmarCerrarSesion(context, ref),
          ),
        ),
      );
    }
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final esNegocio = user?.tipoUsuario == UsuarioSqliteModel.tipoNegocio;
    if (!esNegocio) {
      return _AccesoNoPermitido(
        mensaje: 'Este panel es solo para usuarios Negocio.',
        destinoLogin: user == null,
      );
    }

    final clientes =
        ref.watch(clientesProvider).valueOrNull?.clientes ?? const <Cliente>[];
    final movimientos =
        ref.watch(movimientosProvider).valueOrNull ?? const <Movimiento>[];
    final productos =
        ref.watch(productosProvider).valueOrNull?.productos ??
        const <Producto>[];
    final inventarioResumen = ref.watch(inventarioResumenProvider);
    final solicitudesPendientes =
        ref.watch(solicitudesPendientesCountProvider).valueOrNull ?? 0;
    final cuentas30 = ref.watch(cuentasPorCobrarProvider).valueOrNull ?? [];
    final mora45 = ref.watch(ciclosMoraProvider).valueOrNull ?? [];
    final bloqueados60 = ref.watch(ciclosBloqueadosProvider).valueOrNull ?? [];
    final auditoriasPendientes =
        ref.watch(auditoriasPendientesProvider).valueOrNull ?? 0;
    final inventoryInsights =
        ref.watch(inventoryInsightsProvider).valueOrNull ??
        const <InventoryInsight>[];
    final inventorySummary = InventoryIntelligenceSummary.fromInsights(
      inventoryInsights,
    );
    final collectionInsights =
        ref.watch(collectionInsightsProvider).valueOrNull ??
        const <CollectionInsight>[];
    final collectionSummary = CollectionsIntelligenceSummary.fromInsights(
      collectionInsights,
    );
    final businessRecommendations =
        ref.watch(businessRecommendationsProvider).valueOrNull ??
        const <BusinessRecommendation>[];
    final copilotSummary = BusinessCopilotSummary.fromRecommendations(
      businessRecommendations,
    );

    final montoFiado = clientes.fold<double>(
      0,
      (sum, cliente) => sum + cliente.deuda,
    );
    final now = DateTime.now();
    final cobradoMes = movimientos
        .where(
          (movimiento) =>
              movimiento.tipo == 'pago' &&
              movimiento.fecha.year == now.year &&
              movimiento.fecha.month == now.month,
        )
        .fold<double>(0, (sum, movimiento) => sum + movimiento.monto);
    final productosStockBajo = productos
        .where((producto) => producto.cantidad <= producto.stockMinimo)
        .length;
    final clientesEnRiesgo = {
      ...clientes.where((cliente) => cliente.deuda > 0).map((c) => c.telefono),
      ...mora45.map((c) => c.clienteTelefono ?? '${c.clienteId}'),
      ...bloqueados60.map((c) => c.clienteTelefono ?? '${c.clienteId}'),
    }.length;

    final news = _businessNews(
      context: context,
      solicitudesPendientes: solicitudesPendientes,
      cuentas30: cuentas30.length,
      mora45: mora45.length,
      bloqueados60: bloqueados60.length,
      productosStockBajo: productosStockBajo,
      auditoriasPendientes: auditoriasPendientes,
      cobradoMes: cobradoMes,
      topCliente: _topCliente(clientes),
      collectionSummary: collectionSummary,
      copilotSummary: copilotSummary,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard ejecutivo'),
        actions: const [SyncCloudIndicator()],
      ),
      drawer: AppNavigationDrawer(
        title: user?.nombre ?? 'Fiado App',
        subtitle: 'Menu de negocio',
        items: _businessMenu(context, ref, user),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = AdaptiveLayout.horizontalPadding(
              constraints.maxWidth,
            );
            final wide = constraints.maxWidth >= 980;
            final kpiColumns = constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 720
                ? 3
                : constraints.maxWidth >= 420
                ? 2
                : 1;

            final kpis = [
              DashboardKpiCard(
                title: 'Clientes activos',
                value: '${clientes.length}',
                subtitle: 'Clientes visibles en cartera',
                icon: Icons.groups_2_outlined,
                color: const Color(0xFF1F7A6B),
                status: 'Cartera',
                onTap: () => _push(context, const ClientesScreen()),
              ),
              DashboardKpiCard(
                title: 'Monto fiado activo',
                value: _money(montoFiado),
                subtitle: 'Saldo pendiente registrado',
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFFB54708),
                status: montoFiado > 0 ? 'Pendiente' : 'Al dia',
                onTap: () => _push(context, const ClientesScreen()),
              ),
              DashboardKpiCard(
                title: 'Cobrado este mes',
                value: _money(cobradoMes),
                subtitle: 'Pagos registrados en el mes',
                icon: Icons.payments_outlined,
                color: const Color(0xFF2F6F88),
              ),
              DashboardKpiCard(
                title: 'Score promedio',
                value: 'Sin datos',
                subtitle: 'Disponible al calcular scores',
                icon: Icons.insights_outlined,
                color: const Color(0xFF6D597A),
                onTap: () => _push(context, const ClientScoreReportScreen()),
              ),
              DashboardKpiCard(
                title: 'Clientes en riesgo',
                value: '$clientesEnRiesgo',
                subtitle: 'Con saldo, mora o bloqueo',
                icon: Icons.report_problem_outlined,
                color: const Color(0xFFB42318),
                status: clientesEnRiesgo > 0 ? 'Atencion' : 'Estable',
              ),
              DashboardKpiCard(
                title: 'Stock bajo',
                value: '$productosStockBajo',
                subtitle: 'Productos bajo minimo',
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFFE7B04B),
                onTap: () => _push(context, const InventarioScreen()),
              ),
              DashboardKpiCard(
                title: 'Vencidas 30 dias',
                value: '${cuentas30.length}',
                subtitle: 'Cuentas por cobrar',
                icon: Icons.calendar_month_outlined,
                color: const Color(0xFFB54708),
                onTap: () => _push(context, const CuentasPorCobrarScreen()),
              ),
              DashboardKpiCard(
                title: 'Bloqueados 60 dias',
                value: '${bloqueados60.length}',
                subtitle: 'Clientes bloqueados para fiar',
                icon: Icons.block_outlined,
                color: const Color(0xFFB42318),
                status: bloqueados60.isEmpty ? 'OK' : 'Critico',
                onTap: () => _push(context, const CuentasPorCobrarScreen()),
              ),
              DashboardKpiCard(
                title: 'Cobrar hoy',
                value: '${collectionSummary.collectTodayCount}',
                subtitle: 'Prioridad alta o critica',
                icon: Icons.today_outlined,
                color: const Color(0xFFB54708),
                status: collectionSummary.collectTodayCount > 0
                    ? 'Seguimiento'
                    : 'OK',
                onTap: () =>
                    _push(context, const CollectionsIntelligenceScreen()),
              ),
              DashboardKpiCard(
                title: 'Vencen pronto',
                value: '${collectionSummary.dueSoonCount}',
                subtitle: 'Proximos 3 dias',
                icon: Icons.event_outlined,
                color: const Color(0xFF2F6F88),
                onTap: () =>
                    _push(context, const CollectionsIntelligenceScreen()),
              ),
              DashboardKpiCard(
                title: 'Mora critica',
                value:
                    '${collectionSummary.overdue45Count + collectionSummary.blocked60Count}',
                subtitle: 'Mora 45 y bloqueados 60',
                icon: Icons.priority_high_rounded,
                color: const Color(0xFFB42318),
                onTap: () =>
                    _push(context, const CollectionsIntelligenceScreen()),
              ),
              DashboardKpiCard(
                title: 'Monto critico',
                value: _money(collectionSummary.criticalReceivable),
                subtitle: 'Requiere atencion',
                icon: Icons.request_quote_outlined,
                color: const Color(0xFFB42318),
                onTap: () =>
                    _push(context, const CollectionsIntelligenceScreen()),
              ),
              DashboardKpiCard(
                title: 'Recuperacion sugerida',
                value: _money(collectionSummary.suggestedRecoveryToday),
                subtitle: 'Alta + critica',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF1F7A6B),
                onTap: () =>
                    _push(context, const CollectionsIntelligenceScreen()),
              ),
              DashboardKpiCard(
                title: 'Productos criticos',
                value: '${inventorySummary.criticalCount}',
                subtitle: 'Cobertura menor o igual a 3 dias',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFB54708),
                onTap: () =>
                    _push(context, const InventoryIntelligenceScreen()),
              ),
              DashboardKpiCard(
                title: 'Reposicion sugerida',
                value: '${inventorySummary.totalRecommendedRestock}',
                subtitle: 'Unidades sugeridas para 15 dias',
                icon: Icons.add_box_outlined,
                color: const Color(0xFF1F7A6B),
                onTap: () =>
                    _push(context, const InventoryIntelligenceScreen()),
              ),
              DashboardKpiCard(
                title: 'Valor inmovilizado',
                value: _money(inventorySummary.totalCostValue),
                subtitle: 'Costo total de inventario',
                icon: Icons.savings_outlined,
                color: const Color(0xFF2F6F88),
                onTap: () =>
                    _push(context, const InventoryIntelligenceScreen()),
              ),
              DashboardKpiCard(
                title: 'Ganancia potencial',
                value: _money(inventorySummary.totalPotentialProfit),
                subtitle: 'Venta menos costo',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF6D597A),
                onTap: () =>
                    _push(context, const InventoryIntelligenceScreen()),
              ),
              DashboardKpiCard(
                title: 'Sin movimiento',
                value: '${inventorySummary.noMovementCount}',
                subtitle: 'Sin ventas en 30 dias',
                icon: Icons.hourglass_empty_rounded,
                color: const Color(0xFF6D597A),
                onTap: () =>
                    _push(context, const InventoryIntelligenceScreen()),
              ),
            ];

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                28,
              ),
              child: AdaptiveWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ExecutiveHero(
                      title: 'Hola, ${user?.nombre ?? 'Negocio'}',
                      subtitle:
                          'Vista ejecutiva de cartera, cobros, inventario y operaciones.',
                      trailing:
                          '${inventarioResumen.productosActivos} productos activos',
                    ),
                    if (businessRecommendations.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _CopilotTopRecommendations(
                        recommendations: businessRecommendations
                            .take(3)
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 22),
                    DashboardSectionHeader(
                      title: 'Indicadores clave',
                      subtitle: 'Resumen operativo con datos locales actuales.',
                      trailing: null,
                    ),
                    const SizedBox(height: 14),
                    _ResponsiveKpiGrid(columns: kpiColumns, children: kpis),
                    const SizedBox(height: 24),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _DashboardNewsFeed(news: news),
                          ),
                          const SizedBox(width: 18),
                          Expanded(child: _quickExecutivePanel(context)),
                        ],
                      )
                    else ...[
                      _DashboardNewsFeed(news: news),
                      const SizedBox(height: 18),
                      _quickExecutivePanel(context),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<AppNavigationItem> _businessMenu(
    BuildContext context,
    WidgetRef ref,
    UsuarioSqliteModel? user,
  ) {
    return [
      AppNavigationItem(
        label: 'Dashboard',
        icon: Icons.dashboard,
        onTap: () {},
      ),
      AppNavigationItem(
        label: 'Clientes',
        icon: Icons.groups_2_outlined,
        onTap: () => _push(context, const ClientesScreen()),
      ),
      AppNavigationItem(
        label: 'Inventario',
        icon: Icons.inventory_2_outlined,
        onTap: () => _push(context, const InventarioScreen()),
      ),
      AppNavigationItem(
        label: 'Inventario Inteligente',
        icon: Icons.auto_graph_rounded,
        onTap: () => _push(context, const InventoryIntelligenceScreen()),
      ),
      AppNavigationItem(
        label: 'Business Copilot',
        icon: Icons.lightbulb_outline_rounded,
        onTap: () => _push(context, const BusinessCopilotScreen()),
      ),
      AppNavigationItem(
        label: 'Campanas WhatsApp',
        icon: Icons.campaign_outlined,
        onTap: () => _push(context, const CreateWhatsappCampaignScreen()),
      ),
      AppNavigationItem(
        label: 'Cuentas por cobrar',
        icon: Icons.request_quote_outlined,
        onTap: () => _push(context, const CuentasPorCobrarScreen()),
      ),
      AppNavigationItem(
        label: 'Cobranza Inteligente',
        icon: Icons.manage_search_rounded,
        onTap: () => _push(context, const CollectionsIntelligenceScreen()),
      ),
      AppNavigationItem(
        label: 'Auditorias',
        icon: Icons.assignment_turned_in_outlined,
        onTap: () => _push(context, const InventarioScreen()),
      ),
      AppNavigationItem(
        label: 'Reportes de auditoria',
        icon: Icons.analytics_outlined,
        onTap: () => _push(context, const AuditoriaReportesScreen()),
      ),
      AppNavigationItem(
        label: 'Solicitudes pendientes',
        icon: Icons.fact_check_outlined,
        onTap: () => _push(context, const SolicitudesPendientesScreen()),
      ),
      AppNavigationItem(
        label: 'Colaboradores',
        icon: Icons.engineering_outlined,
        onTap: () => _push(context, const GestionarColaboradoresScreen()),
      ),
      AppNavigationItem(
        label: 'Inteligencia comercial',
        icon: Icons.insights_outlined,
        onTap: () => _push(context, const ClientScoreReportScreen()),
      ),
      AppNavigationItem(
        label: 'Suscripcion',
        icon: Icons.workspace_premium_outlined,
        onTap: () => _push(context, const SubscriptionScreen()),
      ),
      AppNavigationItem(
        label: 'Metodos de pago',
        icon: Icons.credit_card_outlined,
        onTap: () => _push(context, const PaymentMethodsScreen()),
      ),
      AppNavigationItem(
        label: 'Historial de pagos',
        icon: Icons.receipt_long_outlined,
        onTap: () => _push(context, const BillingHistoryScreen()),
      ),
      if (showDeveloperTools)
        AppNavigationItem(
          label: 'Herramientas de desarrollo',
          icon: Icons.sync_rounded,
          onTap: () => _push(context, const SyncStatusScreen()),
        ),
      if (showDeveloperTools)
        AppNavigationItem(
          label: 'Configuracion avanzada de nube',
          icon: Icons.settings_ethernet_rounded,
          onTap: () => _push(context, const SyncAdvancedSettingsScreen()),
        ),
      if (syncDiagnosticsEnabled)
        AppNavigationItem(
          label: 'Diagnóstico de sincronización',
          icon: Icons.monitor_heart_outlined,
          onTap: () => _push(context, const SyncDiagnosticsScreen()),
        ),
      AppNavigationItem(
        label: 'Ayuda / Ver guia nuevamente',
        icon: Icons.help_outline_rounded,
        onTap: user == null
            ? null
            : () => _push(
                context,
                OnboardingAssistantScreen(user: user, manual: true),
              ),
      ),
      AppNavigationItem(
        label: 'Cerrar sesion',
        icon: Icons.logout_rounded,
        destructive: true,
        onTap: () => _confirmarCerrarSesion(context, ref),
      ),
    ];
  }

  List<DashboardNewsCard> _businessNews({
    required BuildContext context,
    required int solicitudesPendientes,
    required int cuentas30,
    required int mora45,
    required int bloqueados60,
    required int productosStockBajo,
    required int auditoriasPendientes,
    required double cobradoMes,
    required Cliente? topCliente,
    required CollectionsIntelligenceSummary collectionSummary,
    required BusinessCopilotSummary copilotSummary,
  }) {
    final news = <DashboardNewsCard>[];
    if (copilotSummary.criticalCount > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.lightbulb_outline_rounded,
          title:
              '${copilotSummary.criticalCount} recomendaciones criticas del Copilot',
          description:
              'Fiado App recomienda atenderlas antes de seguir el dia.',
          level: DashboardNewsLevel.critical,
          actionLabel: 'Abrir Copilot',
          onAction: () => _push(context, const BusinessCopilotScreen()),
        ),
      );
    }
    if (copilotSummary.promotionCount > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.campaign_outlined,
          title: 'Promociona ${copilotSummary.promotionCount} productos',
          description: 'Hay inventario con potencial para campana WhatsApp.',
          level: DashboardNewsLevel.info,
          actionLabel: 'Abrir Copilot',
          onAction: () => _push(context, const BusinessCopilotScreen()),
        ),
      );
    }
    if (collectionSummary.dueSoonCount > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.event_outlined,
          title:
              '${collectionSummary.dueSoonCount} clientes vencen en los proximos 3 dias',
          description: 'Prepara recordatorios antes de que pasen a mora.',
          level: DashboardNewsLevel.alert,
          actionLabel: 'Ver cobranza',
          onAction: () => _push(context, const CollectionsIntelligenceScreen()),
        ),
      );
    }
    final criticalMora =
        collectionSummary.overdue45Count + collectionSummary.blocked60Count;
    if (criticalMora > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.priority_high_rounded,
          title: '$criticalMora clientes estan en mora critica',
          description: 'Prioriza llamadas o acuerdos de pago hoy.',
          level: DashboardNewsLevel.critical,
          actionLabel: 'Ver cobranza',
          onAction: () => _push(context, const CollectionsIntelligenceScreen()),
        ),
      );
    }
    if (collectionSummary.suggestedRecoveryToday > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.trending_up_rounded,
          title:
              '${_money(collectionSummary.suggestedRecoveryToday)} requieren seguimiento hoy',
          description: 'Monto sugerido por prioridad alta y critica.',
          level: DashboardNewsLevel.info,
          actionLabel: 'Ver cobranza',
          onAction: () => _push(context, const CollectionsIntelligenceScreen()),
        ),
      );
    }
    if (bloqueados60 > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.block_outlined,
          title: '$bloqueados60 clientes bloqueados 60 dias',
          description: 'Requieren decision antes de volver a fiar.',
          level: DashboardNewsLevel.critical,
          actionLabel: 'Ver cobros',
          onAction: () => _push(context, const CuentasPorCobrarScreen()),
        ),
      );
    }
    if (mora45 > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.warning_amber_rounded,
          title: '$mora45 clientes en mora 45 dias',
          description: 'Prioriza contacto y acuerdos de pago.',
          level: DashboardNewsLevel.alert,
          actionLabel: 'Ver cuentas',
          onAction: () => _push(context, const CuentasPorCobrarScreen()),
        ),
      );
    }
    if (cuentas30 > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.calendar_month_outlined,
          title: '$cuentas30 cuentas vencidas a 30 dias',
          description: 'Buen momento para preparar recordatorios.',
          level: DashboardNewsLevel.alert,
          actionLabel: 'Ver cuentas',
          onAction: () => _push(context, const CuentasPorCobrarScreen()),
        ),
      );
    }
    if (productosStockBajo > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.inventory_2_outlined,
          title: '$productosStockBajo productos bajo stock minimo',
          description: 'Revisa reposicion para evitar ventas perdidas.',
          level: DashboardNewsLevel.alert,
          actionLabel: 'Ver inventario',
          onAction: () => _push(context, const InventarioScreen()),
        ),
      );
    }
    if (solicitudesPendientes > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.fact_check_outlined,
          title: '$solicitudesPendientes solicitudes pendientes',
          description: 'Hay cambios de colaboradores esperando decision.',
          level: DashboardNewsLevel.info,
          actionLabel: 'Ver solicitudes',
          onAction: () => _push(context, const SolicitudesPendientesScreen()),
        ),
      );
    }
    if (auditoriasPendientes > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.assignment_late_outlined,
          title: '$auditoriasPendientes auditorias pendientes',
          description: 'Mantener auditorias al dia mejora control de stock.',
          level: DashboardNewsLevel.info,
          actionLabel: 'Ver reportes',
          onAction: () => _push(context, const AuditoriaReportesScreen()),
        ),
      );
    }
    if (cobradoMes > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.payments_outlined,
          title: 'Cobros recientes este mes',
          description: 'Se han registrado ${_money(cobradoMes)} en pagos.',
          level: DashboardNewsLevel.success,
        ),
      );
    }
    if (topCliente != null) {
      news.add(
        DashboardNewsCard(
          icon: Icons.star_outline_rounded,
          title: 'Cliente destacado',
          description:
              '${topCliente.nombre} concentra ${_money(topCliente.deuda)} de saldo visible.',
          level: DashboardNewsLevel.info,
          actionLabel: 'Ver clientes',
          onAction: () => _push(context, const ClientesScreen()),
        ),
      );
    }
    if (news.isEmpty) {
      news.add(
        const DashboardNewsCard(
          icon: Icons.check_circle_outline_rounded,
          title: 'Operacion estable',
          description:
              'No hay alertas criticas con los datos locales cargados.',
          level: DashboardNewsLevel.success,
        ),
      );
    }
    return news.take(7).toList();
  }

  Cliente? _topCliente(List<Cliente> clientes) {
    final withDebt = clientes.where((cliente) => cliente.deuda > 0).toList();
    if (withDebt.isEmpty) return null;
    withDebt.sort((a, b) => b.deuda.compareTo(a.deuda));
    return withDebt.first;
  }

  Widget _quickExecutivePanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashboardSectionHeader(
            title: 'Accesos ejecutivos',
            subtitle: 'Rutas frecuentes del negocio.',
          ),
          const SizedBox(height: 14),
          FiadoActionTile(
            icon: Icons.groups_2_outlined,
            title: 'Gestionar clientes',
            onTap: () => _push(context, const ClientesScreen()),
          ),
          FiadoActionTile(
            icon: Icons.inventory_2_outlined,
            title: 'Revisar inventario',
            onTap: () => _push(context, const InventarioScreen()),
          ),
          FiadoActionTile(
            icon: Icons.campaign_outlined,
            title: 'Campanas WhatsApp',
            onTap: () => _push(context, const CreateWhatsappCampaignScreen()),
          ),
          FiadoActionTile(
            icon: Icons.manage_search_rounded,
            title: 'Cobranza Inteligente',
            onTap: () => _push(context, const CollectionsIntelligenceScreen()),
          ),
          FiadoActionTile(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Business Copilot',
            onTap: () => _push(context, const BusinessCopilotScreen()),
          ),
          FiadoActionTile(
            icon: Icons.insights_outlined,
            title: 'Inteligencia comercial',
            onTap: () => _push(context, const ClientScoreReportScreen()),
          ),
          if (showDeveloperTools)
            FiadoActionTile(
              icon: Icons.sync_rounded,
              title: 'Herramientas de desarrollo',
              onTap: () => _push(context, const SyncStatusScreen()),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmarCerrarSesion(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar sesion'),
          content: const Text('Quieres cerrar sesion?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cerrar sesion'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !context.mounted) return;
    await ref.read(authStateProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

class _ExecutiveHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;

  const _ExecutiveHero({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return FiadoGradientCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFDCE9E5)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              trailing,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopilotTopRecommendations extends StatelessWidget {
  final List<BusinessRecommendation> recommendations;

  const _CopilotTopRecommendations({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E8E3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17322C).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeader(
            title: 'Fiado App recomienda',
            subtitle: 'Top 3 acciones sugeridas para hoy.',
            trailing: TextButton.icon(
              onPressed: () => _push(context, const BusinessCopilotScreen()),
              icon: const Icon(Icons.lightbulb_outline_rounded),
              label: const Text('Ver centro'),
            ),
          ),
          const SizedBox(height: 12),
          for (final recommendation in recommendations) ...[
            _CopilotMiniRecommendation(
              recommendation: recommendation,
              onTap: () => _openRecommendationRoute(context, recommendation),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _CopilotMiniRecommendation extends StatelessWidget {
  final BusinessRecommendation recommendation;
  final VoidCallback onTap;

  const _CopilotMiniRecommendation({
    required this.recommendation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (recommendation.priority) {
      BusinessRecommendationPriority.critical => const Color(0xFFB42318),
      BusinessRecommendationPriority.high => const Color(0xFFB54708),
      BusinessRecommendationPriority.medium => const Color(0xFF2F6F88),
      _ => const Color(0xFF1F7A6B),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF17322C),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    recommendation.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF66756D),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DashboardNewsFeed extends StatelessWidget {
  final List<DashboardNewsCard> news;

  const _DashboardNewsFeed({required this.news});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(
          title: 'Noticias importantes',
          subtitle: 'Alertas y oportunidades detectadas.',
        ),
        const SizedBox(height: 14),
        for (final item in news) ...[item, const SizedBox(height: 10)],
      ],
    );
  }
}

class _ResponsiveKpiGrid extends StatelessWidget {
  final int columns;
  final List<Widget> children;

  const _ResponsiveKpiGrid({required this.columns, required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: columns == 1 ? 1.85 : 1.28,
      children: children,
    );
  }
}

class _AccesoNoPermitido extends StatelessWidget {
  final String mensaje;
  final bool destinoLogin;

  const _AccesoNoPermitido({required this.mensaje, required this.destinoLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 42),
              const SizedBox(height: 12),
              Text(mensaje, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
                child: Text(destinoLogin ? 'Ir a login' : 'Cambiar usuario'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _push(BuildContext context, Widget screen) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

void _openRecommendationRoute(
  BuildContext context,
  BusinessRecommendation recommendation,
) {
  final screen = switch (recommendation.actionRoute) {
    BusinessRecommendationRoute.inventory => const InventarioScreen(),
    BusinessRecommendationRoute.collections =>
      const CollectionsIntelligenceScreen(),
    BusinessRecommendationRoute.campaign =>
      const CreateWhatsappCampaignScreen(),
    BusinessRecommendationRoute.audit => const AuditoriaReportesScreen(),
    BusinessRecommendationRoute.authorization =>
      const SolicitudesPendientesScreen(),
    BusinessRecommendationRoute.subscription => const SubscriptionScreen(),
    BusinessRecommendationRoute.score => const ClientScoreReportScreen(),
    _ => const BusinessCopilotScreen(),
  };
  _push(context, screen);
}

String _money(num value) => MoneyFormatter.formatCurrency(value);
