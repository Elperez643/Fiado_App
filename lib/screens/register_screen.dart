import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/subscription_plans.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/money_formatter.dart';
import '../data/models/usuario_sqlite_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/services/cloud_auth_service.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/sync_providers.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/fiado_gradient_card.dart';
import 'onboarding_assistant_screen.dart';

enum _RegisterMode { personal, negocio }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nombreController = TextEditingController();
  final _negocioController = TextEditingController();
  final _adminController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _RegisterMode _mode = _RegisterMode.negocio;
  String _planId = SubscriptionPlans.basico.id;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nombreController.dispose();
    _negocioController.dispose();
    _adminController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final telefono = _telefonoController.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(telefono)) {
      _showMessage('El telefono debe tener exactamente 10 digitos.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_mode == _RegisterMode.personal) {
        final nombre = _nombreController.text.trim();
        if (nombre.isEmpty) {
          _showMessage('Completa el nombre.');
          return;
        }

        await ref
            .read(registerControllerProvider)
            .registrarUsuarioPersonal(nombre, telefono);
        debugPrint('[Register] localCreated=true tipo=personal');
        final authUser = await ref
            .read(loginControllerProvider)
            .login(telefono, telefono);
        await _tryConnectCloudAfterRegistration(
          localUser: authUser,
          password: telefono,
          personalName: nombre,
        );
        if (!mounted) return;
        await OnboardingAssistantScreen.openAfterAuth(
          context: context,
          ref: ref,
          user: authUser,
        );
        return;
      }

      final negocio = _negocioController.text.trim();
      final admin = _adminController.text.trim();
      final password = _passwordController.text.trim();
      final confirm = _confirmPasswordController.text.trim();

      if (negocio.isEmpty || admin.isEmpty) {
        _showMessage('Completa el nombre del negocio y administrador.');
        return;
      }

      if (password.isEmpty) {
        _showMessage('La contrasena es obligatoria.');
        return;
      }

      if (password != confirm) {
        _showMessage('Las contrasenas no coinciden.');
        return;
      }

      // TODO: Rehabilitar backend, Azul y validaciones de suscripcion cuando
      // finalice la estabilizacion local-first.
      await ref
          .read(registerControllerProvider)
          .registrarUsuarioNegocio(
            negocio,
            admin,
            telefono,
            password,
            planId: _planId,
          );
      debugPrint('[Register] localCreated=true tipo=negocio');
      final authUser = await ref
          .read(loginControllerProvider)
          .login(telefono, password);
      await _tryConnectCloudAfterRegistration(
        localUser: authUser,
        password: password,
        businessName: negocio,
        ownerName: admin,
      );
      if (!mounted) return;
      await OnboardingAssistantScreen.openAfterAuth(
        context: context,
        ref: ref,
        user: authUser,
      );
    } catch (error) {
      final raw = error.toString();
      _showMessage(
        raw.contains(AuthRepository.duplicateUserMessage) ||
                raw.contains('Ya existe')
            ? AuthRepository.duplicateUserMessage
            : raw.contains('registrar un negocio')
            ? 'Para registrar un negocio necesitas conexion a internet. Luego podras usar Fiado App sin conexion.'
            : raw.contains('tarjeta')
            ? raw.replaceFirst('Bad state: ', '')
            : raw.contains('limite')
            ? raw.replaceFirst('Bad state: ', '')
            : 'No se pudo crear la cuenta.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _tryConnectCloudAfterRegistration({
    required UsuarioSqliteModel localUser,
    required String password,
    String? personalName,
    String? businessName,
    String? ownerName,
  }) async {
    try {
      debugPrint('[Register] remoteAttempt=true');
      final cloudAuthService = ref.read(cloudAuthServiceProvider);
      CloudAuthenticatedUser cloudUser;
      String? token;
      if (localUser.tipoUsuario == UsuarioSqliteModel.tipoPersonal) {
        try {
          final result = await cloudAuthService
              .registerPersonal(
                name: personalName ?? localUser.nombre,
                phone: localUser.telefono,
                password: password,
              )
              .timeout(const Duration(seconds: 15));
          cloudUser = result.user;
          token = result.token;
        } catch (_) {
          final result = await cloudAuthService
              .loginCloud(phone: localUser.telefono, password: password)
              .timeout(const Duration(seconds: 15));
          final linked = result.success && result.user != null
              ? result
              : await cloudAuthService
                    .linkLocalUserToCloud(
                      phone: localUser.telefono,
                      password: password,
                      name: localUser.nombre,
                      role: localUser.tipoUsuario,
                    )
                    .timeout(const Duration(seconds: 20));
          if (!linked.success || linked.user == null) {
            await ref
                .read(syncUserStatusProvider.notifier)
                .setAuthConnectionError(
                  linked.userMessage ?? 'No se pudo actualizar',
                );
            return;
          }
          cloudUser = linked.user!;
          token = linked.token;
        }
      } else if (localUser.tipoUsuario == UsuarioSqliteModel.tipoNegocio) {
        try {
          final result = await cloudAuthService
              .startBusinessRegistration(
                ownerName: ownerName ?? localUser.nombre,
                businessName: businessName ?? localUser.nombre,
                phone: localUser.telefono,
                password: password,
              )
              .timeout(const Duration(seconds: 15));
          cloudUser = result.user;
          token = result.token;
        } catch (_) {
          final result = await cloudAuthService
              .loginCloud(phone: localUser.telefono, password: password)
              .timeout(const Duration(seconds: 15));
          final linked = result.success && result.user != null
              ? result
              : await cloudAuthService
                    .linkLocalUserToCloud(
                      phone: localUser.telefono,
                      password: password,
                      name: localUser.nombre,
                      role: localUser.tipoUsuario,
                      businessName: businessName ?? localUser.nombre,
                    )
                    .timeout(const Duration(seconds: 20));
          if (!linked.success || linked.user == null) {
            await ref
                .read(syncUserStatusProvider.notifier)
                .setAuthConnectionError(
                  linked.userMessage ?? 'No se pudo actualizar',
                );
            return;
          }
          cloudUser = linked.user!;
          token = linked.token;
        }
      } else {
        return;
      }

      final linkedUser = await ref
          .read(authRepositoryProvider)
          .vincularUsuarioCloudPorTelefono(
            telefono: localUser.telefono,
            cloudUser: cloudUser,
            jwtToken: token,
          );
      if (linkedUser != null) {
        ref.read(authStateProvider.notifier).setLocalUser(linkedUser);
      }
      await ref.read(syncUserStatusProvider.notifier).refresh();
      await ref.read(syncUserStatusProvider.notifier).runAutoSyncNow();
      final status = ref.read(syncUserStatusProvider).valueOrNull;
      debugPrint(
        '[register-cloud] cloud token saved ${token?.trim().isNotEmpty == true}',
      );
      debugPrint(
        '[register-cloud] sync status final=${status?.shortMessage ?? 'unknown'}',
      );
    } catch (error) {
      await ref.read(syncUserStatusProvider.notifier).refresh();
      final status = ref.read(syncUserStatusProvider).valueOrNull;
      debugPrint('[register-cloud] cloud token saved false');
      debugPrint('[register-cloud] conexion remota omitida: $error');
      debugPrint(
        '[register-cloud] sync status final=${status?.shortMessage ?? 'unknown'}',
      );
    }
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FiadoGradientCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            color: Colors.white,
                            size: 34,
                          ),
                          SizedBox(height: 22),
                          Text(
                            'Crear cuenta',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Elige cuenta Personal o Negocio. Los colaboradores se crean dentro del negocio.',
                            style: TextStyle(
                              color: Color(0xFFDCE9E5),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: EdgeInsets.all(isWide ? 24 : 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          isWide
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: _modeCard(_RegisterMode.personal),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _modeCard(_RegisterMode.negocio),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _modeCard(_RegisterMode.personal),
                                    const SizedBox(height: 12),
                                    _modeCard(_RegisterMode.negocio),
                                  ],
                                ),
                          const SizedBox(height: 18),
                          if (_mode == _RegisterMode.personal)
                            TextField(
                              controller: _nombreController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            )
                          else ...[
                            TextField(
                              controller: _negocioController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del negocio',
                                prefixIcon: Icon(Icons.storefront_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _adminController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del administrador',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextField(
                            controller: _telefonoController,
                            keyboardType: TextInputType.number,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Telefono',
                              prefixIcon: Icon(Icons.phone_outlined),
                              counterText: '',
                            ),
                          ),
                          if (_mode == _RegisterMode.negocio) ...[
                            const SizedBox(height: 14),
                            _passwordField(
                              controller: _passwordController,
                              label: 'Contrasena',
                            ),
                            const SizedBox(height: 14),
                            _passwordField(
                              controller: _confirmPasswordController,
                              label: 'Confirmar contrasena',
                            ),
                            const SizedBox(height: 18),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Plan inicial',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF17322C),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            RadioGroup<String>(
                              groupValue: _planId,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _planId = value);
                              },
                              child: Column(
                                children: [
                                  for (final plan in SubscriptionPlans.all)
                                    RadioListTile<String>(
                                      value: plan.id,
                                      title: Text(
                                        '${plan.nombre} ${MoneyFormatter.formatCurrency(plan.precioMensual, symbol: 'USD ')} / ${plan.maxColaboradores} colaboradores',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'El primer mes queda en trial gratis aunque selecciones un plan.',
                              style: TextStyle(color: Color(0xFF66756D)),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _loading ? null : _registrar,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_alt_1),
                              label: Text(
                                _mode == _RegisterMode.personal
                                    ? 'Crear cuenta personal'
                                    : 'Crear cuenta negocio',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Ya tengo cuenta'),
                          ),
                        ],
                      ),
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

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
      ),
    );
  }

  Widget _modeCard(_RegisterMode mode) {
    final selected = _mode == mode;
    final personal = mode == _RegisterMode.personal;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => setState(() => _mode = mode),
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
            Icon(
              personal ? Icons.badge_outlined : Icons.storefront_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                personal ? 'Personal' : 'Negocio',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
