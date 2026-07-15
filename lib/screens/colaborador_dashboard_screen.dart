import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/auditoria_sqlite_model.dart';
import '../data/models/solicitud_autorizacion_sqlite_model.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/dashboard_kpi_card.dart';
import '../widgets/dashboard_news_card.dart';
import '../widgets/dashboard_section_header.dart';
import '../widgets/fiado_action_tile.dart';
import '../widgets/fiado_gradient_card.dart';
import 'auditoria_reportes_screen.dart';
import 'auditoria_screen.dart';
import 'inventario_screen.dart';
import 'login_screen.dart';
import 'mis_solicitudes_screen.dart';
import 'onboarding_assistant_screen.dart';

class ColaboradorDashboardScreen extends ConsumerWidget {
  const ColaboradorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final auditorias =
        ref.watch(auditoriasColaboradorProvider).valueOrNull ?? const [];
    final solicitudes =
        ref.watch(solicitudesColaboradorProvider).valueOrNull ?? const [];
    final productos =
        ref.watch(productosProvider).valueOrNull?.productos ?? const [];
    final auditoriasPendientes = auditorias
        .where(
          (item) =>
              item.auditoria.estado != AuditoriaSqliteModel.estadoFinalizada,
        )
        .length;
    final auditoriasRealizadas = auditorias
        .where(
          (item) =>
              item.auditoria.estado == AuditoriaSqliteModel.estadoFinalizada,
        )
        .length;
    final solicitudesAprobadas = solicitudes
        .where(
          (item) =>
              item.estado == SolicitudAutorizacionSqliteModel.estadoAprobado,
        )
        .length;
    final solicitudesRechazadas = solicitudes
        .where(
          (item) =>
              item.estado == SolicitudAutorizacionSqliteModel.estadoRechazado,
        )
        .length;
    final productosAgregados = solicitudes
        .where(
          (item) =>
              item.entidad == SolicitudAutorizacionSqliteModel.entidadProducto,
        )
        .length;
    final news = _collaboratorNews(
      auditoriasPendientes: auditoriasPendientes,
      solicitudesAprobadas: solicitudesAprobadas,
      solicitudesRechazadas: solicitudesRechazadas,
      productosAgregados: productosAgregados,
      productosActivos: productos.length,
      context: context,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard colaborador')),
      drawer: AppNavigationDrawer(
        title: user?.nombre ?? 'Colaborador',
        subtitle: 'Menu operativo',
        items: [
          AppNavigationItem(
            label: 'Dashboard',
            icon: Icons.dashboard,
            onTap: () {},
          ),
          AppNavigationItem(
            label: 'Inventario',
            icon: Icons.inventory_2_outlined,
            onTap: () => _push(context, const InventarioScreen()),
          ),
          AppNavigationItem(
            label: 'Auditorias',
            icon: Icons.playlist_add_check_circle_outlined,
            onTap: () => _push(
              context,
              AuditoriaScreen(productos: productos, cantidadObjetivo: 3),
            ),
          ),
          AppNavigationItem(
            label: 'Mis auditorias',
            icon: Icons.assignment_turned_in_outlined,
            onTap: () => _push(context, const AuditoriaReportesScreen()),
          ),
          AppNavigationItem(
            label: 'Mis solicitudes',
            icon: Icons.fact_check_outlined,
            onTap: () => _push(context, const MisSolicitudesScreen()),
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
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = AdaptiveLayout.horizontalPadding(
              constraints.maxWidth,
            );
            final columns = constraints.maxWidth >= 1000
                ? 5
                : constraints.maxWidth >= 720
                ? 3
                : constraints.maxWidth >= 420
                ? 2
                : 1;
            final wide = constraints.maxWidth >= 980;

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
                    _CollaboratorHero(name: user?.nombre ?? 'Colaborador'),
                    const SizedBox(height: 22),
                    const DashboardSectionHeader(
                      title: 'Indicadores operativos',
                      subtitle:
                          'Actividad visible de auditorias y solicitudes.',
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: columns == 1 ? 1.85 : 1.18,
                      children: [
                        DashboardKpiCard(
                          title: 'Auditorias realizadas',
                          value: '$auditoriasRealizadas',
                          subtitle: 'Finalizadas por colaborador',
                          icon: Icons.assignment_turned_in_outlined,
                          color: const Color(0xFF1F7A6B),
                        ),
                        DashboardKpiCard(
                          title: 'Auditorias pendientes',
                          value: '$auditoriasPendientes',
                          subtitle: 'Requieren cierre',
                          icon: Icons.assignment_late_outlined,
                          color: const Color(0xFFB54708),
                          status: auditoriasPendientes > 0 ? 'Pendiente' : 'OK',
                        ),
                        DashboardKpiCard(
                          title: 'Solicitudes enviadas',
                          value: '${solicitudes.length}',
                          subtitle: 'Cambios solicitados',
                          icon: Icons.outbox_outlined,
                          color: const Color(0xFF2F6F88),
                        ),
                        DashboardKpiCard(
                          title: 'Solicitudes aprobadas',
                          value: '$solicitudesAprobadas',
                          subtitle: 'Aprobadas por negocio',
                          icon: Icons.verified_outlined,
                          color: const Color(0xFF1F7A6B),
                        ),
                        DashboardKpiCard(
                          title: 'Productos agregados',
                          value: '$productosAgregados',
                          subtitle: 'Solicitudes sobre productos',
                          icon: Icons.add_business_outlined,
                          color: const Color(0xFF6D597A),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _CollaboratorNewsFeed(news: news)),
                          const SizedBox(width: 18),
                          Expanded(child: _collaboratorQuickPanel(context)),
                        ],
                      )
                    else ...[
                      _CollaboratorNewsFeed(news: news),
                      const SizedBox(height: 18),
                      _collaboratorQuickPanel(context),
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

  List<DashboardNewsCard> _collaboratorNews({
    required int auditoriasPendientes,
    required int solicitudesAprobadas,
    required int solicitudesRechazadas,
    required int productosAgregados,
    required int productosActivos,
    required BuildContext context,
  }) {
    final news = <DashboardNewsCard>[];
    if (auditoriasPendientes > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.assignment_late_outlined,
          title: 'Auditoria pendiente',
          description: 'Tienes $auditoriasPendientes auditorias por completar.',
          level: DashboardNewsLevel.alert,
          actionLabel: 'Ver auditorias',
          onAction: () => _push(context, const AuditoriaReportesScreen()),
        ),
      );
    } else {
      news.add(
        const DashboardNewsCard(
          icon: Icons.check_circle_outline_rounded,
          title: 'Auditoria diaria al dia',
          description: 'No hay auditorias pendientes visibles.',
          level: DashboardNewsLevel.success,
        ),
      );
    }
    if (solicitudesAprobadas > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.verified_outlined,
          title: 'Solicitudes aprobadas',
          description: '$solicitudesAprobadas solicitudes fueron aprobadas.',
          level: DashboardNewsLevel.success,
          actionLabel: 'Ver solicitudes',
          onAction: () => _push(context, const MisSolicitudesScreen()),
        ),
      );
    }
    if (solicitudesRechazadas > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.cancel_outlined,
          title: 'Solicitudes rechazadas',
          description: '$solicitudesRechazadas solicitudes requieren revision.',
          level: DashboardNewsLevel.critical,
          actionLabel: 'Ver solicitudes',
          onAction: () => _push(context, const MisSolicitudesScreen()),
        ),
      );
    }
    if (productosAgregados > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.add_business_outlined,
          title: 'Productos agregados correctamente',
          description:
              '$productosAgregados solicitudes vinculadas a productos.',
          level: DashboardNewsLevel.info,
        ),
      );
    }
    news.add(
      DashboardNewsCard(
        icon: Icons.inventory_2_outlined,
        title: 'Inventario disponible',
        description: '$productosActivos productos activos visibles.',
        level: DashboardNewsLevel.info,
        actionLabel: 'Abrir inventario',
        onAction: () => _push(context, const InventarioScreen()),
      ),
    );
    return news.take(6).toList();
  }

  Widget _collaboratorQuickPanel(BuildContext context) {
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
            title: 'Accesos rapidos',
            subtitle: 'Herramientas operativas del dia.',
          ),
          const SizedBox(height: 14),
          FiadoActionTile(
            icon: Icons.inventory_2_outlined,
            title: 'Inventario',
            onTap: () => _push(context, const InventarioScreen()),
          ),
          FiadoActionTile(
            icon: Icons.fact_check_outlined,
            title: 'Mis solicitudes',
            onTap: () => _push(context, const MisSolicitudesScreen()),
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

class _CollaboratorHero extends StatelessWidget {
  final String name;

  const _CollaboratorHero({required this.name});

  @override
  Widget build(BuildContext context) {
    return FiadoGradientCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.engineering_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Panel operativo de auditoria e inventario.',
                  style: TextStyle(color: Color(0xFFDCE9E5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollaboratorNewsFeed extends StatelessWidget {
  final List<DashboardNewsCard> news;

  const _CollaboratorNewsFeed({required this.news});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(
          title: 'Noticias operativas',
          subtitle: 'Avisos de auditorias, solicitudes e inventario.',
        ),
        const SizedBox(height: 14),
        for (final item in news) ...[item, const SizedBox(height: 10)],
      ],
    );
  }
}

void _push(BuildContext context, Widget screen) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}
