import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class SyncDeviceIdentityService {
  static const _deviceIdKey = 'fiado_sync_device_id';

  final Future<SharedPreferences> sharedPreferences;

  const SyncDeviceIdentityService({required this.sharedPreferences});

  Future<String> getOrCreateDeviceId() async {
    final prefs = await sharedPreferences;
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;
    final created = _newDeviceId();
    await prefs.setString(_deviceIdKey, created);
    return created;
  }
}

String _newDeviceId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  return 'device-${hex.join()}';
}
