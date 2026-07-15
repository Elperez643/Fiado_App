import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/money_formatter.dart';
import '../data/models/credito_recordatorio_sqlite_model.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../services/storage_service.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/dashboard_kpi_card.dart';
import '../widgets/dashboard_news_card.dart';
import '../widgets/dashboard_section_header.dart';
import '../widgets/fiado_gradient_card.dart';
import 'login_screen.dart';
import 'onboarding_assistant_screen.dart';
import 'personal_debt_reminders_screen.dart';

class PersonalPortalScreen extends ConsumerStatefulWidget {
  final String telefono;

  const PersonalPortalScreen({super.key, required this.telefono});

  @override
  ConsumerState<PersonalPortalScreen> createState() =>
      _PersonalPortalScreenState();
}

class _PersonalPortalScreenState extends ConsumerState<PersonalPortalScreen> {
  Cliente? cliente;
  List<Movimiento> movimientos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final clientes = await StorageService.cargarClientes();
    final historial = await StorageService.cargarHistorial();
    Cliente? encontrado;

    for (final item in clientes) {
      if (item.telefono == widget.telefono) {
        encontrado = item;
        break;
      }
    }

    final movimientosCliente = <Movimiento>[];
    if (encontrado != null) {
      movimientosCliente.addAll(
        historial.where(
          (movimiento) => movimiento.nombreCliente == encontrado!.nombre,
        ),
      );
      movimientosCliente.sort((a, b) => b.fecha.compareTo(a.fecha));
    }

    if (!mounted) {
      return;
    }

