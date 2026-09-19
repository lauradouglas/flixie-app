import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flixie_app/core/api/api_client.dart';

/// Install isolated networking for native callbacks that escape test zones.
void useApiFixture(http.Client client) {
  ApiClient.useClientForTesting(client);
  addTearDown(() {
    ApiClient.useClientForTesting(null);
    client.close();
  });
}
