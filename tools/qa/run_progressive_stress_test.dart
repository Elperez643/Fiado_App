import 'dart:io';

Future<void> main(List<String> args) async {
  final scales = <_Scale>[
    const _Scale(clients: 1000, products: 500),
    const _Scale(clients: 10000, products: 2000),
    const _Scale(clients: 50000, products: 5000),
    const _Scale(clients: 100000, products: 10000),
  ];
  final results = <_ScaleResult>[];

  for (final scale in scales) {
    stdout.writeln('Running stress scale: ${scale.clients} clients');
    final dbPath = 'qa_data/stress_${scale.clients}.db';
    try {
      final generate = await _runDart([
        'tools/qa/generate_stress_sqlite_data.dart',
        '--clients=${scale.clients}',
        '--products=${scale.products}',
        '--movements=${scale.movements}',
        '--debt-items=${scale.debtItems}',
        '--credit-cycles=${scale.creditCycles}',
        '--sync-queue=${scale.syncQueue}',
        '--audits=${scale.audits}',
        '--output=$dbPath',
        '--reset',
      ]);
      final benchmark = await _runDart([
        'tools/qa/benchmark_sqlite_queries.dart',
        '--db=$dbPath',
      ]);
      results.add(
        _ScaleResult(
          scale: scale,
          generated: _parseKeyValues(generate.stdout),
          metrics: _parseMetrics(benchmark.stdout),
          generateExitCode: generate.exitCode,
          benchmarkExitCode: benchmark.exitCode,
        ),
      );
    } catch (error) {
      results.add(
        _ScaleResult(
          scale: scale,
          generated: {'error': error.toString()},
          metrics: const <String, String>{},
          generateExitCode: 1,
          benchmarkExitCode: 1,
        ),
      );
      await _writeResults(results);
      rethrow;
    }
    await _writeResults(results);
  }

  await _writeResults(results);
}

Future<void> _writeResults(List<_ScaleResult> results) async {
  final output = File('STRESS_TEST_RESULTS.md');
  await output.writeAsString(_renderMarkdown(results));
  stdout.writeln('Wrote partial results to ${output.absolute.path}');
}

Future<ProcessResult> _runDart(List<String> arguments) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    arguments,
    runInShell: true,
  ).timeout(const Duration(minutes: 20));
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  return result;
}

Map<String, String> _parseKeyValues(String output) {
  final values = <String, String>{};
  for (final line in output.split(RegExp(r'\r?\n'))) {
    final index = line.indexOf(':');
    if (index <= 0) continue;
    values[line.substring(0, index).trim()] = line.substring(index + 1).trim();
  }
  return values;
}

Map<String, String> _parseMetrics(String output) {
  final values = <String, String>{};
  for (final line in output.split(RegExp(r'\r?\n'))) {
    final parts = line.split(',');
    if (parts.length < 2 || parts.first == 'metric') continue;
    values[parts[0]] = parts[1];
  }
  return values;
}

String _renderMarkdown(List<_ScaleResult> results) {
  final buffer = StringBuffer()
    ..writeln('# Stress Test Results')
    ..writeln()
    ..writeln('Generated with `tools/qa/run_progressive_stress_test.dart`.')
    ..writeln()
    ..writeln('## Summary')
    ..writeln()
    ..writeln(
      '| Clientes | Insert clientes ms | Page 50 ms | Page 100 ms | Search nombre ms | Search telefono ms | Movs cliente ms | CxC count ms | Vencidos ms | Sync pending ms | Dashboard ms | DB MB | Estado |',
    )
    ..writeln(
      '| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |',
    );

  for (final result in results) {
    final status = result.generateExitCode == 0 && result.benchmarkExitCode == 0
        ? 'OK'
        : 'FAILED';
    buffer.writeln(
      '| ${result.scale.clients} '
      '| ${result.generated['insert_clients_ms'] ?? '-'} '
      '| ${result.metrics['clientes_page_50'] ?? '-'} '
      '| ${result.metrics['clientes_page_100'] ?? '-'} '
      '| ${result.metrics['clientes_search_name_limit_50'] ?? '-'} '
      '| ${result.metrics['clientes_search_phone_limit_50'] ?? '-'} '
      '| ${result.metrics['movimientos_by_client_100'] ?? '-'} '
      '| ${result.metrics['cuentas_por_cobrar_count'] ?? '-'} '
      '| ${result.metrics['ciclos_vencidos_count'] ?? '-'} '
      '| ${result.metrics['sync_queue_pending_count'] ?? '-'} '
      '| ${result.metrics['dashboard_read'] ?? '-'} '
      '| ${result.metrics['database_size_mb'] ?? result.generated['size_mb'] ?? '-'} '
      '| $status |',
    );
  }

  buffer
    ..writeln()
    ..writeln('## Raw Metrics')
    ..writeln();
  for (final result in results) {
    buffer
      ..writeln('### ${result.scale.clients} clientes')
      ..writeln()
      ..writeln('- Generate exit code: `${result.generateExitCode}`')
      ..writeln('- Benchmark exit code: `${result.benchmarkExitCode}`')
      ..writeln()
      ..writeln('| Metric | Value |')
      ..writeln('| --- | ---: |');
    for (final entry in result.generated.entries) {
      buffer.writeln('| ${entry.key} | ${entry.value} |');
    }
    for (final entry in result.metrics.entries) {
      buffer.writeln('| ${entry.key} | ${entry.value} |');
    }
    buffer.writeln();
  }

  buffer
    ..writeln('## Interpretation')
    ..writeln()
    ..writeln(
      '- Queries over 500 ms should be treated as candidates for index or pagination review.',
    )
    ..writeln(
      '- Queries over 1,500 ms at 100,000 clients are not acceptable for interactive screens.',
    )
    ..writeln(
      '- This benchmark measures SQLite query time, not full Flutter build/layout time.',
    );
  return buffer.toString();
}

class _Scale {
  final int clients;
  final int products;

  const _Scale({required this.clients, required this.products});

  int get movements => clients * 3;
  int get debtItems => movements;
  int get creditCycles => clients;
  int get syncQueue => clients ~/ 2;
  int get audits => clients ~/ 20;
}

class _ScaleResult {
  final _Scale scale;
  final Map<String, String> generated;
  final Map<String, String> metrics;
  final int generateExitCode;
  final int benchmarkExitCode;

  const _ScaleResult({
    required this.scale,
    required this.generated,
    required this.metrics,
    required this.generateExitCode,
    required this.benchmarkExitCode,
  });
}
