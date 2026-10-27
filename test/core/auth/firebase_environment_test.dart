import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/firebase_environment.dart';

void main() {
  test('local native options use a valid-format dummy key and demo resources',
      () {
    const options = FirebaseEnvironment.localOptions;
    expect(options.apiKey, matches(RegExp(r'^AIza[A-Za-z0-9_-]{35}$')));
    expect(options.projectId, 'demo-flixie-local');
    expect(options.storageBucket, 'demo-flixie-local.appspot.com');
  });
  test('local avatars cannot use cloud Storage and Android receives its host',
      () {
    const cloud = 'https://firebasestorage.googleapis.com/v0/b/prod/o/avatar';
    expect(
        FirebaseEnvironment.storageImageUrl(cloud,
            local: true, emulatorHost: '127.0.0.1'),
        isNull);
    expect(
        FirebaseEnvironment.storageImageUrl(cloud,
            local: false, emulatorHost: ''),
        cloud);
    expect(
        FirebaseEnvironment.storageImageUrl(
            'http://127.0.0.1:9199/v0/b/demo/o/avatar',
            local: true,
            emulatorHost: '10.0.2.2'),
        'http://10.0.2.2:9199/v0/b/demo/o/avatar');
  });
  test('local mode only accepts local API and emulator endpoints', () {
    for (final host in ['127.0.0.1', 'localhost', '10.0.2.2']) {
      expect(
          () => FirebaseEnvironment.validate(
              local: true,
              release: false,
              apiUrl: 'http://$host:3000',
              emulatorHost: host),
          returnsNormally);
    }
    for (final api in [
      'https://flixie-api.example.com',
      'http://8.8.8.8:3000'
    ]) {
      expect(
          () => FirebaseEnvironment.validate(
              local: true,
              release: false,
              apiUrl: api,
              emulatorHost: '127.0.0.1'),
          throwsStateError);
    }
    expect(
        () => FirebaseEnvironment.validate(
            local: true,
            release: false,
            apiUrl: 'http://localhost:3000',
            emulatorHost: 'firebase.google.com'),
        throwsStateError);
  });
  test('release forbids emulators and keeps production mode valid', () {
    expect(
        () => FirebaseEnvironment.validate(
            local: true,
            release: true,
            apiUrl: 'http://localhost:3000',
            emulatorHost: '127.0.0.1'),
        throwsStateError);
    expect(
        () => FirebaseEnvironment.validate(
            local: false,
            release: true,
            apiUrl: 'https://production.example.com',
            emulatorHost: ''),
        returnsNormally);
  });
}
