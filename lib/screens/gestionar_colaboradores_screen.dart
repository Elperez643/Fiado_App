import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/usuario_sqlite_model.dart';
import '../data/repositories/auth_repository.dart';
import '../presentation/providers/auth_providers.dart';
import '../widgets/adaptive_layout.dart';

class GestionarColaboradoresScreen extends ConsumerWidget {
  const GestionarColaboradoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(currentPermissionsProvider);
    if (!permissions.canManageCollaborators) {
      return Scaffold(
        appBar: AppBar(title: const Text('Colaboradores')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Solo el usuario Negocio puede gestionar colaboradores.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final user = ref.watch(currentUserProvider);
    final colaboradoresAsync = ref.watch(colaboradoresProvider);
    final limitAsync = ref.watch(collaboratorLimitProvider);
    final limit = limitAsync.valueOrNull;

    if (user?.tipoUsuario != UsuarioSqliteModel.tipoNegocio) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Text('Solo el negocio puede gestionar colaboradores.'),
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: limit != null && !limit.puedeCrear
            ? null
            : () => _mostrarCrearColaborador(context, ref, user!.id!),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo colaborador'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding = AdaptiveLayout.contentInset(
              constraints.maxWidth,
            );
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(colaboradoresProvider);
                ref.invalidate(collaboratorLimitProvider);
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        contentPadding,
                        18,
                        contentPadding,
                        14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Colaboradores',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF17322C),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            limit == null
                                ? 'Cargando limite del plan...'
                                : '${limit.usados}/${limit.limite} colaboradores usados',
                            style: const TextStyle(color: Color(0xFF66756D)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  colaboradoresAsync.when(
                    loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => const SliverFillRemaining(
                      child: Center(
                        child: Text('No se pudieron cargar colaboradores.'),
                      ),
                    ),
                    data: (colaboradores) {
                      if (colaboradores.isEmpty) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text('No hay colaboradores registrados.'),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          contentPadding,
                          4,
                          contentPadding,
                          110,
                        ),
                        sliver: SliverList.builder(
                          itemCount: colaboradores.length,
                          itemBuilder: (context, index) {
                            final colaborador = colaboradores[index];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  colaborador.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  colaborador.activo
                                      ? '${colaborador.telefono} - Activo'
                                      : '${colaborador.telefono} - Inactivo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Wrap(
                                  spacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    IconButton(
                                      tooltip: 'Editar colaborador',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () =>
                                          _mostrarEditarColaborador(
                                            context,
                                            ref,
                                            user!.id!,
                                            colaborador,
                                          ),
                                    ),
                                    Switch(
                                      value: colaborador.activo,
                                      onChanged: (activo) async {
                                        await ref
                                            .read(authRepositoryProvider)
                                            .cambiarEstadoColaborador(
                                              colaboradorId: colaborador.id!,
                                              activo: activo,
                                            );
                                        ref.invalidate(colaboradoresProvider);
                                        ref.invalidate(
                                          collaboratorLimitProvider,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _mostrarEditarColaborador(
    BuildContext context,
    WidgetRef ref,
    int usuarioNegocioId,
    UsuarioSqliteModel colaborador,
  ) async {
    final nombreController = TextEditingController(text: colaborador.nombre);
    final telefonoController = TextEditingController(
      text: colaborador.telefono,
    );
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var activo = colaborador.activo;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Editar colaborador'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                      TextField(
                        controller: telefonoController,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Telefono',
                          counterText: '',
                        ),
                      ),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nueva contrasena opcional',
                        ),
                      ),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar nueva contrasena',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Colaborador activo'),
                        value: activo,
                        onChanged: (value) {
                          setDialogState(() => activo = value);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final nombre = nombreController.text.trim();
                      final telefono = telefonoController.text.trim();
                      final password = passwordController.text.trim();
                      final confirmPassword = confirmPasswordController.text
                          .trim();

                      if (nombre.isEmpty) {
                        _mostrarMensaje(context, 'Completa el nombre.');
                        return;
                      }

                      if (!RegExp(r'^\d{10}$').hasMatch(telefono)) {
                        _mostrarMensaje(
                          context,
                          'El telefono debe tener exactamente 10 digitos.',
                        );
                        return;
                      }

                      if (password.isNotEmpty && password != confirmPassword) {
                        _mostrarMensaje(
                          context,
                          'Las contrasenas no coinciden.',
                        );
                        return;
                      }

                      try {
                        await ref
                            .read(authRepositoryProvider)
                            .editarColaboradorDesdeNegocio(
                              usuarioNegocioId: usuarioNegocioId,
                              colaboradorId: colaborador.id!,
                              nombre: nombre,
                              telefono: telefono,
                              nuevaPassword: password.isEmpty ? null : password,
                              activo: activo,
                            );

                        ref.invalidate(colaboradoresProvider);
                        ref.invalidate(collaboratorLimitProvider);

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (context.mounted) {
                          _mostrarMensaje(context, 'Colaborador actualizado.');
                        }
                      } catch (error) {
                        if (!context.mounted) return;
                        final message = error.toString().contains('Ya existe')
                            ? 'Ya existe un usuario con ese telefono.'
                            : 'No se pudo actualizar el colaborador.';
                        _mostrarMensaje(context, message);
                      }
                    },
                    child: const Text('Guardar cambios'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nombreController.dispose();
      telefonoController.dispose();
      passwordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  Future<void> _mostrarCrearColaborador(
    BuildContext context,
    WidgetRef ref,
    int usuarioNegocioId,
  ) async {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Nuevo colaborador'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: telefonoController,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                    counterText: '',
                  ),
                ),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contrasena'),
                ),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contrasena',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final nombre = nombreController.text.trim();
                  final telefono = telefonoController.text.trim();
                  final password = passwordController.text.trim();
                  final confirmPassword = confirmPasswordController.text.trim();

                  if (nombre.isEmpty) {
                    _mostrarMensaje(context, 'Completa el nombre.');
                    return;
                  }

                  if (!RegExp(r'^\d{10}$').hasMatch(telefono)) {
                    _mostrarMensaje(
                      context,
                      'El telefono debe tener exactamente 10 digitos.',
                    );
                    return;
                  }

                  if (password.isEmpty) {
                    _mostrarMensaje(context, 'La contrasena es obligatoria.');
                    return;
                  }

                  if (password != confirmPassword) {
                    _mostrarMensaje(context, 'Las contrasenas no coinciden.');
                    return;
                  }

                  try {
                    await ref
                        .read(registerControllerProvider)
                        .crearColaboradorDesdeNegocio(
                          usuarioNegocioId: usuarioNegocioId,
                          nombre: nombre,
                          telefono: telefono,
                          password: password,
                        );
                    if (context.mounted) Navigator.pop(context);
                  } catch (error) {
                    if (!context.mounted) return;
                    final message =
                        error.toString().contains(
                          AuthRepository.collaboratorLimitMessage,
                        )
                        ? AuthRepository.collaboratorLimitMessage
                        : error.toString().contains('Ya existe')
                        ? 'Ya existe un usuario con ese telefono.'
                        : error.toString().contains('suscripcion')
                        ? 'El plan del negocio no esta activo.'
                        : 'No se pudo crear el colaborador.';
                    _mostrarMensaje(context, message);
                  }
                },
                child: const Text('Crear'),
              ),
            ],
          );
        },
      );
    } finally {
      nombreController.dispose();
      telefonoController.dispose();
      passwordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  void _mostrarMensaje(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