    setState(() {
      cliente = encontrado;
      movimientos = movimientosCliente;
      cargando = false;
    });
  }

  double get balance {
    return movimientos.fold<double>(0, (total, movimiento) {
      if (movimiento.tipo == 'pago') {
        return total - movimiento.monto;
      }

      return total + movimiento.monto;
    });
  }

  Future<void> _cerrarSesion() async {
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

    if (confirmar != true || !mounted) {
      return;
    }

    await ref.read(authStateProvider.notifier).logout();

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = cliente?.nombre ?? 'Cliente';
    final recordatorios = ref.watch(recordatoriosCreditoProvider);
    final debtGuidance = ref.watch(personalDebtRemindersProvider);
    final user = ref.watch(currentUserProvider);

    final totalDeuda = balance > 0 ? balance : 0.0;
    final guidanceItems = debtGuidance.valueOrNull ?? const [];
    final guidanceTotal = guidanceItems.fold<double>(
      0,
      (sum, item) => sum + item.totalPendingAmount,
    );
    final totalPendientePersonal = guidanceItems.isEmpty
        ? totalDeuda
        : guidanceTotal;
    final negociosConDeuda = guidanceItems.isEmpty
        ? (totalDeuda > 0 ? 1 : 0)
        : guidanceItems.length;
    final proximoVencimiento = _proximoVencimiento(
      recordatorios.valueOrNull ?? const <CreditoRecordatorioSqliteModel>[],
    );
    final pagos = movimientos.where((m) => m.tipo == 'pago').length;
    final deudas = movimientos.where((m) => m.tipo == 'deuda').length;
    final cumplimiento = deudas == 0
        ? 'Sin datos'
        : '${((pagos / deudas) * 100).clamp(0, 100).round()}%';
    final news = _personalNews(
      recordatorios.valueOrNull ?? const <CreditoRecordatorioSqliteModel>[],
      movimientos,
      totalDeuda,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard personal')),
      drawer: AppNavigationDrawer(
        title: nombre,
        subtitle: widget.telefono,
        items: [
          AppNavigationItem(
            label: 'Dashboard',
            icon: Icons.dashboard,
            onTap: () {},
          ),
          AppNavigationItem(
            label: 'Mis deudas',
            icon: Icons.account_balance_wallet_outlined,
            onTap: () => _mostrarSeccionActual('Mis deudas'),
          ),
          AppNavigationItem(
            label: 'Recordatorios de pago',
            icon: Icons.tips_and_updates_outlined,
            onTap: _abrirRecordatoriosPago,
          ),
          AppNavigationItem(
            label: 'Historial',
            icon: Icons.history_rounded,
            onTap: () => _mostrarSeccionActual('Historial'),
          ),
          AppNavigationItem(
            label: 'Comprobantes',
            icon: Icons.receipt_long_outlined,
            onTap: () => _mostrarSeccionActual('Comprobantes'),
          ),
          AppNavigationItem(
            label: 'Ayuda / Ver guia nuevamente',
            icon: Icons.help_outline_rounded,
            onTap: user == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OnboardingAssistantScreen(user: user, manual: true),
                    ),
                  ),
          ),
          AppNavigationItem(
            label: 'Cerrar sesion',
            icon: Icons.logout_rounded,
            destructive: true,
            onTap: _cerrarSesion,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding = AdaptiveLayout.contentInset(
              constraints.maxWidth,
            );
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 520
                ? 2
                : 1;
            final wide = constraints.maxWidth >= 980;

            if (cargando) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                16,
                contentPadding,
                28,
              ),
              children: [
                _PersonalDashboardHero(
                  nombre: nombre,
                  telefono: widget.telefono,
                ),
                const SizedBox(height: 22),
                const DashboardSectionHeader(
                  title: 'Tu posicion financiera',
                  subtitle: 'Resumen visible de tus deudas y pagos.',
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: columns == 1 ? 1.85 : 1.26,
                  children: [
                    DashboardKpiCard(
                      title: 'Total adeudado',
                      value: MoneyFormatter.formatCurrency(
                        totalPendientePersonal,
                      ),
                      subtitle: totalPendientePersonal > 0
                          ? 'Saldo pendiente actual'
                          : 'No tienes saldo pendiente',
                      icon: Icons.account_balance_wallet_outlined,
                      color: totalPendientePersonal > 0
                          ? const Color(0xFFB42318)
                          : const Color(0xFF1F7A6B),
                      status: totalPendientePersonal > 0
                          ? 'Pendiente'
                          : 'Al dia',
                    ),
                    DashboardKpiCard(
                      title: 'Negocios donde debe',
                      value: '$negociosConDeuda',
                      subtitle: 'Segun datos locales vinculados',
                      icon: Icons.storefront_outlined,
                      color: const Color(0xFF1F7A6B),
                    ),
                    DashboardKpiCard(
                      title: 'Proximo vencimiento',
                      value: proximoVencimiento,
                      subtitle: 'Fecha mas cercana registrada',
                      icon: Icons.event_available_outlined,
                      color: const Color(0xFFB54708),
                    ),
                    DashboardKpiCard(
                      title: 'Historial de cumplimiento',
                      value: cumplimiento,
                      subtitle: '$pagos pagos sobre $deudas deudas',
                      icon: Icons.verified_outlined,
                      color: const Color(0xFF2F6F88),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                debtGuidance.when(
                  data: (items) => items.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: _PersonalDebtGuidanceTeaser(
                            count: items.length,
                            highestPriority: items.first.priorityLabel,
                            onTap: _abrirRecordatoriosPago,
                          ),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                ),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _PersonalNewsFeed(news: news)),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _BusinessDebtCard(
                          balance: balance,
                          movimientos: movimientos.length,
                        ),
                      ),
                    ],
                  )
                else ...[
                  _PersonalNewsFeed(news: news),
                  if (balance > 0) ...[
                    const SizedBox(height: 18),
                    _BusinessDebtCard(
                      balance: balance,
                      movimientos: movimientos.length,
                    ),
                  ],
                ],
                recordatorios.when(
                  data: (items) => items.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: _PersonalCreditNotices(items: items),
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: LinearProgressIndicator(),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text('No se pudieron cargar avisos: $error'),
                  ),
                ),
                const SizedBox(height: 22),
                const DashboardSectionHeader(
                  title: 'Movimientos recientes',
                  subtitle: 'Deudas y pagos registrados para tu telefono.',
                ),
                const SizedBox(height: 12),
                if (movimientos.isEmpty)
                  _EmptyPersonalState(telefono: widget.telefono)
                else
                  ...movimientos.map(
                    (movimiento) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MovimientoPersonalTile(movimiento: movimiento),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _proximoVencimiento(List<CreditoRecordatorioSqliteModel> items) {
    final fechas =
        items.map((item) => item.fechaLimite).whereType<DateTime>().toList()
          ..sort();
    if (fechas.isEmpty) return 'Sin datos';
    final fecha = fechas.first;
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  List<DashboardNewsCard> _personalNews(
    List<CreditoRecordatorioSqliteModel> recordatorios,
    List<Movimiento> movimientos,
    double totalDeuda,
  ) {
    final news = <DashboardNewsCard>[];
    for (final item in recordatorios.take(3)) {
      news.add(
        DashboardNewsCard(
          icon: Icons.notifications_active_outlined,
          title: item.negocioNombre ?? 'Recordatorio de pago',
          description: item.mensaje,
          level: DashboardNewsLevel.alert,
        ),
      );
    }
    final pagos = movimientos
        .where((movimiento) => movimiento.tipo == 'pago')
        .toList();
    final ultimoPago = pagos.isEmpty ? null : pagos.first;
    if (ultimoPago != null) {
      news.add(
        DashboardNewsCard(
          icon: Icons.payments_outlined,
          title: 'Pago registrado',
          description:
              'Ultimo pago visible por ${MoneyFormatter.formatCurrency(ultimoPago.monto)}.',
          level: DashboardNewsLevel.success,
        ),
      );
    }
    if (totalDeuda > 0) {
      news.add(
        DashboardNewsCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Saldo pendiente',
          description:
              'Tienes ${MoneyFormatter.formatCurrency(totalDeuda)} pendiente en los datos locales.',
          level: DashboardNewsLevel.critical,
        ),
      );
    }
    if (news.isEmpty) {
      news.add(
        const DashboardNewsCard(
          icon: Icons.check_circle_outline_rounded,
          title: 'Sin alertas personales',
          description: 'No hay recordatorios ni deudas pendientes visibles.',
          level: DashboardNewsLevel.success,
        ),
      );
    }
    return news;
  }

  void _mostrarSeccionActual(String seccion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$seccion esta disponible en este dashboard.')),
    );
  }

  void _abrirRecordatoriosPago() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalDebtRemindersScreen()),
    );
  }
}

