import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/utils/money_formatter.dart';
import '../data/models/rendered_status_image.dart';
import '../data/models/subscription_sqlite_model.dart';
import '../data/models/whatsapp_campaign_publication.dart';
import '../data/repositories/whatsapp_campaign_repository.dart';
import '../data/services/whatsapp_status_campaign_service.dart';
import '../data/services/whatsapp_status_image_renderer.dart';
import '../models/producto.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/fiado_data_providers.dart';
import '../presentation/providers/sync_providers.dart';
import 'whatsapp_status_preview_screen.dart';

enum WhatsappCampaignMode { individual, catalogo }

class CreateWhatsappCampaignScreen extends ConsumerStatefulWidget {
  const CreateWhatsappCampaignScreen({super.key});

  @override
  ConsumerState<CreateWhatsappCampaignScreen> createState() =>
      _CreateWhatsappCampaignScreenState();
}

class _CreateWhatsappCampaignScreenState
    extends ConsumerState<CreateWhatsappCampaignScreen> {
  final _renderer = const WhatsappStatusImageRenderer();
  final _picker = ImagePicker();
  final _campaignRepository = WhatsappCampaignRepository();
  final _controllers = <String, TextEditingController>{};
  final _selected = <String>{};
  final _sourceImages = <String, String?>{};
  final _rendered = <String, RenderedStatusImage>{};
  final _rendering = <String>{};
  WhatsappCampaignMode _mode = WhatsappCampaignMode.catalogo;
  bool _publishing = false;
  String? _lastPublicationStatus;
  DateTime? _estimatedExpiresAt;
  List<WhatsappCampaignPublication> _history = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadHistory);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productosProvider);
    final user = ref.watch(currentUserProvider);
    final subscription = ref.watch(currentSubscriptionProvider).valueOrNull;
    final limits = _CampaignLimits.fromSubscription(subscription);
    final negocioId = ref.watch(currentBusinessIdProvider) ?? 0;
    final usedToday = _history
        .where((item) {
          return item.negocioId == negocioId &&
              item.dateKey == _dateKey(DateTime.now()) &&
              item.consumesQuota &&
              WhatsappCampaignPublicationStatus.usadosDelDia.contains(
                item.status,
              );
        })
        .fold<int>(0, (total, item) => total + item.quotaUnits);

    return Scaffold(
      appBar: AppBar(title: const Text('Campana Estados WhatsApp')),
      body: SafeArea(
        child: productsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            message: 'No se pudo cargar inventario: $error',
            onRetry: () => ref.read(productosProvider.notifier).recargar(),
          ),
          data: (state) {
            final products = state.productos;
            _ensureControllers(products);
            final available = products
                .where((product) => product.cantidad > 0)
                .toList(growable: false);
            final unavailable = products.length - available.length;
            final selectedCount = _selected.length;

            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CampaignHeader(
                            selectedCount: selectedCount,
                            unavailableCount: unavailable,
                            usedToday: usedToday,
                            dailyLimit: limits.dailyPublications,
                            maxProducts: limits.maxProductsPerPublication,
                          ),
                          const SizedBox(height: 14),
                          SegmentedButton<WhatsappCampaignMode>(
                            segments: const [
                              ButtonSegment(
                                value: WhatsappCampaignMode.catalogo,
                                icon: Icon(Icons.dashboard_outlined),
                                label: Text('Catalogo'),
                              ),
                              ButtonSegment(
                                value: WhatsappCampaignMode.individual,
                                icon: Icon(Icons.crop_portrait_outlined),
                                label: Text('Individual'),
                              ),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (value) {
                              setState(() => _mode = value.first);
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _mode == WhatsappCampaignMode.catalogo
                                ? 'Varios productos forman una publicacion del dia.'
                                : 'Cada producto seleccionado cuenta como publicacion independiente.',
                            style: const TextStyle(color: Color(0xFF66756D)),
                          ),
                          const SizedBox(height: 20),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _ProductSelectionList(
                                    products: available,
                                    selected: _selected,
                                    sourceImages: _sourceImages,
                                    rendered: _rendered,
                                    rendering: _rendering,
                                    controllers: _controllers,
                                    renderer: _renderer,
                                    onChanged: () => setState(() {}),
                                    onPickImage: _pickImage,
                                    onPreview: (product) => _previewProduct(
                                      product,
                                      user?.nombre ?? 'Mi negocio',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 320,
                                  child: _CampaignActions(
                                    canPublish: selectedCount > 0,
                                    publishing: _publishing,
                                    status: _lastPublicationStatus,
                                    expiresAt: _estimatedExpiresAt,
                                    onPublish: () => _publish(
                                      limits,
                                      user?.nombre ?? 'Mi negocio',
                                    ),
                                    history: _history,
                                    onRetry: _retryPublication,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _ProductSelectionList(
                              products: available,
                              selected: _selected,
                              sourceImages: _sourceImages,
                              rendered: _rendered,
                              rendering: _rendering,
                              controllers: _controllers,
                              renderer: _renderer,
                              onChanged: () => setState(() {}),
                              onPickImage: _pickImage,
                              onPreview: (product) => _previewProduct(
                                product,
                                user?.nombre ?? 'Mi negocio',
                              ),
                            ),
                            const SizedBox(height: 16),
                            _CampaignActions(
                              canPublish: selectedCount > 0,
                              publishing: _publishing,
                              status: _lastPublicationStatus,
                              expiresAt: _estimatedExpiresAt,
                              onPublish: () => _publish(
                                limits,
                                user?.nombre ?? 'Mi negocio',
                              ),
                              history: _history,
                              onRetry: _retryPublication,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadHistory() async {
    final negocioId = ref.read(currentBusinessIdProvider);
    if (negocioId == null) return;
    final history = await _campaignRepository.obtenerHistorial(
      negocioId: negocioId,
    );
    if (!mounted) return;
    setState(() => _history = history);
  }

  void _ensureControllers(List<Producto> products) {
    for (final product in products) {
      _controllers.putIfAbsent(
        product.id,
        () => TextEditingController(text: _defaultStatusText(product)),
      );
    }
  }

  String _defaultStatusText(Producto product) {
    final text = product.nombre.trim();
    return text.length <= whatsappStatusMaxTextLength
        ? text
        : text.substring(0, whatsappStatusMaxTextLength);
  }

  Future<void> _pickImage(Producto product) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: whatsappStatusWidth.toDouble(),
      maxHeight: whatsappStatusHeight.toDouble(),
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() {
      _sourceImages[product.id] = picked.path;
      _rendered.remove(product.id);
    });
  }

  Future<String?> _resolveSourceImage(Producto product) async {
    final selected = _sourceImages[product.id];
    if (selected != null && selected.isNotEmpty) return selected;
    final negocioId = ref.read(currentBusinessIdProvider);
    if (negocioId == null) return null;
    try {
      await ref
          .read(inventoryMediaSyncServiceProvider)
          .downloadForProductUuids(
            negocioId: negocioId,
            productUuids: [product.id],
            metadataLimit: 3,
            contentLimit: 1,
          );
    } catch (error) {
      if (mounted) {
        _showMessage('No se pudo descargar la imagen del articulo.');
      }
    }
    final productId = await ref
        .read(productoRepositoryProvider)
        .obtenerIdSqlitePorLegacyId(product.id, negocioId: negocioId);
    if (productId == null) return null;
    final images = await ref
        .read(productoImagenRepositoryProvider)
        .obtenerImagenesPorProducto(productId, negocioId: negocioId);
    if (images.isEmpty) return null;
    return images.first.localPath;
  }

  Future<RenderedStatusImage?> _renderProduct(
    Producto product,
    String businessName,
  ) async {
    final text = _controllers[product.id]?.text.trim() ?? '';
    final validation = _renderer.validateStatusText(text);
    if (validation != null) {
      _showMessage(validation);
      return null;
    }
    if (product.cantidad <= 0) {
      _showMessage('${product.nombre} no disponible hoy.');
      return null;
    }

    setState(() => _rendering.add(product.id));
    try {
      final source = await _resolveSourceImage(product);
      if (source == null && mounted) {
        _showMessage(
          'Este articulo no tiene imagen; se generara un diseno simple.',
        );
      }
      final rendered = await _renderer.renderProductStatusImage(
        productId: product.id,
        sourceImagePath: source,
        statusText: text,
        salePrice: product.precioVenta,
        businessName: businessName,
        description: product.descripcion,
        availableToday: product.cantidad > 0,
      );
      if (!mounted) return rendered;
      setState(() {
        _sourceImages[product.id] = source;
        _rendered[product.id] = rendered;
      });
      return rendered;
    } catch (error) {
      _showMessage('$error');
      return null;
    } finally {
      if (mounted) setState(() => _rendering.remove(product.id));
    }
  }

  Future<void> _previewProduct(Producto product, String businessName) async {
    final rendered = await _renderProduct(product, businessName);
    if (rendered == null || !mounted) return;
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WhatsappStatusPreviewScreen(renderedImage: rendered),
      ),
    );
    if (accepted == true && mounted) {
      setState(() => _selected.add(product.id));
    }
  }

  Future<void> _publish(_CampaignLimits limits, String businessName) async {
    final selectedIds = _selected.toList();
    if (selectedIds.isEmpty) return;
    final negocioId = ref.read(currentBusinessIdProvider);
    if (negocioId == null) {
      _showMessage('No se pudo identificar el negocio.');
      return;
    }

    final publicationUnits = _mode == WhatsappCampaignMode.individual
        ? selectedIds.length
        : 1;
    final usedToday = await _campaignRepository.contarPublicacionesUsadasHoy(
      negocioId: negocioId,
      date: DateTime.now(),
    );
    if (usedToday + publicationUnits > limits.dailyPublications) {
      _showMessage(
        'Tu plan permite ${limits.dailyPublications} publicaciones por dia. Hoy llevas $usedToday.',
      );
      return;
    }
    if (selectedIds.length > limits.maxProductsPerPublication) {
      _showMessage(
        'Tu plan permite hasta ${limits.maxProductsPerPublication} productos por publicacion.',
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      await ref.read(productosProvider.notifier).recargar();
      final freshProducts =
          ref.read(productosProvider).valueOrNull?.productos ??
          const <Producto>[];
      final selectedProducts = freshProducts
          .where((product) => selectedIds.contains(product.id))
          .where((product) => product.cantidad > 0)
          .toList(growable: false);
      final excluded = selectedIds.length - selectedProducts.length;
      if (selectedProducts.isEmpty) {
        _showMessage('No hay productos disponibles para publicar hoy.');
        return;
      }

      final renderedImages = <RenderedStatusImage>[];
      for (final product in selectedProducts) {
        final rendered = await _renderProduct(product, businessName);
        if (rendered != null) renderedImages.add(rendered);
      }
      if (renderedImages.isEmpty) return;

      final publication =
          await WhatsappStatusCampaignService(
            repository: _campaignRepository,
          ).crearPublicacionPendiente(
            negocioId: negocioId,
            mode: _mode.name,
            productIds: selectedProducts.map((product) => product.id).toList(),
            renderedImages: renderedImages,
            quotaUnits: publicationUnits,
          );

      final accepted = await _confirmQuotaConsumption();
      if (accepted != true) {
        _showMessage('Publicacion pendiente. No se consumio cupo.');
        await _loadHistory();
        return;
      }

      final openedPublication = await WhatsappStatusCampaignService(
        repository: _campaignRepository,
      ).compartirPublicacion(publication);
      await _loadHistory();
      if (openedPublication.status ==
          WhatsappCampaignPublicationStatus.fallidoAntesDeAbrirWhatsapp) {
        _showMessage(
          'No se pudo abrir WhatsApp o el menu de compartir. No se consumio cupo.',
        );
        return;
      }
      if (!mounted) return;
      setState(() => _lastPublicationStatus = 'enviado_a_whatsapp');
      final confirmed = await _askManualConfirmation(excluded);
      if (confirmed == true && mounted) {
        final updated = await _campaignRepository.registrarConfirmacionUsuario(
          openedPublication,
        );
        setState(() {
          _lastPublicationStatus = 'confirmado_por_usuario';
          _estimatedExpiresAt = updated.estimatedExpiresAt;
        });
        await _loadHistory();
        _showMessage(
          'Vigencia estimada. WhatsApp no confirma esta informacion directamente a Fiado App.',
        );
      } else if (mounted) {
        final updated = await _campaignRepository.registrarCancelacionUsuario(
          openedPublication,
        );
        setState(() {
          _lastPublicationStatus = updated.status;
          _estimatedExpiresAt = updated.estimatedExpiresAt;
        });
        await _loadHistory();
        _showMessage(
          'Esta publicacion contara como usada porque WhatsApp fue abierto correctamente. Puedes volver a publicar manana o usar otro cupo disponible segun tu plan.',
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<bool?> _confirmQuotaConsumption() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Abrir WhatsApp'),
        content: const Text(
          'Al continuar, esta publicacion contara como usada en tu limite diario una vez WhatsApp se abra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _askManualConfirmation(int excluded) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar publicacion'),
        content: Text(
          'Fiado App abrio WhatsApp con tu publicacion. Por seguridad, esta publicacion ya cuenta dentro de tu limite diario aunque decidas no publicarla.\n\n${excluded > 0 ? 'Se excluyeron $excluded productos no disponibles.\n\n' : ''}Confirmas que publicaste estos estados?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No publique'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Si, ya publique'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryPublication(
    WhatsappCampaignPublication publication,
  ) async {
    setState(() => _publishing = true);
    try {
      final retried = await WhatsappStatusCampaignService(
        repository: _campaignRepository,
      ).reintentarMismaPublicacion(publication);
      await _loadHistory();
      if (!mounted) return;
      if (retried.status ==
          WhatsappCampaignPublicationStatus.fallidoAntesDeAbrirWhatsapp) {
        _showMessage('No se pudo abrir WhatsApp. No se consumio cupo extra.');
        return;
      }
      setState(() => _lastPublicationStatus = retried.status);
      final confirmed = await _askManualConfirmation(0);
      if (confirmed == true && mounted) {
        final updated = await _campaignRepository.registrarConfirmacionUsuario(
          retried,
        );
        setState(() {
          _lastPublicationStatus = updated.status;
          _estimatedExpiresAt = updated.estimatedExpiresAt;
        });
      } else if (mounted) {
        await _campaignRepository.registrarCancelacionUsuario(retried);
        setState(() => _lastPublicationStatus = 'cancelado_por_usuario');
      }
      await _loadHistory();
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _dateKey(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }
}

class _CampaignLimits {
  final int dailyPublications;
  final int maxProductsPerPublication;

  const _CampaignLimits({
    required this.dailyPublications,
    required this.maxProductsPerPublication,
  });

  factory _CampaignLimits.fromSubscription(SubscriptionSqliteModel? model) {
    switch (model?.planId) {
      case 'empresarial':
        return const _CampaignLimits(
          dailyPublications: 5,
          maxProductsPerPublication: 20,
        );
      case 'crecimiento':
        return const _CampaignLimits(
          dailyPublications: 3,
          maxProductsPerPublication: 15,
        );
      case 'basico':
      default:
        return const _CampaignLimits(
          dailyPublications: 1,
          maxProductsPerPublication: 15,
        );
    }
  }
}

class _CampaignHeader extends StatelessWidget {
  final int selectedCount;
  final int unavailableCount;
  final int usedToday;
  final int dailyLimit;
  final int maxProducts;

  const _CampaignHeader({
    required this.selectedCount,
    required this.unavailableCount,
    required this.usedToday,
    required this.dailyLimit,
    required this.maxProducts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F3EF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estados con imagen renderizada',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Color(0xFF17322C),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cada flyer se genera en 720 x 1280 px con franja inferior y texto dentro de la imagen.',
            style: TextStyle(color: Color(0xFF66756D)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: '$selectedCount seleccionados'),
              _InfoChip(label: 'Max. $maxProducts productos'),
              _InfoChip(label: '$usedToday/$dailyLimit publicaciones hoy'),
              if (unavailableCount > 0)
                _InfoChip(label: '$unavailableCount no disponibles'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductSelectionList extends StatelessWidget {
  final List<Producto> products;
  final Set<String> selected;
  final Map<String, String?> sourceImages;
  final Map<String, RenderedStatusImage> rendered;
  final Set<String> rendering;
  final Map<String, TextEditingController> controllers;
  final WhatsappStatusImageRenderer renderer;
  final VoidCallback onChanged;
  final Future<void> Function(Producto product) onPickImage;
  final Future<void> Function(Producto product) onPreview;

  const _ProductSelectionList({
    required this.products,
    required this.selected,
    required this.sourceImages,
    required this.rendered,
    required this.rendering,
    required this.controllers,
    required this.renderer,
    required this.onChanged,
    required this.onPickImage,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No hay productos disponibles para publicar hoy.'),
        ),
      );
    }

    return Column(
      children: [
        for (final product in products)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ProductCampaignCard(
              product: product,
              selected: selected.contains(product.id),
              hasSourceImage:
                  (sourceImages[product.id]?.trim().isNotEmpty ?? false),
              hasRenderedImage: rendered.containsKey(product.id),
              rendering: rendering.contains(product.id),
              controller: controllers[product.id]!,
              renderer: renderer,
              onSelected: (value) {
                value ? selected.add(product.id) : selected.remove(product.id);
                onChanged();
              },
              onPickImage: () => onPickImage(product),
              onPreview: () => onPreview(product),
              onTextChanged: () {
                rendered.remove(product.id);
                onChanged();
              },
            ),
          ),
      ],
    );
  }
}

class _ProductCampaignCard extends StatelessWidget {
  final Producto product;
  final bool selected;
  final bool hasSourceImage;
  final bool hasRenderedImage;
  final bool rendering;
  final TextEditingController controller;
  final WhatsappStatusImageRenderer renderer;
  final ValueChanged<bool> onSelected;
  final VoidCallback onPickImage;
  final VoidCallback onPreview;
  final VoidCallback onTextChanged;

  const _ProductCampaignCard({
    required this.product,
    required this.selected,
    required this.hasSourceImage,
    required this.hasRenderedImage,
    required this.rendering,
    required this.controller,
    required this.renderer,
    required this.onSelected,
    required this.onPickImage,
    required this.onPreview,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final validation = renderer.validateStatusText(controller.text);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? const Color(0xFF1F7A6B) : const Color(0xFFD9E8E3),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1017322C),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) => onSelected(v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF17322C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stock ${product.cantidad} - ${MoneyFormatter.formatCurrency(product.precioVenta)}',
                      style: const TextStyle(color: Color(0xFF66756D)),
                    ),
                  ],
                ),
              ),
              Icon(
                hasRenderedImage
                    ? Icons.check_circle_rounded
                    : Icons.image_outlined,
                color: hasRenderedImage
                    ? const Color(0xFF1F7A6B)
                    : const Color(0xFF66756D),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLength: whatsappStatusMaxTextLength,
            decoration: InputDecoration(
              labelText: 'Texto del estado',
              helperText: 'Obligatorio, maximo 30 caracteres.',
              errorText: validation,
            ),
            onChanged: (_) => onTextChanged(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onPickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  hasSourceImage ? 'Cambiar imagen' : 'Cargar imagen',
                ),
              ),
              OutlinedButton.icon(
                onPressed: rendering ? null : onPreview,
                icon: rendering
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_outlined),
                label: Text(rendering ? 'Generando' : 'Preview'),
              ),
              if (!hasSourceImage)
                const _InfoChip(label: 'Sin imagen: flyer simple'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CampaignActions extends StatelessWidget {
  final bool canPublish;
  final bool publishing;
  final String? status;
  final DateTime? expiresAt;
  final VoidCallback onPublish;
  final List<WhatsappCampaignPublication> history;
  final ValueChanged<WhatsappCampaignPublication> onRetry;

  const _CampaignActions({
    required this.canPublish,
    required this.publishing,
    required this.status,
    required this.expiresAt,
    required this.onPublish,
    required this.history,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Publicacion',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fiado App comparte imagenes ya renderizadas. WhatsApp no confirma automaticamente los estados.',
            style: TextStyle(color: Color(0xFF66756D)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: canPublish && !publishing ? onPublish : null,
            icon: publishing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(publishing ? 'Preparando' : 'Publicar en WhatsApp'),
          ),
          if (status != null) ...[
            const SizedBox(height: 12),
            _InfoChip(label: status!),
          ],
          if (expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Vigencia estimada: ${expiresAt!.hour.toString().padLeft(2, '0')}:${expiresAt!.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Color(0xFF66756D)),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Historial',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            const Text(
              'Sin publicaciones registradas.',
              style: TextStyle(color: Color(0xFF66756D)),
            )
          else
            for (final publication in history.take(6))
              _PublicationHistoryTile(
                publication: publication,
                onRetry: () => onRetry(publication),
              ),
        ],
      ),
    );
  }
}

class _PublicationHistoryTile extends StatelessWidget {
  final WhatsappCampaignPublication publication;
  final VoidCallback onRetry;

  const _PublicationHistoryTile({
    required this.publication,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final created = publication.createdAt;
    final date =
        '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17322C),
                  ),
                ),
              ),
              _InfoChip(
                label: publication.consumesQuota ? 'Cupo usado' : 'Sin cupo',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            publication.status,
            style: const TextStyle(color: Color(0xFF66756D)),
          ),
          const SizedBox(height: 4),
          Text(
            '${publication.productIds.length} articulos incluidos - ${publication.quotaUnits} cupos',
            style: const TextStyle(color: Color(0xFF66756D)),
          ),
          if (publication.estimatedExpiresAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Vigencia estimada: ${publication.estimatedExpiresAt!.hour.toString().padLeft(2, '0')}:${publication.estimatedExpiresAt!.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Color(0xFF66756D)),
            ),
          ],
          if (publication.puedeReintentarMismaPublicacion) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.replay_outlined),
              label: const Text('Reintentar misma publicacion'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFFE7F3EF),
      labelStyle: const TextStyle(
        color: Color(0xFF17322C),
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide.none,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
