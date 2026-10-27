import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';

void main() {
  test('accepts Apple-style passwords with hyphens as special characters', () {
    expect(validateFirebasePassword('vexnup-ramqiZ-3tobfes'), isNull);
    expect(validateFirebasePassword('Flixie123-'), isNull);
  });

  test('still requires a special character', () {
    expect(validateFirebasePassword('Flixie123'), contains('special'));
  });
}
