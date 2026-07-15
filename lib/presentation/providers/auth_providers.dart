import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/crash_diagnostics_service.dart';
import '../../core/permissions/app_permissions.dart';
import '../../data/models/subscription_sqlite_model.dart';
import '../../data/models/usuario_sqlite_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../data/repositories/user_onboarding_repository.dart';
import 'sync_providers.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

final userOnboardingRepositoryProvider = Provider<UserOnboardingRepository>((
  ref,
) {
  return UserOnboardingRepository();
});

class OnboardingStepInfo {
  final String title;
  final String description;
  final String iconName;
  final List<String> highlights;
  final String message;

  const OnboardingStepInfo({
    required this.title,
    required this.description,
    required this.iconName,
    this.highlights = const [],
    this.message = '',
  });
}

final shouldShowOnboardingProvider = FutureProvider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.id == null) return Future.value(false);
  return ref
      .read(userOnboardingRepositoryProvider)
      .debeMostrarOnboarding(user!.id!, user.tipoUsuario);
});

final onboardingStepsProvider = Provider<List<OnboardingStepInfo>>((ref) {
  final tipo = ref.watch(currentUserProvider)?.tipoUsuario;
  return onboardingStepsForTipo(tipo);
});

List<OnboardingStepInfo> onboardingStepsForTipo(String? tipoUsuario) {
  switch (tipoUsuario) {
    case UsuarioSqliteModel.tipoPersonal:
      return const [
        OnboardingStepInfo(
          title: 'Bienvenido a Fiado App',
          description: 'Consulta y organiza tus compras a credito.',
          iconName: 'account_balance_wallet',
        ),
        OnboardingStepInfo(
          title: 'Revisa tu historial',
          description: 'Ten a mano tus movimientos importantes.',
          iconName: 'receipt',
          highlights: ['Compras', 'Pagos', 'Comprobantes'],
        ),
        OnboardingStepInfo(
          title: 'Organiza tus deudas',
          description: 'Consulta tus saldos por negocio sin mezclar datos.',
          iconName: 'event',
          highlights: ['Recordatorios', 'Vencimientos', 'Consejos'],
        ),
        OnboardingStepInfo(
          title: 'Mejora tu historial',
          description:
              'Pagar a tiempo ayuda a mantener una mejor relacion con los negocios.',
          iconName: 'notifications',
          message:
              'Fiado App recomienda organizar tus pagos con tiempo y guardar tus comprobantes.',
        ),
      ];
    case UsuarioSqliteModel.tipoColaborador:
      return const [
        OnboardingStepInfo(
          title: 'Bienvenido',
          description: 'Gestiona inventario y operaciones del negocio.',
          iconName: 'lock',
        ),
        OnboardingStepInfo(
          title: 'Controla productos',
          description: 'Trabaja con datos claros y editables.',
          iconName: 'inventory',
          highlights: ['Inventario', 'Ubicaciones', 'Codigo de barras'],
        ),
        OnboardingStepInfo(
          title: 'Realiza auditorias',
          description: 'Mantén el inventario confiable para el negocio.',
          iconName: 'checklist',
          highlights: ['Auditorias diarias', 'Auditorias semanales'],
        ),
        OnboardingStepInfo(
          title: 'Trabaja con autorizaciones',
          description: 'Los cambios sensibles se envian al negocio.',
          iconName: 'approval',
          highlights: ['Solicitudes', 'Aprobaciones'],
        ),
      ];
    case UsuarioSqliteModel.tipoNegocio:
    default:
      return const [
        OnboardingStepInfo(
          title: 'Bienvenido a Fiado App',
          description:
              'Administra clientes, inventario y fiados desde un solo lugar.',
          iconName: 'dashboard',
        ),
        OnboardingStepInfo(
          title: 'Controla quien paga',
          description: 'Identifica riesgos antes de volver a fiar.',
          iconName: 'score',
          highlights: [
            'Score Inteligente',
            'Cobranza Inteligente',
            'Ciclos 30/45/60',
          ],
        ),
        OnboardingStepInfo(
          title: 'Controla tu inventario',
          description: 'Conoce exactamente que tienes disponible.',
          iconName: 'inventory',
          highlights: [
            'Codigo de barras',
            'Ubicaciones',
            'Inventario Inteligente',
            'Auditorias',
          ],
        ),
        OnboardingStepInfo(
          title: 'Vende mas',
          description: 'Promociona productos sin perder tiempo.',
          iconName: 'campaigns',
          highlights: [
            'Campanas WhatsApp',
            'Productos recomendados',
            'Promociones inteligentes',
          ],
        ),
        OnboardingStepInfo(
          title: 'Fiado App recomienda',
          description: 'Toma mejores decisiones todos los dias.',
          iconName: 'copilot',
          highlights: ['Business Copilot', 'KPIs', 'Recomendaciones'],
        ),
      ];
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    subscriptionRepository: ref.read(subscriptionRepositoryProvider),
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
  );
});

