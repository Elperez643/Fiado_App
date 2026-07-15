import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_gradients.dart';
import '../core/theme/app_shadows.dart';
import '../data/models/usuario_sqlite_model.dart';
import '../presentation/providers/auth_providers.dart';
import '../widgets/adaptive_layout.dart';
import 'colaborador_dashboard_screen.dart';
import 'personal_portal_screen.dart';
import 'principal_screen.dart';

class OnboardingAssistantScreen extends ConsumerStatefulWidget {
  final UsuarioSqliteModel user;
  final bool manual;

  const OnboardingAssistantScreen({
    super.key,
    required this.user,
    this.manual = false,
  });

  @override
  ConsumerState<OnboardingAssistantScreen> createState() =>
      _OnboardingAssistantScreenState();

  static Widget destinationFor(UsuarioSqliteModel user) {
    if (user.tipoUsuario == UsuarioSqliteModel.tipoPersonal) {
      return PersonalPortalScreen(telefono: user.telefono);
    }
    if (user.tipoUsuario == UsuarioSqliteModel.tipoColaborador) {
      return const ColaboradorDashboardScreen();
    }
    return const PrincipalScreen();
  }

  static Future<void> openAfterAuth({
    required BuildContext context,
    required WidgetRef ref,
    required UsuarioSqliteModel user,
  }) async {
    var shouldShow = false;
    try {
      debugPrint(
        '[post-login] rol=${user.tipoUsuario} userId=${user.id} negocioId=${user.negocioId ?? user.id}',
      );
      if (user.id != null) {
        var onboardingGateReady = true;
        if (user.tipoUsuario == UsuarioSqliteModel.tipoNegocio) {
          final access = await ref
              .read(subscriptionRepositoryProvider)
              .validarAccesoNegocio(user.id!);
          onboardingGateReady = access.hasAccess;
          debugPrint('[post-login] acceso negocio=${access.hasAccess}');
        }
        if (onboardingGateReady) {
          shouldShow = await ref
              .read(userOnboardingRepositoryProvider)
              .debeMostrarOnboarding(user.id!, user.tipoUsuario);
        }
      }
      debugPrint('[post-login] onboarding requerido=$shouldShow');
    } catch (error) {
      shouldShow = false;
      debugPrint('[post-login] error onboarding, usando dashboard: $error');
    }
    if (!context.mounted) return;
    debugPrint(
      '[post-login] navegando a ${shouldShow ? 'onboarding' : user.tipoUsuario}',
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => shouldShow
            ? OnboardingAssistantScreen(user: user)
            : destinationFor(user),
      ),
      (_) => false,
    );
  }
}

