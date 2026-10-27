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
      for (final icon in ['pipGlasses', 'pipHoodie']) {
        await service.select(icon);
        expect(selected, icon);
      }
    }
  });
  test('Other badges cannot select Pip', () async {
    final service = AppIconService(channel: channel);
    service.updateUser(member('other', ['OG_USER', 'FOUNDING_FILM_FRIEND']));
    await expectLater(service.select('pipGlasses'), throwsStateError);
    await expectLater(service.select('pipHoodie'), throwsStateError);
    expect(calls, isEmpty);
  });
  test('Sign out restores the default and rejects a queued selection',
      () async {
    final service = AppIconService(channel: channel);
    service.updateUser(member('founder', ['FOUNDER']));
    await service.select('pipHoodie');
    final queued = service.select('pipHoodie');
    service.updateUser(null);
    await expectLater(queued, throwsStateError);
    await service.select('default');
    expect(selected, 'default');
  });
  test('Cinema Club requires a verified entitlement for the current account',
      () async {
    final service = AppIconService(channel: channel);
    service.updateUser(member('cinema', []));
    await expectLater(service.select('pipPeeksIn'), throwsStateError);
    service.updateCinemaEntitlement('someone-else', true);
    await expectLater(service.select('pipPeeksIn'), throwsStateError);
    service.updateCinemaEntitlement('cinema', true);
    await service.select('pipPeeksIn');
    expect(selected, 'pipPeeksIn');
    service.updateUser(member('cinema', []));
    await service.select('pipPeeksIn');
    service.updateUser(member('other', []));
    await expectLater(service.select('pipPeeksIn'), throwsStateError);
    service.updateCinemaEntitlement('other', false);
    await service.select('default');
    expect(selected, 'default');
  });
}