final authStateProvider =
    AsyncNotifierProvider<AuthStateNotifier, UsuarioSqliteModel?>(
      AuthStateNotifier.new,
    );

final currentUserProvider = Provider<UsuarioSqliteModel?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final currentPermissionsProvider = Provider<AppPermissions>((ref) {
  return AppPermissions.forUser(ref.watch(currentUserProvider));
});

final currentBusinessIdProvider = Provider<int?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  if (user.tipoUsuario == UsuarioSqliteModel.tipoNegocio) return user.id;
  if (user.tipoUsuario == UsuarioSqliteModel.tipoColaborador) {
    return user.negocioId;
  }
  return null;
});

final loginControllerProvider = Provider<LoginController>((ref) {
  return LoginController(ref);
});

final registerControllerProvider = Provider<RegisterController>((ref) {
  return RegisterController(ref);
});

final subscriptionStatusProvider = FutureProvider<SubscriptionAccess>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Future.value(
      const SubscriptionAccess(
        hasAccess: false,
        trialDaysLeft: 0,
        status: 'anonymous',
      ),
    );
  }

  if (user.tipoUsuario == UsuarioSqliteModel.tipoPersonal) {
    return Future.value(
      const SubscriptionAccess(
        hasAccess: true,
        trialDaysLeft: 0,
        status: 'not_required',
      ),
    );
  }

  if (user.tipoUsuario == UsuarioSqliteModel.tipoColaborador) {
    return ref
        .read(subscriptionRepositoryProvider)
        .validarAccesoColaborador(user.id!);
  }

  return ref
      .read(subscriptionRepositoryProvider)
      .validarAccesoNegocio(user.id!);
});

final currentSubscriptionProvider = FutureProvider<SubscriptionSqliteModel?>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.tipoUsuario == UsuarioSqliteModel.tipoPersonal) {
    return Future.value(null);
  }

  final negocioId = user.tipoUsuario == UsuarioSqliteModel.tipoColaborador
      ? user.negocioId
      : user.id;

  if (negocioId == null) return Future.value(null);
  return ref.read(subscriptionRepositoryProvider).obtenerPlanActual(negocioId);
});

final collaboratorLimitProvider = FutureProvider<CollaboratorLimitStatus>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.tipoUsuario != UsuarioSqliteModel.tipoNegocio) {
    return Future.value(
      const CollaboratorLimitStatus(usados: 0, limite: 0, puedeCrear: false),
    );
  }

  return ref
      .read(subscriptionRepositoryProvider)
      .validarLimiteColaboradores(user.id!);
});

final colaboradoresProvider = FutureProvider<List<UsuarioSqliteModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.tipoUsuario != UsuarioSqliteModel.tipoNegocio) {
    return Future.value(const <UsuarioSqliteModel>[]);
  }
  return ref.read(authRepositoryProvider).listarColaboradoresActivos(user.id!);
});