class _OnboardingAssistantScreenState
    extends ConsumerState<OnboardingAssistantScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final steps = onboardingStepsForTipo(widget.user.tipoUsuario);
    final step = steps[_index];
    final last = _index == steps.length - 1;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = AdaptiveLayout.contentInset(constraints.maxWidth);
            final wide = constraints.maxWidth >= 850;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(padding, 18, padding, 24),
              child: AdaptiveWidth(
                maxWidth: 1120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OnboardingTopBar(
                      title: _titleFor(widget.user.tipoUsuario),
                      current: _index + 1,
                      total: steps.length,
                      manual: widget.manual,
                      onSkip: _skipOrClose,
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _OnboardingSlide(
                        key: ValueKey('${widget.user.tipoUsuario}_$_index'),
                        step: step,
                        progress: (_index + 1) / steps.length,
                        wide: wide,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _OnboardingActions(
                      canGoBack: _index > 0,
                      last: last,
                      manual: widget.manual,
                      onBack: () => setState(() => _index--),
                      onNext: last
                          ? _completeOrClose
                          : () => setState(() => _index++),
                      onSkip: _skipOrClose,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _completeOrClose() async {
    if (!widget.manual && widget.user.id != null) {
      await ref
          .read(userOnboardingRepositoryProvider)
          .marcarCompletado(widget.user.id!, widget.user.tipoUsuario);
      ref.invalidate(shouldShowOnboardingProvider);
    }
    if (!mounted) return;
    _goNext();
  }

  Future<void> _skipOrClose() async {
    if (!widget.manual && widget.user.id != null) {
      await ref
          .read(userOnboardingRepositoryProvider)
          .marcarOmitido(widget.user.id!, widget.user.tipoUsuario);
      ref.invalidate(shouldShowOnboardingProvider);
    }
    if (!mounted) return;
    _goNext();
  }

  void _goNext() {
    if (widget.manual) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingAssistantScreen.destinationFor(widget.user),
      ),
    );
  }

  String _titleFor(String tipoUsuario) {
    switch (tipoUsuario) {
      case UsuarioSqliteModel.tipoPersonal:
        return 'Guia para tu cuenta personal';
      case UsuarioSqliteModel.tipoColaborador:
        return 'Guia para colaboradores';
      default:
        return 'Guia inicial para tu negocio';
    }
  }
}

class _OnboardingTopBar extends StatelessWidget {
  final String title;
  final int current;
  final int total;
  final bool manual;
  final VoidCallback onSkip;

  const _OnboardingTopBar({
    required this.title,
    required this.current,
    required this.total,
    required this.manual,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Paso $current de $total',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onSkip,
          child: Text(manual ? 'Cerrar' : 'Omitir'),
        ),
      ],
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final OnboardingStepInfo step;
  final double progress;
  final bool wide;

  const _OnboardingSlide({
    super.key,
    required this.step,
    required this.progress,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _OnboardingVisual(step: step, progress: progress);
    final content = _OnboardingContent(step: step);

    return Container(
      padding: EdgeInsets.all(wide ? 26 : 18),
      decoration: BoxDecoration(
        gradient: AppGradients.surfaceGlow,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: visual),
                const SizedBox(width: 26),
                Expanded(child: content),
              ],
            )
          : Column(children: [visual, const SizedBox(height: 22), content]),
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  final OnboardingStepInfo step;
  final double progress;

  const _OnboardingVisual({required this.step, required this.progress});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 260),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: _gradientFor(step.iconName),
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShadows.elevated,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -18,
              child: _SoftCircle(size: 124, alpha: 0.12),
            ),
            Positioned(
              left: -28,
              bottom: -24,
              child: _SoftCircle(size: 148, alpha: 0.10),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    _iconFor(step.iconName),
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 48),
                _MiniDashboardPreview(iconName: step.iconName),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingContent extends StatelessWidget {
  final OnboardingStepInfo step;

  const _OnboardingContent({required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          step.description,
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.45,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (step.highlights.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in step.highlights) _HighlightChip(label: item),
            ],
          ),
        ],
        if (step.message.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.tips_and_updates_outlined,
                  color: AppColors.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OnboardingActions extends StatelessWidget {
  final bool canGoBack;
  final bool last;
  final bool manual;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _OnboardingActions({
    required this.canGoBack,
    required this.last,
    required this.manual,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final back = OutlinedButton.icon(
          onPressed: canGoBack ? onBack : null,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Atras'),
        );
        final skip = TextButton(
          onPressed: onSkip,
          child: Text(manual ? 'Cerrar' : 'Omitir'),
        );
        final next = FilledButton.icon(
          onPressed: onNext,
          icon: Icon(last ? Icons.rocket_launch_outlined : Icons.arrow_forward),
          label: Text(last ? 'Comenzar' : 'Siguiente'),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              next,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: back),
                  const SizedBox(width: 8),
                  Expanded(child: skip),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            skip,
            const Spacer(),
            back,
            const SizedBox(width: 10),
            next,
          ],
        );
      },
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final String label;

  const _HighlightChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.success,
            size: 18,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDashboardPreview extends StatelessWidget {
  final String iconName;

  const _MiniDashboardPreview({required this.iconName});

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(iconName);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _PreviewMetric(icon: icon, width: 0.54),
              const SizedBox(width: 10),
              _PreviewMetric(icon: Icons.trending_up_rounded, width: 0.36),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _PreviewLine(width: 92),
              const SizedBox(width: 10),
              _PreviewLine(width: 56),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  final IconData icon;
  final double width;

  const _PreviewMetric({required this.icon, required this.width});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: (width * 100).round(),
      child: Container(
        height: 74,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  final double width;

  const _PreviewLine({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  final double size;
  final double alpha;

  const _SoftCircle({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

IconData _iconFor(String name) {
  switch (name) {
    case 'account_balance_wallet':
      return Icons.account_balance_wallet_outlined;
    case 'event':
      return Icons.event_available_outlined;
    case 'receipt':
      return Icons.receipt_long_outlined;
    case 'notifications':
      return Icons.notifications_active_outlined;
    case 'lock':
      return Icons.lock_outline;
    case 'inventory':
      return Icons.inventory_2_outlined;
    case 'checklist':
      return Icons.checklist_outlined;
    case 'approval':
      return Icons.approval_outlined;
    case 'groups':
      return Icons.groups_2_outlined;
    case 'payments':
      return Icons.payments_outlined;
    case 'engineering':
      return Icons.engineering_outlined;
    case 'dashboard':
      return Icons.dashboard_customize_outlined;
    case 'score':
      return Icons.speed_outlined;
    case 'campaigns':
      return Icons.campaign_outlined;
    case 'copilot':
      return Icons.auto_awesome_outlined;
    default:
      return Icons.auto_stories_outlined;
  }
}

Gradient _gradientFor(String name) {
  return switch (name) {
    'score' || 'event' => AppGradients.alert,
    'copilot' || 'dashboard' => AppGradients.executive,
    'campaigns' || 'receipt' => AppGradients.trust,
    _ => AppGradients.executive,
  };
}
