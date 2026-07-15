import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/money_formatter.dart';
import '../models/producto.dart';
import '../data/models/producto_imagen_sqlite_model.dart';
import '../data/models/solicitud_autorizacion_sqlite_model.dart';
import '../data/models/usuario_sqlite_model.dart';
import '../data/models/auditoria_sqlite_model.dart';
import '../data/repositories/producto_repository.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../services/inventario_service.dart';
import '../utils/auditoria_helper.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/product_image_thumbnail.dart';
import 'auditoria_screen.dart';
import 'clientes_screen.dart';
import 'orden_compra_screen.dart';
import 'validacion_reporte_screen.dart';
import 'widgets/agregar_producto_dialog.dart';

class InventarioScreen extends ConsumerStatefulWidget {
  const InventarioScreen({super.key});

  @override
  ConsumerState<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends ConsumerState<InventarioScreen> {
  late List<Producto> productos;
  List<Producto> planAuditoriaProductos = const [];
  List<AuditoriaResultado> reportePendiente = const [];
  DateTime? _auditoriaDiariaCompletadaFecha;
  DateTime? _auditoriaSemanalCompletadaFecha;
  List<String> _productosAuditadosHoyIds = const [];
  Map<String, ProductoImagenSqliteModel> _primerasImagenesPorProducto =
      const {};
  Set<String> _imagenLegacyIdsCargados = const {};
  bool _cargandoPrimerasImagenes = false;
  Timer? _reporteTimer;
  bool _mostrarRojo = true;

  @override
  void initState() {
    super.initState();
    _reporteTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _mostrarRojo = !_mostrarRojo;
      });
    });
    productos = const <Producto>[];
    _cargarProductos();
  }

  @override
  void dispose() {
    _reporteTimer?.cancel();
    super.dispose();
  }

  List<Producto> get _productosDisponiblesAuditoria => productos
      .where(AuditoriaHelper.tieneDisponibilidadEnInventario)
      .toList(growable: false);

  List<Producto> get _productosDisponiblesNoAuditadosHoy =>
      _productosDisponiblesAuditoria
          .where((producto) => !_productosAuditadosHoyIds.contains(producto.id))
          .toList(growable: false);

  List<Producto> get _productosParaReposicion => productos
      .where(OrdenCompraScreen.requiereReposicion)
      .toList(growable: false);

  bool get _auditoriaDiariaCompletadaHoy =>
      _esMismoDia(_auditoriaDiariaCompletadaFecha, DateTime.now());

  bool get _auditoriaSemanalDisponible =>
      AuditoriaHelper.esLunes() &&
      !_esMismaSemana(_auditoriaSemanalCompletadaFecha, DateTime.now());

  bool get _puedeIniciarAuditoria =>
      !_auditoriaDiariaCompletadaHoy || _auditoriaSemanalDisponible;

  bool get _siguienteAuditoriaEsSemanal =>
      _auditoriaDiariaCompletadaHoy && _auditoriaSemanalDisponible;

  int get _cantidadObjetivoAuditoria => _siguienteAuditoriaEsSemanal ? 5 : 3;

  String get _textoBotonAuditoria => _siguienteAuditoriaEsSemanal
      ? 'Iniciar auditoria semanal'
      : 'Iniciar auditoria';

  bool get _botonAuditoriaEsAmarillo {
    final ahora = DateTime.now();
    final minutos = (ahora.hour * 60) + ahora.minute;
    const inicioAmarillo = (11 * 60) + 1;
    const finAmarillo = 14 * 60;
    return minutos >= inicioAmarillo && minutos <= finAmarillo;
  }

  bool get _botonAuditoriaEsIntermitente {
    final ahora = DateTime.now();
    final minutos = (ahora.hour * 60) + ahora.minute;
    const inicioIntermitente = (14 * 60) + 1;
    const finIntermitente = 17 * 60;
    return minutos >= inicioIntermitente && minutos <= finIntermitente;
  }

  Future<void> _cargarProductos() async {
    final productosGuardados = (await ref.read(
      productosProvider.future,
    )).productos;
    await _cargarEstadoAuditorias();

    if (!mounted) {
      return;
    }

    setState(() {
      productos = productosGuardados;
    });
    await _cargarPlanAuditoriaPendiente();
  }

  Future<void> _cargarEstadoAuditorias() async {
    final user = ref.read(currentUserProvider);
    final negocioId = _negocioIdActual(user);
    DateTime? diaria;
    DateTime? semanal;

    if (negocioId != null) {
      final repository = ref.read(auditoriaRepositoryProvider);
      diaria = await repository.obtenerUltimaFinalizada(
        negocioId: negocioId,
        tipo: AuditoriaSqliteModel.tipoDiaria,
        colaboradorId: user?.tipoUsuario == UsuarioSqliteModel.tipoColaborador
            ? user?.id
            : null,
      );
      semanal = await repository.obtenerUltimaFinalizada(
        negocioId: negocioId,
        tipo: AuditoriaSqliteModel.tipoSemanal,
        colaboradorId: user?.tipoUsuario == UsuarioSqliteModel.tipoColaborador
            ? user?.id
            : null,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _auditoriaDiariaCompletadaFecha = diaria;
      _auditoriaSemanalCompletadaFecha = semanal;
      _productosAuditadosHoyIds = const [];
    });
  }

  Future<void> _guardarProductos() async {
    await ref.read(productosProvider.notifier).guardarProductos(productos);
  }

  Future<void> _cargarPlanAuditoriaPendiente() async {
    final inventarioService = InventarioService(productos: productos);
    final planBase = inventarioService.generarPlanAuditoria();

    if (!mounted) {
      return;
    }

    setState(() {
      planAuditoriaProductos = planBase.productos;
    });
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) {
      return 'Sin verificacion';
    }

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    return '$dia/$mes/$anio';
  }

  bool _esMismoDia(DateTime? fecha, DateTime referencia) {
    return fecha != null &&
        fecha.year == referencia.year &&
        fecha.month == referencia.month &&
        fecha.day == referencia.day;
  }

  DateTime _inicioDeSemana(DateTime fecha) {
    final normalizada = DateTime(fecha.year, fecha.month, fecha.day);
    return normalizada.subtract(Duration(days: normalizada.weekday - 1));
  }

  bool _esMismaSemana(DateTime? fecha, DateTime referencia) {
    if (fecha == null) {
      return false;
    }

    return _inicioDeSemana(fecha) == _inicioDeSemana(referencia);
  }

  List<Producto> _seleccionarProductosAuditoria({
    required bool esSemanal,
    required int cantidadObjetivo,
  }) {
    final candidatosBase = _productosDisponiblesNoAuditadosHoy;

    if (!esSemanal) {
      final seleccion = List<Producto>.from(candidatosBase)..shuffle();
      return seleccion.take(cantidadObjetivo).toList(growable: false);
    }

    final ordenadosPorRotacion = List<Producto>.from(candidatosBase)
      ..sort(
        (a, b) => b.rotacionSemanaAnterior.compareTo(a.rotacionSemanaAnterior),
      );
    final altaRotacion = ordenadosPorRotacion
        .take(cantidadObjetivo)
        .toList(growable: false);
    final seleccion = List<Producto>.from(altaRotacion)..shuffle();
    return seleccion;
  }

  List<AuditoriaResultado> _unirReportesPendientes(
    List<AuditoriaResultado> existentes,
    List<AuditoriaResultado> nuevos,
  ) {
    final porProducto = <String, AuditoriaResultado>{};

    for (final resultado in existentes) {
      porProducto[resultado.productoId] = resultado;
    }

    for (final resultado in nuevos) {
      porProducto[resultado.productoId] = resultado;
    }

    return porProducto.values.toList(growable: false);
  }

  int? _negocioIdActual(UsuarioSqliteModel? user) {
    if (user == null) return null;
    if (user.tipoUsuario == UsuarioSqliteModel.tipoColaborador) {
      return user.negocioId;
    }
    if (user.tipoUsuario == UsuarioSqliteModel.tipoNegocio) {
      return user.id;
    }
    return null;
  }

  Future<void> _iniciarAuditoria() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cantidadObjetivo = _cantidadObjetivoAuditoria;
    final fueAuditoriaSemanal = _siguienteAuditoriaEsSemanal;
    final productosAuditar = _seleccionarProductosAuditoria(
      esSemanal: fueAuditoriaSemanal,
      cantidadObjetivo: cantidadObjetivo,
    );
    final user = ref.read(currentUserProvider);
    final negocioId = _negocioIdActual(user);

    if (negocioId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Inicia sesion como negocio o colaborador.'),
        ),
      );
      return;
    }

    if (productosAuditar.length < cantidadObjetivo) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Se necesitan al menos $cantidadObjetivo articulos disponibles no repetidos para auditar.',
          ),
        ),
      );
      return;
    }

    final auditoria = fueAuditoriaSemanal
        ? await ref
              .read(auditoriaRepositoryProvider)
              .crearAuditoriaSemanal(
                negocioId: negocioId,
                colaboradorId:
                    user?.tipoUsuario == UsuarioSqliteModel.tipoColaborador
                    ? user?.id
                    : null,
                productos: productosAuditar,
                cantidadObjetivo: cantidadObjetivo,
              )
        : await ref
              .read(auditoriaRepositoryProvider)
              .crearAuditoriaDiaria(
                negocioId: negocioId,
                colaboradorId:
                    user?.tipoUsuario == UsuarioSqliteModel.tipoColaborador
                    ? user?.id
                    : null,
                productos: productosAuditar,
                cantidadObjetivo: cantidadObjetivo,
              );

    if (!mounted) return;
    final resultados = await navigator.push<List<AuditoriaResultado>>(
      MaterialPageRoute(
        builder: (_) => AuditoriaScreen(
          productos: productosAuditar,
          cantidadObjetivo: cantidadObjetivo,
          productosPreseleccionados: true,
        ),
      ),
    );

    if (!mounted) return;
    if (resultados == null || resultados.isEmpty) {
      return;
    }

    final ahora = DateTime.now();
    final resultadosConDiferencias = resultados
        .where((resultado) => resultado.diferencia != 0)
        .toList(growable: false);
    final esColaborador =
        user?.tipoUsuario == UsuarioSqliteModel.tipoColaborador;
    final idsAuditados = resultados
        .map((resultado) => resultado.productoId)
        .toList(growable: false);

    setState(() {
      if (!esColaborador) {
        reportePendiente = _unirReportesPendientes(
          reportePendiente,
          resultadosConDiferencias,
        );
      }
      productos = productos
          .map((producto) {
            AuditoriaResultado? resultado;

            for (final item in resultados) {
              if (item.productoId == producto.id) {
                resultado = item;
                break;
              }
            }

            if (resultado == null) {
              return producto;
            }

            if (resultado.fueVerificadoCorrectamente) {
              return producto.copyWith(
                ultimaVerificacion: ahora,
                disponibilidadConfirmada: true,
                disponibilidadCorregida: false,
                requiereVerificacionAdministrador: false,
              );
            }

            return producto.copyWith(
              ultimaVerificacion: ahora,
              disponibilidadConfirmada: false,
              disponibilidadCorregida: false,
              requiereVerificacionAdministrador: true,
            );
          })
          .toList(growable: false);
      planAuditoriaProductos = const [];
      if (fueAuditoriaSemanal) {
        _auditoriaSemanalCompletadaFecha = ahora;
      } else {
        _auditoriaDiariaCompletadaFecha = ahora;
      }
      _productosAuditadosHoyIds = {
        ..._productosAuditadosHoyIds,
        ...idsAuditados,
      }.toList(growable: false);
    });
    await _guardarProductos();

    for (final resultado in resultados) {
      final productoSqliteId = await ref
          .read(productoRepositoryProvider)
          .obtenerIdSqlitePorLegacyId(
            resultado.productoId,
            negocioId: negocioId,
          );
      if (productoSqliteId != null && auditoria.id != null) {
        await ref
            .read(auditoriaRepositoryProvider)
            .validarItem(
              auditoriaId: auditoria.id!,
              productoSqliteId: productoSqliteId,
              stockFisico: resultado.cantidadAuditada,
            );
      }
    }
    if (auditoria.id != null) {
      await ref
          .read(auditoriaRepositoryProvider)
          .finalizarAuditoria(
            auditoria.id!,
            observaciones: resultadosConDiferencias.isEmpty
                ? 'Auditoria completada sin diferencias.'
                : 'Auditoria con ${resultadosConDiferencias.length} diferencias.',
          );
    }
    ref.invalidate(auditoriasNegocioProvider);
    ref.invalidate(auditoriasColaboradorProvider);
    ref.invalidate(auditoriasPendientesProvider);

    if (esColaborador && resultadosConDiferencias.isNotEmpty) {
      await _crearSolicitudesPorDiferenciasAuditoria(resultadosConDiferencias);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Auditoria enviada al negocio para validar diferencias.',
            ),
          ),
        );
      }
      return;
    }

    if (mounted && resultadosConDiferencias.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Auditoria completada sin diferencias.')),
      );
    }
  }

  Future<void> _crearSolicitudesPorDiferenciasAuditoria(
    List<AuditoriaResultado> diferencias,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user?.id == null || user?.negocioId == null) {
      return;
    }

    for (final resultado in diferencias) {
      final productoAntes = productos.firstWhere(
        (producto) => producto.id == resultado.productoId,
      );
      final productoDespues = productoAntes.copyWith(
        cantidad: resultado.cantidadAuditada,
        requiereVerificacionAdministrador: false,
        disponibilidadConfirmada:
            resultado.cantidadAuditada == productoAntes.cantidad,
        disponibilidadCorregida:
            resultado.cantidadAuditada != productoAntes.cantidad,
        ultimaVerificacion: DateTime.now(),
      );

      await ref
          .read(solicitudAutorizacionRepositoryProvider)
          .crearSolicitud(
            negocioId: user!.negocioId!,
            colaboradorId: user.id!,
            tipoSolicitud: SolicitudAutorizacionSqliteModel.tipoAjustarStock,
            entidad: SolicitudAutorizacionSqliteModel.entidadProducto,
            datosAntes: jsonEncode(productoAntes.toJson()),
            datosDespues: jsonEncode(productoDespues.toJson()),
          );
    }

    ref.invalidate(solicitudesColaboradorProvider);
    ref.invalidate(solicitudesPendientesProvider);
    ref.invalidate(solicitudesPendientesCountProvider);
  }

  Future<void> _validarReporteInventario() async {
    if (reportePendiente.isEmpty) {
      return;
    }

    final resultadosValidacion =
        await Navigator.push<List<ValidacionReporteResultado>>(
          context,
          MaterialPageRoute(
            builder: (_) => ValidacionReporteScreen(reporte: reportePendiente),
          ),
        );

    if (resultadosValidacion == null || resultadosValidacion.isEmpty) {
      return;
    }

    final ahora = DateTime.now();

    setState(() {
      productos = productos
          .map((producto) {
            AuditoriaResultado? resultadoAuditoria;
            ValidacionReporteResultado? resultadoValidacion;

            for (final item in reportePendiente) {
              if (item.productoId == producto.id) {
                resultadoAuditoria = item;
                break;
              }
            }

            for (final item in resultadosValidacion) {
              if (item.productoId == producto.id) {
                resultadoValidacion = item;
                break;
              }
            }

            if (resultadoAuditoria == null || resultadoValidacion == null) {
              return producto;
            }

            return producto.copyWith(
              cantidad: resultadoValidacion.cantidadValidada,
              ultimaVerificacion: ahora,
              disponibilidadConfirmada:
                  resultadoValidacion.cantidadValidada == producto.cantidad,
              disponibilidadCorregida:
                  resultadoValidacion.cantidadValidada != producto.cantidad,
              requiereVerificacionAdministrador: false,
            );
          })
          .toList(growable: false);
      reportePendiente = const [];
    });
    await _guardarProductos();
  }

  void _abrirOrdenCompra() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrdenCompraScreen(productos: productos),
      ),
    );
  }

  Future<void> _buscarProductos() async {
    final textoController = TextEditingController(
      text: ref.read(productoBusquedaProvider),
    );

    final busqueda = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text('Buscar producto'),
          content: TextField(
            controller: textoController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre o categoria',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Limpiar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, textoController.text),
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 400), () {
      textoController.dispose();
    });

    if (busqueda == null) {
      return;
    }

    ref.read(productoBusquedaProvider.notifier).state = busqueda.trim();
    await ref.read(productosProvider.future);
    if (mounted) {
      await _cargarPlanAuditoriaPendiente();
    }
  }

  Future<void> _recargarInventario() async {
    await ref.read(productosProvider.notifier).recargar();
    _imagenLegacyIdsCargados = const {};
    _primerasImagenesPorProducto = const {};
    await _cargarProductos();
  }

  void _programarCargaPrimerasImagenes(List<Producto> productosVisibles) {
    final legacyIds = productosVisibles
        .map((producto) => producto.id)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    if (_cargandoPrimerasImagenes ||
        _setsIguales(legacyIds, _imagenLegacyIdsCargados)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cargarPrimerasImagenes(productosVisibles);
      }
    });
  }

  Future<void> _cargarPrimerasImagenes(List<Producto> productosVisibles) async {
    if (_cargandoPrimerasImagenes) return;
    final negocioId = ref.read(currentBusinessIdProvider);
    if (negocioId == null || productosVisibles.isEmpty) return;

    final legacyIds = productosVisibles
        .map((producto) => producto.id)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    setState(() => _cargandoPrimerasImagenes = true);
    try {
      final sqliteIds = await ref
          .read(productoRepositoryProvider)
          .obtenerIdsSqlitePorLegacyIds(
            legacyIds.toList(growable: false),
            negocioId: negocioId,
          );
      final imagesBySqliteId = await ref
          .read(productoImagenRepositoryProvider)
          .obtenerPrimeraImagenPorProductos(
            sqliteIds.values.toList(growable: false),
            negocioId: negocioId,
          );
      final imagesByLegacyId = <String, ProductoImagenSqliteModel>{};
      for (final entry in sqliteIds.entries) {
        final image = imagesBySqliteId[entry.value];
        if (image != null) {
          imagesByLegacyId[entry.key] = image;
        }
      }
      if (!mounted) return;
      setState(() {
        _primerasImagenesPorProducto = imagesByLegacyId;
        _imagenLegacyIdsCargados = legacyIds;
      });
    } finally {
      if (mounted) {
        setState(() => _cargandoPrimerasImagenes = false);
      }
    }
  }

  bool _setsIguales(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final value in a) {
      if (!b.contains(value)) return false;
    }
    return true;
  }

  Future<void> _crearProducto() async {
    final permissions = ref.read(currentPermissionsProvider);
    if (!permissions.canAddInventario) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu usuario no puede crear articulos de inventario.'),
        ),
      );
      return;
    }

    final result = await _mostrarFormularioProducto();
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(productosProvider.notifier)
          .guardarProducto(result.producto, imagenes: result.imagenes);
      await _cargarProductos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto agregado al inventario.')),
        );
      }
    } on ProductoDuplicadoException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ya existe un articulo con ese nombre o codigo de referencia en este negocio.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _editarProducto(Producto producto) async {
    final result = await _mostrarFormularioProducto(producto: producto);
    if (result == null) {
      return;
    }
    final actualizado = result.producto;

    try {
      await _aplicarOCrearSolicitud(
        tipoSolicitud: SolicitudAutorizacionSqliteModel.tipoModificarProducto,
        productoAntes: producto,
        productoDespues: actualizado,
        mensajeDirecto: 'Producto actualizado.',
        mensajeSolicitud: 'Solicitud de modificacion enviada al negocio.',
        accionDirecta: () async {
          await ref
              .read(productosProvider.notifier)
              .actualizarProducto(actualizado);
        },
      );
    } on ProductoDuplicadoException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ya existe un articulo con ese nombre o codigo de referencia en este negocio.',
          ),
        ),
      );
    }
  }

  Future<void> _ajustarStock(Producto producto) async {
    final controller = TextEditingController(text: '${producto.cantidad}');
    final nuevaCantidad = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ajustar stock'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  int.tryParse(controller.text.trim()),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (nuevaCantidad == null || nuevaCantidad < 0) {
      return;
    }

    await _aplicarOCrearSolicitud(
      tipoSolicitud: SolicitudAutorizacionSqliteModel.tipoAjustarStock,
      productoAntes: producto,
      productoDespues: producto.copyWith(cantidad: nuevaCantidad),
      mensajeDirecto: 'Stock actualizado.',
      mensajeSolicitud: 'Solicitud de ajuste de stock enviada al negocio.',
      accionDirecta: () async {
        await ref
            .read(productosProvider.notifier)
            .actualizarStock(productoId: producto.id, cantidad: nuevaCantidad);
      },
    );
  }

  Future<void> _eliminarProducto(Producto producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar producto'),
          content: Text('Deseas eliminar ${producto.nombre}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    await _aplicarOCrearSolicitud(
      tipoSolicitud: SolicitudAutorizacionSqliteModel.tipoEliminarProducto,
      productoAntes: producto,
      productoDespues: producto,
      mensajeDirecto: 'Producto eliminado.',
      mensajeSolicitud: 'Solicitud de eliminacion enviada al negocio.',
      accionDirecta: () async {
        await ref
            .read(productosProvider.notifier)
            .eliminarProducto(producto.id);
      },
    );
  }

  Future<void> _aplicarOCrearSolicitud({
    required String tipoSolicitud,
    required Producto productoAntes,
    required Producto productoDespues,
    required String mensajeDirecto,
    required String mensajeSolicitud,
    required Future<void> Function() accionDirecta,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    final esColaborador =
        user?.tipoUsuario == UsuarioSqliteModel.tipoColaborador;

    if (!esColaborador) {
      await accionDirecta();
      await _cargarProductos();
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(mensajeDirecto)));
      }
      return;
    }

    if (user?.id == null || user?.negocioId == null) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No se pudo identificar el negocio asociado.'),
          ),
        );
      }
      return;
    }

    await ref
        .read(solicitudAutorizacionRepositoryProvider)
        .crearSolicitud(
          negocioId: user!.negocioId!,
          colaboradorId: user.id!,
          tipoSolicitud: tipoSolicitud,
          entidad: SolicitudAutorizacionSqliteModel.entidadProducto,
          datosAntes: jsonEncode(productoAntes.toJson()),
          datosDespues: jsonEncode(productoDespues.toJson()),
        );

    ref.invalidate(solicitudesColaboradorProvider);
    ref.invalidate(solicitudesPendientesProvider);
    ref.invalidate(solicitudesPendientesCountProvider);

    if (mounted) {
      messenger.showSnackBar(SnackBar(content: Text(mensajeSolicitud)));
    }
  }

  Future<ProductoFormResult?> _mostrarFormularioProducto({
    Producto? producto,
  }) async {
    final puedeAgregarImagenes =
        producto == null &&
        ref.read(currentPermissionsProvider).canAddProductImages;
    return showDialog<ProductoFormResult>(
      context: context,
      builder: (dialogContext) {
        return AgregarProductoDialog(
          producto: producto,
          puedeAgregarImagenes: puedeAgregarImagenes,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(currentPermissionsProvider);
    if (!permissions.canViewInventario) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventario')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No tienes permiso para acceder al inventario de negocio.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final productosAsync = ref.watch(productosProvider);
    final productosState = productosAsync.valueOrNull;
    final productosActuales = productosState?.productos ?? productos;
    final inventarioResumen = ref.watch(inventarioResumenProvider);
    final productosStockBajo = productosActuales
        .where((producto) => producto.cantidad <= producto.stockMinimo)
        .length;
    final valorCostoInventario = productosActuales.fold<double>(
      0,
      (total, producto) => total + (producto.cantidad * producto.costoUnitario),
    );
    final valorVentaInventario = productosActuales.fold<double>(
      0,
      (total, producto) => total + (producto.cantidad * producto.precioVenta),
    );
    final gananciaPotencial = valorVentaInventario - valorCostoInventario;
    final user = ref.watch(currentUserProvider);
    final puedeAgregar = permissions.canAddInventario;
    final puedeSolicitarCambios =
        user?.tipoUsuario == UsuarioSqliteModel.tipoColaborador;
    final puedeGestionarExistentes =
        permissions.canEditInventario || permissions.canDeleteInventario;
    final puedeValidarInventario =
        user?.tipoUsuario != UsuarioSqliteModel.tipoColaborador;
    productos = productosActuales;
    _programarCargaPrimerasImagenes(productosActuales);
    final textTheme = Theme.of(context).textTheme;
    final hoyEsLunes = AuditoriaHelper.esLunes();
    final productosPendientes = productos
        .where(AuditoriaHelper.necesitaAuditoria)
        .toList(growable: false);

    if (productosAsync.hasError && productosState == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFB42318),
                    size: 42,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No se pudo cargar el inventario',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF17322C),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(productosProvider.notifier).recargar();
                      _cargarProductos();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (productosAsync.isLoading && productosState == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      bottomNavigationBar: reportePendiente.isEmpty || !puedeValidarInventario
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _validarReporteInventario,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mostrarRojo
                          ? const Color(0xFFB42318)
                          : const Color(0xFFE7B04B),
                      foregroundColor: _mostrarRojo
                          ? Colors.white
                          : const Color(0xFF17322C),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                    child: const Text('Validar reporte de Inventario'),
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding = AdaptiveLayout.contentInset(
              constraints.maxWidth,
            );

            return CustomScrollView(
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (Navigator.canPop(context)) ...[
                              _InventoryHeaderActionButton(
                                icon: Icons.arrow_back_rounded,
                                tooltip: 'Volver',
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Inventario',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF17322C),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Controla stock, auditorias y validaciones.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF66756D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (permissions.canViewClientes)
                              _InventoryHeaderActionButton(
                                icon: Icons.groups_2_outlined,
                                tooltip: 'Clientes',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ClientesScreen(),
                                    ),
                                  );
                                },
                              ),
                            _InventoryHeaderActionButton(
                              icon: Icons.search_rounded,
                              tooltip: 'Buscar producto',
                              onPressed: _buscarProductos,
                            ),
                            _InventoryHeaderActionButton(
                              icon: Icons.refresh_rounded,
                              tooltip: 'Recargar',
                              onPressed: _recargarInventario,
                            ),
                            if (puedeAgregar)
                              _InventoryHeaderActionButton(
                                icon: Icons.add_rounded,
                                tooltip: 'Agregar producto',
                                onPressed: _crearProducto,
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF17322C), Color(0xFF1F7A6B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x2217322C),
                                blurRadius: 24,
                                offset: Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hoyEsLunes
                                              ? 'Inventario semanal'
                                              : 'Inventario diario',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          hoyEsLunes
                                              ? 'Hasta 5 productos clave para auditar.'
                                              : 'Hasta 3 productos disponibles para auditar.',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFDCE9E5),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Valor venta inventario',
                                      style: TextStyle(
                                        color: Color(0xFFDCE9E5),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        MoneyFormatter.formatCurrency(
                                          valorVentaInventario,
                                        ),
                                        maxLines: 1,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final crossAxisCount =
                                      constraints.maxWidth >= 720
                                      ? 4
                                      : constraints.maxWidth >= 360
                                      ? 2
                                      : 1;
                                  final tiles = [
                                    _InventoryMetricTile(
                                      icon: Icons.widgets_outlined,
                                      label: 'Productos',
                                      value:
                                          '${inventarioResumen.productosActivos}',
                                    ),
                                    _InventoryMetricTile(
                                      icon: Icons.payments_outlined,
                                      label: 'Costo',
                                      value: MoneyFormatter.formatCurrency(
                                        valorCostoInventario,
                                      ),
                                    ),
                                    _InventoryMetricTile(
                                      icon: Icons.trending_up_rounded,
                                      label: 'Ganancia',
                                      value: MoneyFormatter.formatCurrency(
                                        gananciaPotencial,
                                      ),
                                    ),
                                    _InventoryMetricTile(
                                      icon: Icons.warning_amber_rounded,
                                      label: 'Stock bajo',
                                      value: '$productosStockBajo',
                                    ),
                                    _InventoryMetricTile(
                                      icon: Icons.playlist_add_check_rounded,
                                      label: 'Plan hoy',
                                      value: _puedeIniciarAuditoria
                                          ? '${min(_cantidadObjetivoAuditoria, _productosDisponiblesNoAuditadosHoy.length)}'
                                          : '0',
                                    ),
                                  ];

                                  return GridView.count(
                                    crossAxisCount: crossAxisCount,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: crossAxisCount == 1
                                        ? 3.3
                                        : 1.95,
                                    children: tiles,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Auditoria',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF17322C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Logica integrada con InventarioService para el plan inteligente del dia.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF66756D),
                          ),
                        ),
                        if (_puedeIniciarAuditoria) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _productosDisponiblesNoAuditadosHoy.length <
                                      _cantidadObjetivoAuditoria
                                  ? null
                                  : _iniciarAuditoria,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _botonAuditoriaEsIntermitente
                                    ? (_mostrarRojo
                                          ? const Color(0xFFB42318)
                                          : const Color(0xFFE7B04B))
                                    : _botonAuditoriaEsAmarillo
                                    ? const Color(0xFFE7B04B)
                                    : null,
                                foregroundColor: _botonAuditoriaEsIntermitente
                                    ? (_mostrarRojo
                                          ? Colors.white
                                          : const Color(0xFF17322C))
                                    : _botonAuditoriaEsAmarillo
                                    ? const Color(0xFF17322C)
                                    : null,
                                side: _botonAuditoriaEsIntermitente
                                    ? const BorderSide(
                                        color: Colors.black,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              icon: const Icon(
                                Icons.playlist_add_check_circle_outlined,
                              ),
                              label: Text(_textoBotonAuditoria),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _abrirOrdenCompra,
                          child: Ink(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _productosParaReposicion.isEmpty
                                    ? const Color(0xFFD9E8E3)
                                    : const Color(0xFFE7B04B),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x12000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: _productosParaReposicion.isEmpty
                                        ? const Color(0xFFE7F3EF)
                                        : const Color(0xFFFFF4DB),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(
                                    Icons.shopping_cart_checkout_outlined,
                                    color: _productosParaReposicion.isEmpty
                                        ? const Color(0xFF1F7A6B)
                                        : const Color(0xFFB54708),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Orden de compra',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF17322C),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _productosParaReposicion.isEmpty
                                            ? 'No hay articulos bajo el minimo.'
                                            : '${_productosParaReposicion.length} articulos requieren reposicion.',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF66756D),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF66756D),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFD9E8E3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pendientes de auditoria',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF17322C),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                productosPendientes.isEmpty
                                    ? 'No hay productos pendientes por auditar.'
                                    : 'Productos pendientes por fecha o por falta de cierre en la auditoria previa.',
                                style: const TextStyle(
                                  color: Color(0xFF66756D),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                productos.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 40,
                                    color: Color(0xFF1F7A6B),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'No hay productos registrados',
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF17322C),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'El inventario se cargara desde SQLite cuando existan productos activos.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF66756D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          contentPadding,
                          4,
                          contentPadding,
                          28,
                        ),
                        sliver: SliverList.builder(
                          itemCount:
                              productos.length +
                              ((productosState?.hasMore ?? false) ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= productos.length) {
                              final isLoadingMore =
                                  productosState?.isLoadingMore ?? false;

                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 14,
                                ),
                                child: Center(
                                  child: OutlinedButton.icon(
                                    onPressed: isLoadingMore
                                        ? null
                                        : () => ref
                                              .read(productosProvider.notifier)
                                              .cargarMas(),
                                    icon: isLoadingMore
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.expand_more_rounded),
                                    label: Text(
                                      isLoadingMore
                                          ? 'Cargando'
                                          : 'Cargar mas productos',
                                    ),
                                  ),
                                ),
                              );
                            }

                            final producto = productos[index];
                            final requiereAuditoria =
                                AuditoriaHelper.necesitaAuditoria(producto);
                            final stockBajo =
                                producto.cantidad <= producto.stockMinimo;
                            final categoria =
                                (producto.categoria?.trim().isNotEmpty ?? false)
                                ? producto.categoria!.trim()
                                : producto.ubicacion;
                            final codigo =
                                (producto.codigoReferencia?.trim().isNotEmpty ??
                                    false)
                                ? producto.codigoReferencia!.trim()
                                : 'Sin codigo';
                            final gananciaUnidad =
                                producto.precioVenta - producto.costoUnitario;
                            final productImage =
                                _primerasImagenesPorProducto[producto.id];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: stockBajo
                                        ? const Color(0xFFE7B04B)
                                        : producto.esClave
                                        ? const Color(0xFFE7B04B)
                                        : const Color(0xFFD9E8E3),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x12000000),
                                      blurRadius: 18,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final compact = constraints.maxWidth < 520;
                                    final leading = ProductImageThumbnail(
                                      image: productImage,
                                      stockBajo: stockBajo,
                                      esClave: producto.esClave,
                                      size: compact ? 58 : 64,
                                    );
                                    final info = Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            producto.nombre,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF17322C),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 7,
                                            children: [
                                              _ProductDataPill(
                                                icon: Icons.qr_code_2_rounded,
                                                label: codigo,
                                              ),
                                              _ProductDataPill(
                                                icon: Icons.category_outlined,
                                                label: categoria,
                                              ),
                                              _ProductDataPill(
                                                icon: Icons.sell_outlined,
                                                label:
                                                    'Venta ${MoneyFormatter.formatCurrency(producto.precioVenta)}',
                                              ),
                                              _ProductDataPill(
                                                icon: Icons.payments_outlined,
                                                label:
                                                    'Costo ${MoneyFormatter.formatCurrency(producto.costoUnitario)}',
                                              ),
                                              _ProductDataPill(
                                                icon: Icons.percent_rounded,
                                                label:
                                                    'Margen ${producto.porcentajeGanancia.toStringAsFixed(1)}%',
                                              ),
                                              _ProductDataPill(
                                                icon: Icons.trending_up_rounded,
                                                label:
                                                    'Gan. ${MoneyFormatter.formatCurrency(gananciaUnidad)}',
                                              ),
                                              _ProductDataPill(
                                                icon:
                                                    Icons.low_priority_rounded,
                                                label:
                                                    'Min. ${producto.stockMinimo}',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 7,
                                            children: [
                                              _ProductStateChip(
                                                label: stockBajo
                                                    ? 'Stock bajo'
                                                    : 'Stock estable',
                                                color: stockBajo
                                                    ? const Color(0xFFB54708)
                                                    : const Color(0xFF1F7A6B),
                                                background: stockBajo
                                                    ? const Color(0xFFFFF4DB)
                                                    : const Color(0xFFE7F3EF),
                                              ),
                                              _ProductStateChip(
                                                label: producto.cantidad > 0
                                                    ? 'Disponible'
                                                    : 'Sin disponibilidad',
                                                color: producto.cantidad > 0
                                                    ? const Color(0xFF1F7A6B)
                                                    : const Color(0xFFB42318),
                                                background:
                                                    producto.cantidad > 0
                                                    ? const Color(0xFFE7F3EF)
                                                    : const Color(0xFFFDEAE5),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            _formatearFecha(
                                              producto.ultimaVerificacion,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF66756D),
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            producto.requiereVerificacionAdministrador
                                                ? 'Verificacion por encargado, diferencias entre cantidades'
                                                : requiereAuditoria
                                                ? 'Necesita auditoria'
                                                : 'Auditoria al dia',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color:
                                                  producto
                                                      .requiereVerificacionAdministrador
                                                  ? const Color(0xFFB42318)
                                                  : requiereAuditoria
                                                  ? const Color(0xFFB54708)
                                                  : const Color(0xFF1F7A6B),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    final status = _InventoryStatusAmount(
                                      esClave: producto.esClave,
                                      cantidad: producto.cantidad,
                                      stockMinimo: producto.stockMinimo,
                                      stockBajo: stockBajo,
                                      alignEnd: !compact,
                                    );
                                    final acciones = _InventoryProductActions(
                                      enabled:
                                          puedeGestionarExistentes ||
                                          puedeSolicitarCambios ||
                                          user == null,
                                      onEdit: () => _editarProducto(producto),
                                      onStock: () => _ajustarStock(producto),
                                      onDelete: () =>
                                          _eliminarProducto(producto),
                                    );

                                    if (compact) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              leading,
                                              const SizedBox(width: 12),
                                              info,
                                              acciones,
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          status,
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        leading,
                                        const SizedBox(width: 14),
                                        info,
                                        const SizedBox(width: 10),
                                        status,
                                        const SizedBox(width: 4),
                                        acciones,
                                      ],
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InventoryMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InventoryMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFDCE9E5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryHeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _InventoryHeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3DED2)),
        ),
        child: IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _InventoryStatusAmount extends StatelessWidget {
  final bool esClave;
  final int cantidad;
  final int stockMinimo;
  final bool stockBajo;
  final bool alignEnd;

  const _InventoryStatusAmount({
    required this.esClave,
    required this.cantidad,
    required this.stockMinimo,
    required this.stockBajo,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: stockBajo
                ? const Color(0xFFFFF4DB)
                : esClave
                ? const Color(0xFFFFF4DB)
                : const Color(0xFFE7F3EF),
          ),
          child: Text(
            stockBajo
                ? 'Reponer'
                : esClave
                ? 'Clave'
                : 'Regular',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: stockBajo
                  ? const Color(0xFFB54708)
                  : esClave
                  ? const Color(0xFFB54708)
                  : const Color(0xFF1F7A6B),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            '$cantidad uds',
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF17322C),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Min. $stockMinimo',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF66756D),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProductDataPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProductDataPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4EEE9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF66756D)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF66756D),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductStateChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _ProductStateChip({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InventoryProductActions extends StatelessWidget {
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onStock;
  final VoidCallback onDelete;

  const _InventoryProductActions({
    required this.enabled,
    required this.onEdit,
    required this.onStock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: 'Acciones de producto',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit();
            return;
          case 'stock':
            onStock();
            return;
          case 'delete':
            onDelete();
            return;
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Modificar'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'stock',
            child: ListTile(
              leading: Icon(Icons.inventory_outlined),
              title: Text('Ajustar stock'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline_rounded),
              title: Text('Eliminar'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ];
      },
    );
  }
}
