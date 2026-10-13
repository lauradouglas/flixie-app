import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/app_icon/app_icon_service.dart';
import 'package:flixie_app/models/user.dart';

User member(String id, List<String> badges) => User(
      id: id,
      username: 'renamed-member',
      email: 'fixture@example.invalid',
      iconColorId: 1,
      completedSetup: true,
      darkMode: false,
      profileBadges: badges,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/app_icon');
  final calls = <String>[];
  var selected = 'default';
  setUp(() {
    calls.clear();
    selected = 'default';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'status') {
        return {'supported': true, 'selected': selected};
      }
      selected = call.arguments as String;
      calls.add(selected);
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('Founder and First 100 retain access after renaming', () async {
    for (final badge in ['FOUNDER', 'EARLY_ADOPTER']) {
      final service = AppIconService(channel: channel);
      service.updateUser(member('fixture-$badge', [badge]));
      await service.select('pipGlasses');
      expect(selected, 'pipGlasses');
    }
  });
  test('Other badges cannot select Pip', () async {
    final service = AppIconService(channel: channel);
    service.updateUser(member('other', ['OG_USER', 'FOUNDING_FILM_FRIEND']));
    await expectLater(service.select('pipGlasses'), throwsStateError);
    expect(calls, isEmpty);
  });
  test('Sign out restores the default and rejects a queued selection',
      () async {
    final service = AppIconService(channel: channel);
    service.updateUser(member('founder', ['FOUNDER']));
    await service.select('pipGlasses');
    final queued = service.select('pipGlasses');
    service.updateUser(null);
    await expectLater(queued, throwsStateError);
    await service.select('default');
    expect(selected, 'default');
  });
}