class _PersonalDebtGuidanceTeaser extends StatelessWidget {
  final int count;
  final String highestPriority;
  final VoidCallback onTap;

  const _PersonalDebtGuidanceTeaser({
    required this.count,
    required this.highestPriority,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F3EF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD9E8E3)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.tips_and_updates_outlined,
                color: Color(0xFF1F7A6B),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recordatorios disponibles',
                    style: TextStyle(
                      color: Color(0xFF17322C),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count negocio(s) con consejos. Prioridad mayor: $highestPriority.',
                    style: const TextStyle(color: Color(0xFF66756D)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF1F7A6B)),
          ],
        ),
      ),
    );
  }
}

class _PersonalDashboardHero extends StatelessWidget {
  final String nombre;
  final String telefono;

  const _PersonalDashboardHero({required this.nombre, required this.telefono});

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
            child: const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  telefono,
                  style: const TextStyle(color: Color(0xFFDCE9E5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalNewsFeed extends StatelessWidget {
  final List<DashboardNewsCard> news;

  const _PersonalNewsFeed({required this.news});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(
          title: 'Noticias personales',
          subtitle: 'Avisos importantes sobre tus deudas.',
        ),
        const SizedBox(height: 14),
        for (final item in news) ...[item, const SizedBox(height: 10)],
      ],
    );
  }
}

