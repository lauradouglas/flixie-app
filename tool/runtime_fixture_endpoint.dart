import 'dart:io';

/// The device variant uses the Mac's private USB or Wi-Fi fixture address.
const runtimeFixtureHost =
    String.fromEnvironment('RUNTIME_FIXTURE_HOST', defaultValue: '127.0.0.1');

bool isRuntimeFixtureEndpoint(String baseUrl, String host) {
  final address = InternetAddress.tryParse(host);
  final privateTunnel = address?.type == InternetAddressType.IPv6 &&
      address!.rawAddress[0] == 0xfd;
  final bytes = address?.rawAddress;
  final privateWifi = address?.type == InternetAddressType.IPv4 &&
      (bytes![0] == 10 ||
          (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
          (bytes[0] == 192 && bytes[1] == 168));
  final url = Uri.tryParse(baseUrl);
  if (url == null ||
      (host != '127.0.0.1' && !privateTunnel && !privateWifi) ||
      url.scheme != 'http' ||
      url.host != host ||
      url.port != 3007 ||
      url.path.isNotEmpty ||
      url.query.isNotEmpty ||
      url.hasFragment ||
      url.userInfo.isNotEmpty) {
    return false;
  }
  return true;
}

void verifyRuntimeFixtureEndpoint(String baseUrl) {
  if (!Platform.isIOS ||
      !isRuntimeFixtureEndpoint(baseUrl, runtimeFixtureHost)) {
    throw StateError('Requires the isolated local runtime fixture endpoint.');
  }
}

String get runtimeFirestoreHost => runtimeFixtureHost.contains(':')
    ? '[$runtimeFixtureHost]'
    : runtimeFixtureHost;
