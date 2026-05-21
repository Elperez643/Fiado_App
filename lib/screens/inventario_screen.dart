import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../services/inventario_service.dart';
import '../services/storage_service.dart';
import '../utils/auditoria_helper.dart';
import '../widgets/adaptive_layout.dart';
import 'auditoria_screen.dart';
import 'clientes_screen.dart';
import 'orden_compra_screen.dart';
import 'validacion_reporte_screen.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  late List<Producto> productos;
  List<Producto> planAuditoriaProductos = const [];
  List<AuditoriaResultado> reportePendiente = const [];
  DateTime? _auditoriaDiariaCompletadaFecha;
  DateTime? _auditoriaSemanalCompletadaFecha;
  List<String> _productosAuditadosHoyIds = const [];
  Timer? _reporteTimer;
  bool _mostrarRojo = true;

  List<Producto> get _productosIniciales => [
        Producto(
          id: 'prod-001',
          nombre: 'Arroz Selecto 5 lb',
          ubicacion: 'Pasillo A - Estante 1',
          cantidad: 18,
          tipoMedida: Producto.medidaPeso,
          esClave: true,
          ultimaVerificacion: DateTime(2026, 5, 1),
          disponibilidadConfirmada: true,
          nivelDemanda: Producto.demandaAlta,
          rotacionSemanaAnterior: 96,
        ),
        Producto(
          id: 'prod-002',
          nombre: 'Aceite vegetal 1L',
          ubicacion: 'Pasillo A - Estante 3',
          cantidad: 9,
          tipoMedida: Producto.medidaUnidad,
          esClave: true,
          ultimaVerificacion: DateTime(2026, 4, 30),
          disponibilidadCorregida: true,
          nivelDemanda: Producto.demandaAlta,
          rotacionSemanaAnterior: 88,
        ),
        Producto(
          id: 'prod-003',
          nombre: 'Habichuelas rojas 800 g',
          ubicacion: 'Pasillo B - Estante 2',
          cantidad: 24,
          tipoMedida: Producto.medidaPeso,
          esClave: false,
          ultimaVerificacion: DateTime(2026, 4, 28),
          disponibilidadConfirmada: true,
          nivelDemanda: Producto.demandaMedia,
          rotacionSemanaAnterior: 74,
        ),
        Producto(
          id: 'prod-004',
          nombre: 'Azucar crema 2 lb',
          ubicacion: 'Pasillo B - Estante 4',
          cantidad: 6,
          tipoMedida: Producto.medidaPeso,
          esClave: true,
          nivelDemanda: Producto.demandaAlta,
          rotacionSemanaAnterior: 81,
        ),
        Producto(
          id: 'prod-005',
          nombre: 'Cafe molido 1 lb',
          ubicacion: 'Pasillo C - Estante 1',
          cantidad: 0,
          tipoMedida: Producto.medidaPeso,
          esClave: false,
          ultimaVerificacion: DateTime(2026, 5, 2),
          disponibilidadConfirmada: true,
          nivelDemanda: Producto.demandaMedia,
          rotacionSemanaAnterior: 63,
        ),
        Producto(
          id: 'prod-006',
          nombre: 'Leche evaporada',
          ubicacion: 'Pasillo C - Estante 3',
          cantidad: 15,
          tipoMedida: Producto.medidaUnidad,
          esClave: true,
          ultimaVerificacion: DateTime(2026, 4, 29),
          disponibilidadCorregida: true,
          nivelDemanda: Producto.demandaMedia,
          rotacionSemanaAnterior: 79,
        ),
        Producto(
          id: 'prod-007',
          nombre: 'Pasta alimenticia 1 lb',
          ubicacion: 'Pasillo D - Estante 1',
          cantidad: 20,
          tipoMedida: Producto.medidaUnidad,
          esClave: false,
          nivelDemanda: Producto.demandaMedia,
          rotacionSemanaAnterior: 71,
        ),
        Producto(
          id: 'prod-008',
          nombre: 'Salsa de tomate 8 oz',
          ubicacion: 'Pasillo D - Estante 2',
          cantidad: 16,
          tipoMedida: Producto.medidaUnidad,
          esClave: false,
          nivelDemanda: Producto.demandaMedia,
          rotacionSemanaAnterior: 69,
        ),
        Producto(
          id: 'prod-009',
          nombre: 'Harina de maiz 2 lb',
          ubicacion: 'Pasillo E - Estante 1',
          cantidad: 12,
          tipoMedida: Producto.medidaPeso,
          esClave: true,
          nivelDemanda: Producto.demandaAlta,
          rotacionSemanaAnterior: 83,
        ),
        Producto(
          id: 'prod-010',
          nombre: 'Galletas saladas',
          ubicacion: 'Pasillo E - Estante 3',
          cantidad: 22,
          tipoMedida: Producto.medidaUnidad,
          esClave: false,
          nivelDemanda: Producto.demandaMedia,
          rotacionSemanaAnterior: 67,
        ),
      ];

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
    productos = _productosIniciales;
    _cargarProductos();
  }

  @override
  void dispose() {
    _reporteTimer?.cancel();
    super.dispose();
  }

  int get productosClave => productos.where((p) => p.esClave).length;
  List<Producto> get _productosDisponiblesAuditoria => productos
      .where(AuditoriaHelper.tieneDisponibilidadEnInventario)
      .toList(growable: false);

  List<Producto> get _productosDisponiblesNoAuditadosHoy =>
      _productosDisponiblesAuditoria
          .where(
            (producto) => !_productosAuditadosHoyIds.contains(producto.id),
          )
          .toList(growable: false);

  List<Producto> get _productosParaReposicion => productos
      .where(OrdenCompraScreen.requiereReposicion)
      .toList(growable: false);

  bool get _auditoriaDiariaCompletadaHoy =>
      _esMismoDia(_auditoriaDiariaCompletadaFecha, DateTime.now());

  bool get _auditoriaSemanalDisponible =>
      AuditoriaHelper.esLunes() &&
      !_esMismaSemana(
        _auditoriaSemanalCompletadaFecha,
        DateTime.now(),
      );

  bool get _puedeIniciarAuditoria =>
      !_auditoriaDiariaCompletadaHoy || _auditoriaSemanalDisponible;

  bool get _siguienteAuditoriaEsSemanal =>
      _auditoriaDiariaCompletadaHoy && _auditoriaSemanalDisponible;

  int get _cantidadObjetivoAuditoria =>
      _siguienteAuditoriaEsSemanal ? 5 : 3;

  String get _textoBotonAuditoria =>
      _siguienteAuditoriaEsSemanal
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
    final productosGuardados = await StorageService.cargarProductos();
    await _cargarEstadoAuditorias();

    if (productosGuardados.isEmpty) {
      await StorageService.guardarProductos(_productosIniciales);
      if (!mounted) {
        return;
      }

      setState(() {
        productos = _productosIniciales;
      });
      await _cargarPlanAuditoriaPendiente();
      return;
    }

    if (!mounted) {
      return;
    }

    final productosCompletos = _agregarProductosInicialesFaltantes(
      productosGuardados,
    );

    if (productosCompletos.length != productosGuardados.length) {
      await StorageService.guardarProductos(productosCompletos);
    }

    setState(() {
      productos = productosCompletos;
    });
    await _cargarPlanAuditoriaPendiente();
  }

  List<Producto> _agregarProductosInicialesFaltantes(
    List<Producto> productosGuardados,
  ) {
    final porId = <String, Producto>{
      for (final producto in productosGuardados) producto.id: producto,
    };

    for (final producto in _productosIniciales) {
      final guardado = porId[producto.id];
      if (guardado == null) {
        porId[producto.id] = producto;
        continue;
      }

      porId[producto.id] = guardado.copyWith(
        tipoMedida: producto.tipoMedida,
        nivelDemanda: producto.nivelDemanda,
        rotacionSemanaAnterior: guardado.rotacionSemanaAnterior == 0
            ? producto.rotacionSemanaAnterior
            : guardado.rotacionSemanaAnterior,
      );
    }

    return porId.values.toList(growable: false);
  }

  Future<void> _cargarEstadoAuditorias() async {
    final diaria =
        await StorageService.cargarAuditoriaDiariaCompletadaFecha();
    final semanal =
        await StorageService.cargarAuditoriaSemanalCompletadaFecha();
    final auditadosHoy =
        await StorageService.cargarAuditoriaProductosDelDiaIds();

    if (!mounted) {
      return;
    }

    setState(() {
      _auditoriaDiariaCompletadaFecha = diaria;
      _auditoriaSemanalCompletadaFecha = semanal;
      _productosAuditadosHoyIds = auditadosHoy;
    });
  }

  Future<void> _guardarProductos() async {
    await StorageService.guardarProductos(productos);
  }

  Future<void> _cargarPlanAuditoriaPendiente() async {
    final inventarioService = InventarioService(productos: productos);
    final planBase = inventarioService.generarPlanAuditoria();
    final idsPendientes = await StorageService.cargarAuditoriaPendienteIds();
    final fechaPendiente = await StorageService.cargarAuditoriaPendienteFecha();

    final hoy = DateTime.now();
    final esMismoDiaPendiente =
        fechaPendiente != null &&
        fechaPendiente.year == hoy.year &&
        fechaPendiente.month == hoy.month &&
        fechaPendiente.day == hoy.day;

    final productosPendientes = idsPendientes
        .map((id) {
          for (final producto in productos) {
            if (producto.id == id) {
              return producto;
            }
          }
          return null;
        })
        .whereType<Producto>()
        .toList(growable: false);

    List<Producto> planFinal;

    if (idsPendientes.isEmpty) {
      planFinal = planBase.productos;
    } else if (esMismoDiaPendiente) {
      planFinal = productosPendientes;
    } else {
      final mapa = <String, Producto>{};

      for (final producto in productosPendientes) {
        mapa[producto.id] = producto;
      }

      for (final producto in planBase.productos) {
        mapa.putIfAbsent(producto.id, () => producto);
      }

      planFinal = mapa.values.toList(growable: false);
    }

    if (planFinal.isEmpty) {
      await StorageService.limpiarAuditoriaPendiente();
    } else {
      await StorageService.guardarAuditoriaPendiente(
        planFinal.map((producto) => producto.id).toList(growable: false),
        hoy,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      planAuditoriaProductos = planFinal;
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
        (a, b) =>
            b.rotacionSemanaAnterior.compareTo(a.rotacionSemanaAnterior),
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

  Future<void> _iniciarAuditoria() async {
    final cantidadObjetivo = _cantidadObjetivoAuditoria;
    final fueAuditoriaSemanal = _siguienteAuditoriaEsSemanal;
    final productosAuditar = _seleccionarProductosAuditoria(
      esSemanal: fueAuditoriaSemanal,
      cantidadObjetivo: cantidadObjetivo,
    );

    if (productosAuditar.length < cantidadObjetivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se necesitan al menos $cantidadObjetivo articulos disponibles no repetidos para auditar.',
          ),
        ),
      );
      return;
    }

    final resultados = await Navigator.push<List<AuditoriaResultado>>(
      context,
      MaterialPageRoute(
        builder: (_) => AuditoriaScreen(
          productos: productosAuditar,
          cantidadObjetivo: cantidadObjetivo,
          productosPreseleccionados: true,
        ),
      ),
    );

    if (resultados == null || resultados.isEmpty) {
      return;
    }

    final ahora = DateTime.now();
    final resultadosConDiferencias = resultados
        .where((resultado) => resultado.diferencia != 0)
        .toList(growable: false);
    final idsAuditados = resultados
        .map((resultado) => resultado.productoId)
        .toList(growable: false);

    setState(() {
      reportePendiente = _unirReportesPendientes(
        reportePendiente,
        resultadosConDiferencias,
      );
      productos = productos.map((producto) {
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
      }).toList(growable: false);
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
    await StorageService.limpiarAuditoriaPendiente();
    await _guardarProductos();
    if (fueAuditoriaSemanal) {
      await StorageService.guardarAuditoriaSemanalCompletada(ahora);
    } else {
      await StorageService.guardarAuditoriaDiariaCompletada(ahora);
    }
    await StorageService.guardarAuditoriaProductosDelDia(
      _productosAuditadosHoyIds,
      ahora,
    );

    if (mounted && resultadosConDiferencias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auditoria completada sin diferencias.'),
        ),
      );
    }
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
      productos = productos.map((producto) {
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
      }).toList(growable: false);
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hoyEsLunes = AuditoriaHelper.esLunes();
    final productosPendientes = productos
        .where(AuditoriaHelper.necesitaAuditoria)
        .toList(growable: false);

    return Scaffold(
      bottomNavigationBar: reportePendiente.isEmpty
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
                      side: const BorderSide(
                        color: Colors.black,
                        width: 2,
                      ),
                    ),
                    child: const Text('Validar reporte de Inventario'),
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding =
                AdaptiveLayout.contentInset(constraints.maxWidth);

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
                    children: [
                      if (Navigator.canPop(context)) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: 'Volver',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inventario',
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF17322C),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Controla stock, auditorias y validaciones.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF66756D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.groups_2_outlined),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            hoyEsLunes ? 'Modo lunes' : 'Modo diario',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '${productos.length} productos',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hoyEsLunes
                              ? 'Hoy se auditan hasta 5 productos clave.'
                              : 'Hoy se auditan hasta 3 productos aleatorios.',
                          style: const TextStyle(
                            color: Color(0xFFDCE9E5),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            hoyEsLunes
                                ? 'El plan usa productos clave con disponibilidad y evita los auditados con cierre en los ultimos 15 dias.'
                                : 'El plan diario usa solo productos con disponibilidad y evita auditorias cerradas dentro del ultimo mes.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _InventoryMetricTile(
                                label: 'Claves',
                                value: '$productosClave',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InventoryMetricTile(
                                label: 'Plan hoy',
                                value: _puedeIniciarAuditoria
                                    ? '${min(_cantidadObjetivoAuditoria, _productosDisponiblesNoAuditadosHoy.length)}'
                                    : '0',
                              ),
                            ),
                          ],
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
                        onPressed: _productosDisponiblesNoAuditadosHoy.length <
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Orden de compra',
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
                                  style: const TextStyle(
                                    color: Color(0xFF66756D),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
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
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                4,
                contentPadding,
                28,
              ),
              sliver: SliverList.builder(
                itemCount: productos.length,
                itemBuilder: (context, index) {
                  final producto = productos[index];
                  final requiereAuditoria =
                      AuditoriaHelper.necesitaAuditoria(producto);
                  final auditoriaCerrada =
                      AuditoriaHelper.tieneAuditoriaCerrada(producto);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: producto.esClave
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
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: producto.esClave
                                  ? const Color(0xFFFFF4DB)
                                  : const Color(0xFFE7F3EF),
                            ),
                            child: Icon(
                              producto.esClave
                                  ? Icons.priority_high_rounded
                                  : Icons.inventory_2_outlined,
                              color: producto.esClave
                                  ? const Color(0xFFB54708)
                                  : const Color(0xFF1F7A6B),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  producto.nombre,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF17322C),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'ID: ${producto.id}',
                                  style: const TextStyle(
                                    color: Color(0xFF66756D),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatearFecha(producto.ultimaVerificacion),
                                  style: const TextStyle(
                                    color: Color(0xFF66756D),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  producto.cantidad > 0
                                      ? 'Disponible en inventario'
                                      : 'Sin disponibilidad',
                                  style: TextStyle(
                                    color: producto.cantidad > 0
                                        ? const Color(0xFF1F7A6B)
                                        : const Color(0xFFB42318),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  producto.cantidad <= 0
                                      ? 'Sin disponibilidad en inventario'
                                      : auditoriaCerrada
                                          ? producto.disponibilidadCorregida
                                              ? 'Disponibilidad corregida'
                                              : 'Disponibilidad confirmada'
                                          : 'Auditoria sin cierre',
                                  style: TextStyle(
                                    color: producto.cantidad <= 0
                                        ? const Color(0xFFB42318)
                                        : auditoriaCerrada
                                            ? const Color(0xFF1F7A6B)
                                            : const Color(0xFFB54708),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  producto.requiereVerificacionAdministrador
                                      ? 'Verificacion por encargado, diferencias entre cantidades'
                                      : requiereAuditoria
                                          ? 'Necesita auditoria'
                                          : 'Auditoria al dia',
                                  style: TextStyle(
                                    color: producto
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
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: producto.esClave
                                      ? const Color(0xFFFFF4DB)
                                      : const Color(0xFFE7F3EF),
                                ),
                                child: Text(
                                  producto.esClave ? 'Clave' : 'Regular',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: producto.esClave
                                        ? const Color(0xFFB54708)
                                        : const Color(0xFF1F7A6B),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${producto.cantidad} uds',
                                style: const TextStyle(
                                  color: Color(0xFF17322C),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ],
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
  final String label;
  final String value;

  const _InventoryMetricTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFDCE9E5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