class _BusinessDebtCard extends StatelessWidget {
  final double balance;
  final int movimientos;

  const _BusinessDebtCard({required this.balance, required this.movimientos});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final leading = Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3EF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: Color(0xFF1F7A6B),
            ),
          );
          final info = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppConstants.businessDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF17322C),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$movimientos movimientos registrados',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF66756D)),
                ),
              ],
            ),
          );
          final amount = FittedBox(
            fit: BoxFit.scaleDown,
            alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
            child: Text(
              MoneyFormatter.formatCurrency(balance),
              maxLines: 1,
              style: TextStyle(
                color: balance > 0
                    ? const Color(0xFFB42318)
                    : const Color(0xFF1F7A6B),
                fontWeight: FontWeight.w800,
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [leading, const SizedBox(width: 12), info]),
                const SizedBox(height: 10),
                amount,
              ],
            );
          }

          return Row(
            children: [
              leading,
              const SizedBox(width: 14),
              info,
              const SizedBox(width: 10),
              amount,
            ],
          );
        },
      ),
    );
  }
}

class _PersonalCreditNotices extends StatelessWidget {
  final List<CreditoRecordatorioSqliteModel> items;

  const _PersonalCreditNotices({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Avisos de credito',
          style: TextStyle(
            color: Color(0xFF17322C),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in items)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE7B04B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.negocioNombre ?? 'Negocio',
                  style: const TextStyle(
                    color: Color(0xFF17322C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                if (item.saldoPendiente != null)
                  Text(
                    'Monto pendiente: ${MoneyFormatter.formatCurrency(item.saldoPendiente!, symbol: 'US\$')}',
                  ),
                if (item.fechaLimite != null)
                  Text(
                    'Fecha limite: ${item.fechaLimite!.day}/${item.fechaLimite!.month}/${item.fechaLimite!.year}',
                  ),
                const SizedBox(height: 8),
                Text(item.mensaje),
              ],
            ),
          ),
      ],
    );
  }
}

class _MovimientoPersonalTile extends StatelessWidget {
  final Movimiento movimiento;

  const _MovimientoPersonalTile({required this.movimiento});

  @override
  Widget build(BuildContext context) {
    final esPago = movimiento.tipo == 'pago';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: esPago ? const Color(0xFFD9E8E3) : const Color(0xFFF3D6D0),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          final leading = Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: esPago ? const Color(0xFFE7F3EF) : const Color(0xFFFDEAE5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              esPago ? Icons.payments_outlined : Icons.add_card_outlined,
              color: esPago ? const Color(0xFF1F7A6B) : const Color(0xFFB54708),
            ),
          );
          final info = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esPago ? 'Pago registrado' : 'Deuda agregada',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17322C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${movimiento.fecha.day}/${movimiento.fecha.month}/${movimiento.fecha.year}',
                  style: const TextStyle(color: Color(0xFF66756D)),
                ),
              ],
            ),
          );
          final amount = FittedBox(
            fit: BoxFit.scaleDown,
            alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
            child: Text(
              MoneyFormatter.formatCurrency(movimiento.monto),
              maxLines: 1,
              style: TextStyle(
                color: esPago
                    ? const Color(0xFF1F7A6B)
                    : const Color(0xFFB42318),
                fontWeight: FontWeight.w800,
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [leading, const SizedBox(width: 12), info]),
                const SizedBox(height: 10),
                amount,
              ],
            );
          }

          return Row(
            children: [
              leading,
              const SizedBox(width: 14),
              info,
              const SizedBox(width: 10),
              amount,
            ],
          );
        },
      ),
    );
  }
}

class _EmptyPersonalState extends StatelessWidget {
  final String telefono;

  const _EmptyPersonalState({required this.telefono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE3DED2)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3EF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.history_toggle_off_rounded,
              color: Color(0xFF1F7A6B),
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No hay movimientos para este telefono',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF17322C),
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            telefono,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF66756D)),
          ),
        ],
      ),
    );
  }
}
