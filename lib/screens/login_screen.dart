import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../data/models/usuario_sqlite_model.dart';
import '../data/repositories/auth_repository.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../presentation/providers/sync_providers.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/fiado_gradient_card.dart';
import 'backend_settings_screen.dart';
import 'onboarding_assistant_screen.dart';
import 'register_screen.dart';

enum _LoginMode { personal, negocios, colaborador }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usuarioController = TextEditingController();
  final _claveController = TextEditingController();
  _LoginMode _modo = _LoginMode.negocios;
  bool _ocultarClave = true;
  bool _navegando = false;

  @override
  void dispose() {
    _usuarioController.dispose();
    _claveController.dispose();
    super.dispose();
  }

  void _cambiarModo(_LoginMode modo) {
    setState(() {
      _modo = modo;
      _claveController.clear();
      _ocultarClave = modo != _LoginMode.personal;
    });
  }

  void _mostrarError([String? mensaje]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje ?? AuthRepository.invalidCredentialsMessage),
      ),
    );
  }

  String _mensajeLoginError(Object error) {
    final raw = error.toString();
    if (raw.contains(AuthRepository.invalidCredentialsMessage)) {
      return AuthRepository.invalidCredentialsMessage;
    }
    if (raw.contains('Fiado App Web requiere')) {
      return raw.split(':').last.trim();
    }
    debugPrint('[login] error tecnico oculto al usuario: $raw');
    return AuthRepository.invalidCredentialsMessage;
  }

  Future<void> _iniciarSesion() async {
    if (_navegando) return;
    setState(() => _navegando = true);
    try {
      await _iniciarSesionCore();
    } finally {
      if (mounted) setState(() => _navegando = false);
    }
  }

  Future<void> _iniciarSesionCore() async {
    final usuario = _usuarioController.text.trim();
    final clave = _claveController.text.trim();
    debugPrint(
      '[login] iniciado modo=${_modo.name} usuario=${usuario.isEmpty ? 'vacio' : 'informado'}',
    );

    try {
      final authRepository = ref.read(authRepositoryProvider);
      final hadLocalUser =
          !kIsWeb &&
          usuario.isNotEmpty &&
          await authRepository.obtenerUsuarioPorTelefono(usuario) != null;
      final authUser = await ref
          .read(loginControllerProvider)
          .login(usuario, clave);

      if (!mounted) return;
      debugPrint(
        '[login] exitoso rol=${authUser.tipoUsuario} userId=${authUser.id} negocioId=${authUser.negocioId ?? authUser.id}',
      );
      final shouldWaitInitialRestore =
          !kIsWeb && !hadLocalUser && authUser.remoteId != null;
      if (shouldWaitInitialRestore) {
        await _ensureCloudLinkAfterLocalLogin(
          authUser,
          usuario,
          clave,
          waitForRestore: true,
        );
        if (!mounted) return;
      } else {
        await _ensureCloudLinkAfterLocalLogin(authUser, usuario, clave);
        if (!mounted) return;
      }

      await OnboardingAssistantScreen.openAfterAuth(
        context: context,
        ref: ref,
        user: authUser,
      );
    } catch (error) {
      debugPrint('[login] error modo=${_modo.name}: $error');
      await ref.read(authStateProvider.notifier).refresh();
      if (!mounted) return;
      _mostrarError(_mensajeLoginError(error));
    }
  }

  Future<void> _ensureCloudLinkAfterLocalLogin(
    UsuarioSqliteModel authUser,
    String telefono,
    String password, {
    bool waitForRestore = false,
  }) async {
    final cloudAuthService = ref.read(cloudAuthServiceProvider);
    final hasCloudToken = await cloudAuthService.isCloudAuthenticated();
    if (hasCloudToken && authUser.remoteId != null) {
      final syncNotifier = ref.read(syncUserStatusProvider.notifier);
      await syncNotifier.refresh();
      if (waitForRestore) {
        await syncNotifier.runInitialRestore();
        _refreshRestoredDataProviders();
      } else {
        await syncNotifier.runAutoSyncNow();
      }
      return;
    }
    await _programarLoginCloud(authUser, telefono, password);
  }

  void _refreshRestoredDataProviders() {
    ref.invalidate(clientesProvider);
    ref.invalidate(movimientosProvider);
    ref.invalidate(productosProvider);
    ref.invalidate(billableProductsProvider);
    ref.invalidate(inventoryInsightsProvider);
    ref.invalidate(inventoryDirtyMetricsCountProvider);
    ref.invalidate(inventoryActiveProductsCountProvider);
    ref.invalidate(inventoryCachedMetricsCountProvider);
    ref.invalidate(collectionInsightsProvider);
    ref.invalidate(cuentasPorCobrarProvider);
    ref.invalidate(ciclosMoraProvider);
    ref.invalidate(ciclosBloqueadosProvider);
    ref.invalidate(recordatoriosCreditoProvider);
    ref.invalidate(solicitudesPendientesProvider);
    ref.invalidate(solicitudesPendientesCountProvider);
    ref.invalidate(solicitudesColaboradorProvider);
    ref.invalidate(auditoriasNegocioProvider);
    ref.invalidate(auditoriasColaboradorProvider);
    ref.invalidate(auditoriasPendientesProvider);
    ref.invalidate(businessRecommendationsProvider);
    ref.invalidate(personalDebtRemindersProvider);
  }

  Future<void> _programarLoginCloud(
    UsuarioSqliteModel authUser,
    String telefono,
    String password,
  ) async {
    final cloudAuthService = ref.read(cloudAuthServiceProvider);
    final authRepository = ref.read(authRepositoryProvider);
    final authNotifier = ref.read(authStateProvider.notifier);
    final syncNotifier = ref.read(syncUserStatusProvider.notifier);
    try {
      var result = await cloudAuthService
          .loginCloud(phone: telefono, password: password)
          .timeout(const Duration(seconds: 15));
      if ((!result.success || result.user == null) &&
          authUser.tipoUsuario != UsuarioSqliteModel.tipoColaborador) {
        result = await cloudAuthService
            .linkLocalUserToCloud(
              phone: authUser.telefono,
              password: password,
              name: authUser.nombre,
              role: authUser.tipoUsuario,
              businessName: _businessNameForCloud(authUser),
            )
            .timeout(const Duration(seconds: 20));
      }
      if (result.success) {
        if (result.user != null) {
          final linkedUser = await authRepository
              .vincularUsuarioCloudPorTelefono(
                telefono: telefono,
                cloudUser: result.user!,
                jwtToken: result.token,
              );
          if (linkedUser != null) {
            authNotifier.setLocalUser(linkedUser);
          }
        }
        await syncNotifier.refresh();
        await syncNotifier.runAutoSyncNow();
        debugPrint('[login-cloud] cuenta actualizada');
        return;
      }
      await syncNotifier.refresh();
      await syncNotifier.setAuthConnectionError(
        result.userMessage ?? 'No se pudo actualizar',
      );
      debugPrint('[login-cloud] pendiente silencioso: ${result.userMessage}');
    } catch (error) {
      await syncNotifier.refresh();
      debugPrint('[login-cloud] best-effort omitido: $error');
    }
  }

  String? _businessNameForCloud(UsuarioSqliteModel user) {
    if (user.tipoUsuario != UsuarioSqliteModel.tipoNegocio) return null;
    final separator = user.nombre.indexOf(' - ');
    if (separator <= 0) return user.nombre;
    return user.nombre.substring(0, separator).trim();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = AdaptiveLayout.horizontalPadding(
              constraints.maxWidth,
            );
            final isWide = AdaptiveLayout.isTabletOrWider(constraints.maxWidth);

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                24,
              ),
              child: AdaptiveWidth(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LoginHero(isWide: isWide),
                      const SizedBox(height: 18),
                      Container(
                        padding: EdgeInsets.all(isWide ? 24 : 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 22,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tipo de acceso',
                              style: textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF17322C),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            isWide
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: _modeCard(_LoginMode.personal),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _modeCard(_LoginMode.negocios),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _modeCard(
                                          _LoginMode.colaborador,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _modeCard(_LoginMode.personal),
                                      const SizedBox(height: 12),
                                      _modeCard(_LoginMode.negocios),
                                      const SizedBox(height: 12),
                                      _modeCard(_LoginMode.colaborador),
                                    ],
                                  ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _usuarioController,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                labelText: _modo == _LoginMode.negocios
                                    ? 'Telefono o usuario beta'
                                    : 'Usuario o telefono',
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _claveController,
                              obscureText:
                                  _modo != _LoginMode.personal && _ocultarClave,
                              keyboardType: TextInputType.text,
                              onSubmitted: (_) => _iniciarSesion(),
                              decoration: InputDecoration(
                                labelText: _modo == _LoginMode.personal
                                    ? 'Contrasena o telefono'
                                    : 'Contrasena',
                                prefixIcon: Icon(
                                  _modo == _LoginMode.personal
                                      ? Icons.phone_outlined
                                      : Icons.lock_outline,
                                ),
                                suffixIcon: _modo != _LoginMode.personal
                                    ? IconButton(
                                        icon: Icon(
                                          _ocultarClave
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _ocultarClave = !_ocultarClave;
                                          });
                                        },
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _navegando ? null : _iniciarSesion,
                                icon: _navegando
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login_rounded),
                                label: Text(
                                  _navegando
                                      ? 'Entrando...'
                                      : _modo == _LoginMode.negocios
                                      ? 'Entrar al negocio'
                                      : _modo == _LoginMode.colaborador
                                      ? 'Entrar como colaborador'
                                      : 'Ver mi historial',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text('Crear cuenta'),
                              ),
                            ),
                            if (kDebugMode) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const BackendSettingsScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.dns_outlined),
                                  label: const Text('Configurar servidor'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _modeCard(_LoginMode modo) {
    final selected = _modo == modo;
    final isPersonal = modo == _LoginMode.personal;
    final isCollaborator = modo == _LoginMode.colaborador;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _cambiarModo(modo),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.successSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                isPersonal
                    ? Icons.badge_outlined
                    : isCollaborator
                    ? Icons.engineering_outlined
                    : Icons.storefront_outlined,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersonal
                        ? 'Personal'
                        : isCollaborator
                        ? 'Colaborador'
                        : 'Negocios',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPersonal
                        ? 'Solo tu historial'
                        : isCollaborator
                        ? 'Acceso limitado'
                        : 'Acceso completo',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  final bool isWide;

  const _LoginHero({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return FiadoGradientCard(
      padding: EdgeInsets.all(isWide ? 28 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(height: isWide ? 34 : 24),
          const Text(
            'Fiado App',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Entra como negocio para administrar todo o como cliente para consultar solo tu historial.',
            style: TextStyle(
              color: Color(0xFFDCE9E5),
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
