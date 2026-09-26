import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/profile/presentation/pages/friend_profile_screen.dart';
import 'package:flixie_app/features/profile/presentation/pages/milestones_screen.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User get dbUser => const User(
      id: 'me',
      username: 'Me',
      email: '',
      iconColorId: 0,
      completedSetup: true,
      darkMode: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    await loader.load();
  });
  for (final hasCover in [false, true]) {
    for (final friends in [true, false]) {
      testWidgets(
          'current profile milestones access: friends=$friends cover=$hasCover',
          (tester) async {
        final requests = <String>[];
        var following = friends;
        final capture = GlobalKey();
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ApiClient.useClientForTesting(MockClient((request) async {
          final path = request.url.path;
          requests.add(path);
          Object data = [];
          if (path.endsWith('/users/friend')) {
            data = {
              'id': 'friend',
              'username': 'LauraD',
              'bio': hasCover
                  ? List.filled(
                          12, 'Sci-fi, big screens and a good plot twist.')
                      .join(' ')
                  : 'Sci-fi, big screens and a good plot twist.',
              'email': '',
              'iconColorId': 0,
              'completedSetup': true,
              'darkMode': true,
              if (hasCover)
                'creatorProfile': {
                  'verified': true,
                  'role': 'director',
                  'coverUrl': 'https://example.invalid/cover.jpg',
                  'answers': [],
                },
            };
          } else if (path.endsWith('/community/profiles/friend/follow')) {
            if (request.method == 'PUT')
              following =
                  (jsonDecode(request.body) as Map)['following'] as bool;
            data = {'following': following};
          } else if (path.endsWith('/friends/me')) {
            data = {
              'friendships': friends
                  ? [
                      {
                        'id': 'edge',
                        'friend': {'id': 'friend', 'username': 'LauraD'}
                      }
                    ]
                  : [],
              'pendingFriends': [],
              'requestedFriends': []
            };
          } else if (path.endsWith('/activity')) {
            data = {'items': [], 'nextCursor': null};
          } else if (path.endsWith('/milestones')) {
            data = {'visibility': 'friends', 'items': []};
          }
          return http.Response(jsonEncode(data), 200);
        }));
        addTearDown(() => ApiClient.useClientForTesting(null));
        final auth = _Auth();
        addTearDown(auth.dispose);
        await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
                theme: AppTheme.darkTheme,
                builder: (context, child) =>
                    RepaintBoundary(key: capture, child: child!),
                home: const FriendProfileScreen(
                    userId: 'friend', showCommunityFollow: true))));
        await tester.pumpAndSettle();
        if (const bool.fromEnvironment('PROFILE_SCREENSHOTS')) {
          await tester.runAsync(() async {
            final image = await (capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('/tmp/adaptive-profile-$friends.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(find.text('Profile'), hasCover ? findsNothing : findsOneWidget);
        if (hasCover) {
          final rect =
              tester.getRect(find.byKey(const ValueKey('profile-cover')));
          expect(rect.left, 0);
          expect(rect.top, 0);
          expect(rect.width, 390);
        }
        expect(find.text('Follow'), friends ? findsNothing : findsOneWidget);
        expect(find.textContaining('… Read more'),
            hasCover ? findsOneWidget : findsNothing);
        if (hasCover) {
          await tester.tap(find.textContaining('… Read more'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Read less'), findsOneWidget);
          await tester.ensureVisible(find.textContaining('Read less'));
          await tester.tap(find.textContaining('Read less'));
          await tester.pumpAndSettle();
          await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
          await tester.pumpAndSettle();
        }
        expect(find.text('Overview'), findsNothing);
        expect(find.text('Watched'), findsNothing);
        expect(
            find.text('Add Friend'), friends ? findsNothing : findsOneWidget);
        expect(find.text('Message'), friends ? findsOneWidget : findsNothing);
        if (!friends) {
          await tester.tap(find.text('Follow'));
          await tester.pumpAndSettle();
          expect(find.text('Following'), findsOneWidget);
        } else {
          expect(find.text('✓ Friends'), findsOneWidget);
          await tester.tap(find.byTooltip('Unfollow'));
          await tester.pumpAndSettle();
          expect(find.text('Follow'), findsOneWidget);
          expect(find.text('✓ Friends'), findsOneWidget);
          expect(find.text('Message'), findsOneWidget);
          expect(following, isFalse);
        }
        // The cover remains full bleed as content reflows on narrow phones,
        // landscape and tablets, including accessibility text sizes.
        if (hasCover) {
          for (final size in [
            const Size(320, 700),
            const Size(844, 390),
            const Size(1024, 1366)
          ]) {
            tester.view.physicalSize = size;
            tester.platformDispatcher.textScaleFactorTestValue = 2;
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
                tester
                    .getSize(find.byKey(const ValueKey('profile-cover')))
                    .width,
                size.width);
          }
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          tester.view.physicalSize = const Size(390, 844);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip('Profile actions'));
        await tester.pumpAndSettle();
        expect(find.text('Report user'), findsOneWidget);
        expect(find.text('Block user'), findsOneWidget);
        await tester.tapAt(const Offset(5, 150));
        await tester.pumpAndSettle();
        final link = find.text('View earned milestones');
        if (friends) {
          expect(link, findsOneWidget);
          await tester.ensureVisible(link);
          await tester.pumpAndSettle();
          await tester.tap(link);
          await tester.pumpAndSettle();
          expect(find.byType(MilestonesScreen), findsOneWidget);
          expect(find.text('LauraD’s movie moments'), findsOneWidget);
          expect(
              requests.any((path) => path.endsWith('/users/friend/milestones')),
              isTrue);
        } else {
          expect(link, findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
