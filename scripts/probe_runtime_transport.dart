import 'dart:convert';
import 'dart:io';

// Real HTTP only: 20 pooled reads, six seconds idle, repeated five times.
// Run before a native capture, never concurrently with its measured windows.
Future<void> main() async {
  final client = HttpClient();
  final results = <Map<String, Object>>[];
  try {
    final uri = Uri.parse('http://127.0.0.1:3007/benchmark/manifest');
    final bootstrap = await (await client.getUrl(uri)).close();
    final manifest = jsonDecode(await utf8.decoder.bind(bootstrap).join())
        as Map<String, dynamic>;
    if (manifest['database'] != 'flixie_runtime_fixture') {
      throw StateError('Isolated fixture API required');
    }
    for (var round = 0; round < 5; round++) {
      final reads = await Future.wait(List.generate(20, (_) async {
        try {
          final response = await (await client.getUrl(uri)).close();
          await response.drain<void>();
          return '${response.statusCode}';
        } catch (error) {
          return error.toString();
        }
      }));
      final errors = reads.where((status) => status != '200').toList();
      results.add(
          {'round': round + 1, 'requests': reads.length, 'errors': errors});
      if (round < 4) {
        await Future<void>.delayed(const Duration(seconds: 6));
      }
    }
    final clean = results.every((result) => (result['errors'] as List).isEmpty);
    stdout.writeln(jsonEncode({
      'database': manifest['database'],
      'transport': manifest['transport'],
      'idle_ms': 6000,
      'requests': 100,
      'clean': clean,
      'rounds': results,
    }));
    if (!clean) exitCode = 1;
  } finally {
    client.close(force: true);
  }
}
