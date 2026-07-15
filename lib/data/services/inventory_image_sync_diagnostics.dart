import 'dart:convert';

import '../models/sync_outbox_item.dart';

class InventoryImageSyncDiagnostics {
  static String pushRequestLog({
    required Uri endpoint,
    required String module,
    required Map<String, Object?> body,
    required List<SyncOutboxItem> items,
  }) {
    final originalJson = jsonEncode(body);
    final images = body['images'] as List<Object?>? ?? const [];
    final firstImage = images.isEmpty ? null : images.first;
    final firstImageMap = firstImage is Map
        ? Map<String, Object?>.from(firstImage)
        : const <String, Object?>{};
    return jsonEncode({
      'endpoint': endpoint.toString(),
      'module': module,
      'itemCount': items.length,
      'rootKeys': body.keys.toList(growable: false),
      'firstItemKeys': firstImageMap.keys.toList(growable: false),
      'payloadBytes': utf8.encode(originalJson).length,
      'events': items
          .map(
            (item) => {
              'outboxId': item.id,
              'changeId': item.uuid,
              'entityType': item.entityType,
              'entityUuid': item.entityUuid,
              'imageId': item.payloadAsMap()['uuid'],
              'productId': item.payloadAsMap()['productUuid'],
              'attemptCountBefore': item.attemptCount,
              'attemptCountSent': item.attemptCount + 1,
            },
          )
          .toList(growable: false),
      'json': redact(body),
    });
  }

  static String failedEventsLog(List<SyncOutboxItem> items) => jsonEncode(
    items
        .map(
          (item) => {
            'outboxId': item.id,
            'changeId': item.uuid,
            'entityUuid': item.entityUuid,
            'imageId': item.payloadAsMap()['uuid'],
            'productId': item.payloadAsMap()['productUuid'],
            'attemptCountBefore': item.attemptCount,
            'attemptCountSent': item.attemptCount + 1,
          },
        )
        .toList(growable: false),
  );

  static Object? redact(Object? value, {String? key}) {
    if (value is Map) {
      return value.map<String, Object?>((rawKey, rawValue) {
        final childKey = rawKey.toString();
        return MapEntry(childKey, redact(rawValue, key: childKey));
      });
    }
    if (value is List) {
      return value.map((item) => redact(item, key: key)).toList();
    }
    final normalizedKey = (key ?? '').replaceAll('_', '').toLowerCase();
    if (normalizedKey.contains('token') || normalizedKey.contains('password')) {
      return '[redacted]';
    }
    if (value is String &&
        (normalizedKey.contains('base64') ||
            normalizedKey == 'imagedata' ||
            normalizedKey == 'imagecontent' ||
            normalizedKey == 'contentdata')) {
      return {
        'length': value.length,
        'prefix': value.substring(0, value.length < 20 ? value.length : 20),
      };
    }
    return value;
  }
}
