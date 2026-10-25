// Manual native SDK smoke test. Uses a loopback receiver and a fake ingestion
// token; never sends fixture activity to the production PostHog project.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:flixie_app/core/analytics/analytics_consent.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/posthog_analytics_backend.dart';

class _Consent implements AnalyticsConsentStore {
  AnalyticsConsent value = AnalyticsConsent.unknown;
  @override
  Future<AnalyticsConsent> read() async => value;
  @override
  Future<void> write(AnalyticsConsent next) async {
    value = next;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
      home: Scaffold(
          body:
              Center(child: Text('Isolated native analytics verification')))));
  unawaited(_verify());
}

Future<void> _verify() async {
  final events = <Map<String, dynamic>>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final bytes =
        await request.fold<List<int>>([], (all, part) => all..addAll(part));
    if (bytes.isNotEmpty) {
      final payload = request.headers.value('content-encoding') == 'gzip'
          ? gzip.decode(bytes)
          : bytes;
      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is Map && decoded['batch'] is List) {
        events.addAll((decoded['batch'] as List).cast<Map<String, dynamic>>());
      } else if (decoded is Map<String, dynamic> && decoded['event'] != null) {
        events.add(decoded);
      }
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write('{"status":1}');
    await request.response.close();
  });
  final analytics = AnalyticsController(
    backend: PostHogAnalyticsBackend(
        projectToken: 'phc_isolated_native_verification',
        host: 'http://127.0.0.1:${server.port}'),
    consentStore: _Consent(),
  );
  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
  }

  try {
    await analytics.initialize();
    await analytics.searchResultOpened(
        mode: 'movies', resultType: 'movie', position: 1);
    check(events.isEmpty, 'collection before consent');
    await analytics.allow();
    await analytics.screenViewed('Search');
    await analytics.searchCompleted(mode: 'movies', resultCount: 1);
    await analytics.searchResultOpened(
        mode: 'movies', resultType: 'movie', position: 1);
    await analytics.detailActionTapped(
        contentType: 'movie', action: 'watchlist');
    await Posthog().flush();
    for (var i = 0; i < 40 && events.length < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final names = events.map((e) => e['event']).toSet();
    check(
        names.containsAll({
          '\$screen',
          'search_completed',
          'search_result_opened',
          'detail_action_tapped'
        }),
        'missing native events: $names');
    check(Platform.isIOS, 'test did not run on iOS');
    check(events.every((e) => (e['properties'] as Map)[r'$os_name'] == 'iOS'),
        'native iOS metadata missing');
    final tap = events.firstWhere(
        (e) => e['event'] == 'search_result_opened')['properties'] as Map;
    check(tap['result_type'] == 'movie' && tap['position'] == 1,
        'tap properties missing');
    final count = events.length;
    await analytics.decline();
    await analytics.searchResultOpened(
        mode: 'shows', resultType: 'show', position: 2);
    await Posthog().flush();
    await Future<void>.delayed(const Duration(seconds: 1));
    check(events.length == count, 'collection after withdrawal');
    debugPrint('NATIVE_ANALYTICS_SMOKE_PASS ${jsonEncode({
          'platform': 'iOS',
          'events': names.toList(),
          'before_consent_blocked': true,
          'withdrawal_blocked': true,
          'receiver': 'loopback only'
        })}');
  } catch (error, stack) {
    debugPrint('NATIVE_ANALYTICS_SMOKE_FAIL $error\n$stack');
  } finally {
    await Posthog().close();
    analytics.dispose();
    await server.close(force: true);
  }
}