class AuthStateNotifier extends AsyncNotifier<UsuarioSqliteModel?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<UsuarioSqliteModel?> build() async {
    if (kIsWeb) {
      debugPrint('[startup] auth init omitido en Web local');
      return null;
    }
    try {
      return await _repository.obtenerUsuarioActual().timeout(
        const Duration(seconds: 18),
      );
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('[startup] auth init timeout: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<UsuarioSqliteModel> login(String telefono, String password) async {
    state = const AsyncLoading();
    try {
      await CrashDiagnosticsService.recordStartupStep('[login] start');
      if (kIsWeb) {
        final cloudResult = await ref
            .read(cloudAuthServiceProvider)
            .loginCloud(phone: telefono, password: password)
            .timeout(const Duration(seconds: 15));
        if (!cloudResult.success || cloudResult.user == null) {
          throw StateError(AuthRepository.invalidCredentialsMessage);
        }
        final cloudUser = cloudResult.user!;
        final user = UsuarioSqliteModel(
          remoteId: cloudUser.remoteId,
          nombre: cloudUser.businessName?.trim().isNotEmpty == true
              ? cloudUser.businessName!.trim()
              : cloudUser.name,
          telefono: cloudUser.phone,
          tipoUsuario: _localRoleFromCloud(cloudUser.role),
          passwordHash: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          syncStatus: 'synced',
        );
        state = AsyncData(user);
        await CrashDiagnosticsService.recordStartupStep('[login] web ok');
        return user;
      }

      final normalizedPhone = telefono.trim();
      final user = await _repository
          .loginWithCloudFallback(
            telefono: normalizedPhone,
            password: password,
            cloudLogin: () => ref
                .read(cloudAuthServiceProvider)
                .loginCloud(phone: normalizedPhone, password: password),
          )
          .timeout(const Duration(seconds: 20));
      state = AsyncData(user);
      await CrashDiagnosticsService.recordStartupStep('[login] ok');
      return user;
    } on TimeoutException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      await CrashDiagnosticsService.recordStartupError(error);
      throw StateError(AuthRepository.invalidCredentialsMessage);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      await CrashDiagnosticsService.recordStartupError(error);
      rethrow;
    }
  }

  String _localRoleFromCloud(String role) {
    return switch (role.toLowerCase().trim()) {
      'person' || 'personal' => UsuarioSqliteModel.tipoPersonal,
      'business' || 'negocio' => UsuarioSqliteModel.tipoNegocio,
      'collaborator' || 'colaborador' => UsuarioSqliteModel.tipoColaborador,
      _ => UsuarioSqliteModel.tipoNegocio,
    };
  }

  Future<void> logout() async {
    await ref.read(cloudAuthServiceProvider).clearCloudToken();
    await _repository.logout();
    state = const AsyncData(null);
  }

  void setLocalUser(UsuarioSqliteModel user) {
    state = AsyncData(user);
  }

  Future<void> refresh() async {
    state = AsyncData(await _repository.obtenerUsuarioActual());
  }
}

class LoginController {
  final Ref ref;

  const LoginController(this.ref);

  Future<UsuarioSqliteModel> login(String telefono, String password) {
    return ref.read(authStateProvider.notifier).login(telefono, password);
  }

  Future<void> logout() {
    return ref.read(authStateProvider.notifier).logout();
  }
}

class RegisterController {
  final Ref ref;

  const RegisterController(this.ref);

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<UsuarioSqliteModel> registrarUsuarioPersonal(
    String nombre,
    String telefono,
  ) async {
    final user = await _repository.registrarUsuarioPersonal(nombre, telefono);
    await ref.read(authStateProvider.notifier).refresh();
    return user;
  }

  Future<UsuarioSqliteModel> registrarUsuarioNegocio(
    String nombreNegocio,
    String nombreAdmin,
    String telefono,
    String password, {
    String planId = 'basico',
  }) async {
    final user = await _repository.registrarUsuarioNegocio(
      nombreNegocio,
      nombreAdmin,
      telefono,
      password,
      planId: planId,
    );
    await ref.read(authStateProvider.notifier).refresh();
    ref.invalidate(currentSubscriptionProvider);
    ref.invalidate(subscriptionStatusProvider);
    return user;
  }

  Future<UsuarioSqliteModel> crearColaboradorDesdeNegocio({
    required int usuarioNegocioId,
    required String nombre,
    required String telefono,
    required String password,
  }) async {
    final user = await _repository.crearColaboradorDesdeNegocio(
      usuarioNegocioId: usuarioNegocioId,
      nombre: nombre,
      telefono: telefono,
      password: password,
    );
    ref.invalidate(colaboradoresProvider);
    ref.invalidate(collaboratorLimitProvider);
    return user;
  }
}
