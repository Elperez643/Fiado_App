import 'dart:io';

const blockedOfficialPricePatterns = <String>[
  r'RD\$\s*700\b',
  r'RD\$\s*1,?500\b',
  r'RD\$\s*2,?800\b',
  r'USD\s*700\b',
  r'USD\s*1,?500\b',
  r'USD\s*2,?800\b',
];

const excludedPathParts = <String>[
  '.git',
  '.dart_tool',
  'build',
  'dist',
  'qa_data',
  '.codex_',
];

Future<void> main() async {
  final root = Directory.current;
  final files = await root
      .list(recursive: true, followLinks: false)
      .where((entity) => entity is File)
      .cast<File>()
      .where(_shouldScan)
      .toList();

  final violations = <String>[];
  final regexes = blockedOfficialPricePatterns
      .map((pattern) => RegExp(pattern, caseSensitive: false))
      .toList();

  for (final file in files) {
    final content = await file.readAsString();
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isAllowedObsoleteReference(line)) {
        continue;
      }
      for (final regex in regexes) {
        if (regex.hasMatch(line)) {
          violations.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
  }

  _validateFlutterCatalog();
  _validateBackendCatalog();

  if (violations.isNotEmpty) {
    stderr.writeln('Old subscription prices found as official visible values:');
    for (final violation in violations) {
      stderr.writeln(violation);
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Subscription price validation OK');
  stdout.writeln(
    'Flutter source of truth: lib/core/constants/subscription_plans.dart',
  );
  stdout.writeln(
    'Backend source of truth: backend/src/FiadoApp.Api/Subscriptions/SubscriptionPlanCatalog.cs',
  );
}

bool _isAllowedObsoleteReference(String line) {
  final normalized = line.toLowerCase();
  return normalized.contains('obsoleto') ||
      normalized.contains('obsoletos') ||
      normalized.contains('historico') ||
      normalized.contains('historicos') ||
      normalized.contains('histórico') ||
      normalized.contains('históricos') ||
      normalized.contains('viejo') ||
      normalized.contains('viejos');
}

bool _shouldScan(File file) {
  final normalized = file.path.replaceAll('\\', '/');
  if (excludedPathParts.any((part) => normalized.contains('/$part/'))) {
    return false;
  }
  return normalized.endsWith('.dart') ||
      normalized.endsWith('.cs') ||
      normalized.endsWith('.md') ||
      normalized.endsWith('.json') ||
      normalized.endsWith('.yaml') ||
      normalized.endsWith('.yml');
}

void _validateFlutterCatalog() {
  final file = File('lib/core/constants/subscription_plans.dart');
  final content = file.readAsStringSync();
  final expected = <String>['4.99', '12.99', '20.99'];
  for (final value in expected) {
    if (!content.contains('precioMensual: $value')) {
      throw StateError('Missing Flutter subscription price $value');
    }
  }
}

void _validateBackendCatalog() {
  final file = File(
    'backend/src/FiadoApp.Api/Subscriptions/SubscriptionPlanCatalog.cs',
  );
  final content = file.readAsStringSync();
  final expected = <String>['4.99m', '12.99m', '20.99m'];
  for (final value in expected) {
    if (!content.contains(value)) {
      throw StateError('Missing backend subscription price $value');
    }
  }
}
