import 'package:flutter/foundation.dart';

enum SocialAuthProvider {
  apple('apple.com', 'Apple'),
  google('google.com', 'Google');

  const SocialAuthProvider(this.id, this.label);
  final String id;
  final String label;

  static List<SocialAuthProvider> get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? const [google]
          : values;
}
