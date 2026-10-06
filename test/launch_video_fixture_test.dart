import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../patrol_test/launch_video_details_test.dart' show LaunchDetailFixture;
import '../patrol_test/support/store_screenshot_fixture.dart';
import 'support/api_fixture.dart';

void main() {
  testWidgets('launch movie reviews are visible in the real reviews tab',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = LaunchDetailFixture();
    useApiFixture(fixture.client);
    final auth = StoreScreenshotAuth();
    final router = storeScreenshotRouter();
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(storeScreenshotApp(auth, router));
    router.go('/movies/157336');
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(find.text('Reviews').first),
        alignment: .35);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reviews').first);
    await tester.pumpAndSettle();
    expect(find.text('A film that stays with you'), findsOneWidget);
    expect(fixture.unexpectedRequests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 16));
  });
}
