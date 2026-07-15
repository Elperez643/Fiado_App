import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/subscription_plans.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/money_formatter.dart';
import '../data/services/api_client.dart';
import '../data/models/subscription_sqlite_model.dart';
import '../data/models/usuario_sqlite_model.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/sync_providers.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/fiado_gradient_card.dart';
import 'subscription_status_screen.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String _billingCycle = BillingCycle.mensual;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);
    final accessAsync = ref.watch(subscriptionStatusProvider);
    final limitAsync = ref.watch(collaboratorLimitProvider);

    if (user?.tipoUsuario != UsuarioSqliteModel.tipoNegocio) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Text('Solo el negocio puede gestionar el plan.'),
          ),
        ),
      );
    }

    final repository = ref.read(subscriptionRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding = AdaptiveLayout.contentInset(
              constraints.maxWidth,
            );
            final subscription = subscriptionAsync.valueOrNull;
            final access = accessAsync.valueOrNull;
            final limit = limitAsync.valueOrNull;
            final selectedCycle = subscription?.billingCycle ?? _billingCycle;
            final plans = repository.obtenerPlanesPorCiclo(_billingCycle);

            return ListView(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                18,
                contentPadding,
                28,
              ),
              children: [
                const FiadoGradientCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.workspace_premium_outlined,
                        color: Colors.white,
                        size: 34,
                      ),
                      SizedBox(height: 22),
                      Text(
                        'Suscripcion',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Planes SaaS en USD, trial gratis y pagos test seguros con Stripe Checkout.',
                        style: TextStyle(
                          color: Color(0xFFDCE9E5),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _CurrentPlanCard(
                  subscription: subscription,
                  trialDaysLeft: access?.trialDaysLeft ?? 0,
                  colaboradoresUsados: limit?.usados ?? 0,
                  colaboradoresLimite: limit?.limite ?? 0,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionStatusScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Ver facturacion mock'),
                ),
                const SizedBox(height: 18),
                _BillingCycleSelector(
                  selected: _billingCycle,
                  onSelected: (cycle) => setState(() => _billingCycle = cycle),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, planConstraints) {
                    final isWide = planConstraints.maxWidth >= 840;
                    if (!isWide) {
                      return Column(
                        children: [
                          for (final price in plans)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PlanCard(
                                price: price,
                                selected:
                                    subscription?.planId == price.planId &&
                                    selectedCycle == price.billingCycle,
                                onSelected: () => _selectPlan(user, price),
                                onStripe: () => _payWithStripe(user, price),
                              ),
                            ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final price in plans)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: _PlanCard(
                                price: price,
                                selected:
                                    subscription?.planId == price.planId &&
                                    selectedCycle == price.billingCycle,
                                onSelected: () => _selectPlan(user, price),
                                onStripe: () => _payWithStripe(user, price),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _selectPlan(
    UsuarioSqliteModel? user,
    SubscriptionPlanPrice price,
  ) async {
    if (user?.id == null) return;
    await ref
        .read(subscriptionRepositoryProvider)
        .seleccionarPlan(
          user!.id!,
          price.planId,
          billingCycle: price.billingCycle,
        );
    ref.invalidate(currentSubscriptionProvider);
    ref.invalidate(collaboratorLimitProvider);
  }

  Future<void> _payWithStripe(
    UsuarioSqliteModel? user,
    SubscriptionPlanPrice price,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (user?.id == null) return;
    try {
      await _selectPlan(user, price);
      final cloudReady = await ref
          .read(cloudAuthServiceProvider)
          .isCloudAuthenticated()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (!cloudReady) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Para pagar una suscripcion necesitas conexion a internet.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      final checkoutUrl = await ref
          .read(paymentServiceProvider)
          .createStripeCheckoutSession(
            planId: price.planId,
            billingCycle: price.billingCycle,
          );
      if (!mounted) return;
      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!launched) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Stripe Checkout.')),
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo iniciar Stripe Checkout: $error')),
      );
    }
  }
}

class _BillingCycleSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _BillingCycleSelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final cycle in BillingCycle.all)
          ChoiceChip(
            label: Text(_cycleLabel(cycle)),
            selected: selected == cycle,
            onSelected: (_) => onSelected(cycle),
          ),
      ],
    );
  }

  String _cycleLabel(String cycle) {
    final discount = BillingCycle.discountPercent(cycle);
    final label = BillingCycle.label(cycle);
    return discount == 0 ? label : '$label - $discount% ahorro';
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionSqliteModel? subscription;
  final int trialDaysLeft;
  final int colaboradoresUsados;
  final int colaboradoresLimite;

  const _CurrentPlanCard({
    required this.subscription,
    required this.trialDaysLeft,
    required this.colaboradoresUsados,
    required this.colaboradoresLimite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = subscription?.finalPrice ?? 0;
    final currency =
        subscription?.currencyCode ?? SubscriptionPlans.currencyCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan actual: ${subscription?.planNombre ?? 'Sin plan'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${MoneyFormatter.formatCurrency(price, symbol: '$currency ')} / ${BillingCycle.label(subscription?.billingCycle ?? BillingCycle.mensual).toLowerCase()}',
            ),
            Text(
              'Colaboradores usados: $colaboradoresUsados/$colaboradoresLimite',
            ),
            Text('Dias restantes trial: $trialDaysLeft'),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Activar pago proximamente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlanPrice price;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onStripe;

  const _PlanCard({
    required this.price,
    required this.selected,
    required this.onSelected,
    required this.onStripe,
  });

  @override
  Widget build(BuildContext context) {
    final plan = SubscriptionPlans.byId(price.planId);
    final theme = Theme.of(context);
    final borderColor = selected || plan.recomendado
        ? AppColors.primary
        : AppColors.border;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.nombre,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (plan.recomendado)
                    const _Badge(label: 'Recomendado')
                  else if (selected)
                    const Icon(Icons.check_circle, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 12),
              if (price.hasDiscount)
                Text(
                  MoneyFormatter.formatCurrency(
                    price.originalPrice,
                    symbol: '${price.currencyCode} ',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF7A8A84),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                MoneyFormatter.formatCurrency(
                  price.finalPrice,
                  symbol: '${price.currencyCode} ',
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                BillingCycle.label(price.billingCycle),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (price.hasDiscount) ...[
                const SizedBox(height: 8),
                Text(
                  'Ahorras ${price.discountPercent}% - ${MoneyFormatter.formatCurrency(price.ahorro, symbol: '${price.currencyCode} ')}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _BenefitLine(
                text: 'Hasta ${plan.maxColaboradores} colaboradores',
              ),
              _BenefitLine(text: plan.clientesRecomendados),
              for (final benefit in plan.beneficios)
                _BenefitLine(text: benefit),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSelected,
                  child: Text(selected ? 'Plan seleccionado' : 'Seleccionar'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onStripe,
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('Pagar con Stripe (modo prueba)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitLine extends StatelessWidget {
  final String text;

  const _BenefitLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
