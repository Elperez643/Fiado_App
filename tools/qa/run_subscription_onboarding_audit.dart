import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = _stringOption(args, 'db') ?? 'qa_data/offline_first_audit.db';
  final file = File(dbPath);
  if (!await file.exists()) {
    stdout.writeln('SUBSCRIPTION_ONBOARDING_AUDIT');
    stdout.writeln('database: ${file.absolute.path}');
    stdout.writeln('status: DB_NOT_FOUND');
    stdout.writeln('No se ejecuto reset ni se crearon datos.');
    return;
  }

  final db = await databaseFactory.openDatabase(file.absolute.path);
  try {
    final users = await db.query(DatabaseSchema.usuariosTable, orderBy: 'id');
    final subscriptions = await db.query(
      DatabaseSchema.subscriptionsTable,
      orderBy: 'id DESC',
    );
    final sessions = await db.query(
      DatabaseSchema.sesionesTable,
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'last_active_at DESC',
    );

    stdout.writeln('SUBSCRIPTION_ONBOARDING_AUDIT');
    stdout.writeln('database: ${file.absolute.path}');
    stdout.writeln('usuarios_locales: ${users.length}');
    stdout.writeln(
      'negocios_locales: ${users.where((u) => u['tipo_usuario'] == 'negocio').length}',
    );
    stdout.writeln('sesion_local_activa: ${sessions.isNotEmpty}');
    stdout.writeln(
      'cloud_token_state: ${sessions.any((s) => (s['jwt_token'] as String?)?.trim().isNotEmpty == true) ? 'local_session_token' : 'secure_storage_or_absent'}',
    );
    stdout.writeln('');
    stdout.writeln(
      'business_id,phone,subscription_status,trial_state,has_payment_method,trial_used,offline_allowed',
    );

    for (final user in users.where((u) => u['tipo_usuario'] == 'negocio')) {
      final id = user['id'] as int;
      final sub = subscriptions.cast<Map<String, Object?>>().firstWhere(
        (s) => s['usuario_id'] == id,
        orElse: () => const <String, Object?>{},
      );
      final status = sub['status']?.toString() ?? 'missing';
      final trialEndsAt = DateTime.tryParse(
        sub['trial_ends_at']?.toString() ?? '',
      );
      final now = DateTime.now();
      final trialState = trialEndsAt == null
          ? 'missing'
          : trialEndsAt.isAfter(now)
          ? 'active_until_${trialEndsAt.toIso8601String()}'
          : 'expired_${trialEndsAt.toIso8601String()}';
      final paymentProvider = sub['payment_provider']?.toString();
      final hasPaymentMethod =
          paymentProvider == 'stripe' ||
          paymentProvider == 'mock' ||
          status == 'active' ||
          status == 'trial_active';
      final trialUsed =
          status == 'trial_active' ||
          status == 'active' ||
          status == 'past_due' ||
          status == 'expired' ||
          status == 'canceled';
      final offlineAllowed = status == 'trial_active' || status == 'active';
      stdout.writeln(
        '$id,${user['telefono']},$status,$trialState,$hasPaymentMethod,$trialUsed,$offlineAllowed',
      );
    }
  } finally {
    await db.close();
  }
}

String? _stringOption(List<String> args, String name) {
  final prefix = '--$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  final index = args.indexOf('--$name');
  if (index >= 0 && index + 1 < args.length) return args[index + 1];
  return null;
}
