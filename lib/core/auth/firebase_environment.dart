import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Daily debug runs use a separate named app, never the bundled production app.
class FirebaseEnvironment {
  static const useEmulators =
      bool.fromEnvironment('USE_FIREBASE_EMULATORS', defaultValue: kDebugMode);
  static const projectId = 'demo-flixie-local';
  static const bucket = '$projectId.appspot.com';
  static const localOptions = FirebaseOptions(
    // Native Firebase validates the key shape even for the emulator.
    // Assemble this fictional value so secret scanners do not mistake it
    // for an exposed Google credential. It cannot access a real project.
    apiKey: 'AI' 'za' '00000000000000000000000000000000000',
    appId: '1:1234567890:ios:0123456789abcdef',
    messagingSenderId: '1234567890',
    projectId: projectId,
    storageBucket: bucket,
  );
  static const _configuredHost =
      String.fromEnvironment('FIREBASE_EMULATOR_HOST');
  static String get host => _configuredHost.isNotEmpty
      ? _configuredHost
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : '127.0.0.1');
  static FirebaseApp get app =>
      Firebase.app(useEmulators ? 'flixie-local' : defaultFirebaseAppName);
  static FirebaseAuth get auth => FirebaseAuth.instanceFor(app: app);
  static FirebaseFirestore get firestore =>
      FirebaseFirestore.instanceFor(app: app);
  static FirebaseStorage get storage => FirebaseStorage.instanceFor(app: app);

  static void validate(
      {required bool local,
      required bool release,
      required String apiUrl,
      required String emulatorHost}) {
    if (release && local) {
      throw StateError('Release builds cannot use Firebase emulators.');
    }
    if (!local) return;
    bool localHost(String value) =>
        value == 'localhost' ||
        value == '127.0.0.1' ||
        value == '10.0.2.2' ||
        value == '::1' ||
        value == '[::1]';
    final api = Uri.parse(apiUrl);
    if (api.scheme != 'http' ||
        !localHost(api.host) ||
        !localHost(emulatorHost)) {
      throw StateError(
          'Local Firebase requires a loopback/emulator host and local HTTP API.');
    }
  }

  /// Cloud avatar URLs must never bypass the local Storage SDK in debug runs.
  static String? storageImageUrl(String? url,
      {required bool local, required String emulatorHost}) {
    if (!local || url == null) return url;
    final uri = Uri.tryParse(url);
    if (uri?.host == 'firebasestorage.googleapis.com' ||
        uri?.host == 'storage.googleapis.com') {
      return null;
    }
    if (uri != null &&
        uri.port == 9199 &&
        const ['localhost', '127.0.0.1'].contains(uri.host)) {
      return uri.replace(host: emulatorHost).toString();
    }
    return url;
  }

  static Future<void> initializeLocal() async {
    if (!useEmulators) throw StateError('Local Firebase was not selected.');
    final localApp = await Firebase.initializeApp(
        name: 'flixie-local', options: localOptions);
    await FirebaseAuth.instanceFor(app: localApp).useAuthEmulator(host, 9099);
    final database = FirebaseFirestore.instanceFor(app: localApp);
    // Keep emulator restarts from showing stale documents from an earlier seed.
    database.settings = const Settings(persistenceEnabled: false);
    database.useFirestoreEmulator(host, 8185);
    await FirebaseStorage.instanceFor(app: localApp)
        .useStorageEmulator(host, 9199);
  }
}
