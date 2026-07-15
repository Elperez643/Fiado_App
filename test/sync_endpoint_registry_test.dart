import 'package:fiado_app/data/services/sync_endpoint_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('todos los modulos automaticos conocidos tienen endpoint valido', () {
    const expectedModules = {
      'clients',
      'movements',
      'inventory',
      'audits',
      'collaborators',
      'whatsapp',
      'inventory_images',
    };

    expect(SyncEndpointRegistry.definitions.keys.toSet(), expectedModules);
    for (final definition in SyncEndpointRegistry.definitions.values) {
      expect(definition.pushPath, startsWith('/api/sync/'));
      expect(definition.pushPath, endsWith('/push'));
      expect(definition.pullPath, endsWith('/pull'));
      expect(definition.httpPath, isNot(contains('_')));
    }
  });

  test('inventory_images conserva identidad local y traduce ruta HTTP', () {
    final definition = SyncEndpointRegistry.forModule('inventory_images');

    expect(definition.localModule, 'inventory_images');
    expect(definition.pushPath, '/api/sync/inventory/images/push');
    expect(definition.pullPath, '/api/sync/inventory/images/pull');
    expect(definition.supportsGlobalPull, isFalse);
    expect(
      definition.pushPayloadShape,
      SyncPushPayloadShape.inventoryImageMetadata,
    );
  });

  test('modulo desconocido no genera endpoint automatico incorrecto', () {
    expect(
      () => SyncEndpointRegistry.forModule('debt_items'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('todos los endpoints legacy se resuelven desde un unico registro', () {
    const expectedHandlers = {
      'clients',
      'products',
      'product_images',
      'movements',
      'debt_items',
      'receipts',
      'credit_cycles',
      'audits',
      'audit_items',
      'authorization_requests',
      'client_scores',
      'whatsapp_campaigns',
    };

    expect(
      LegacySyncEndpointRegistry.definitions.keys.toSet(),
      expectedHandlers,
    );
    for (final definition in LegacySyncEndpointRegistry.definitions.values) {
      expect(definition.pushPath, isNot(contains('_')));
      expect(definition.pullPath, isNot(contains('_')));
    }
  });
}
