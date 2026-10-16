import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/guest_home_screen.dart';

// Real guest Home and local public feeds, without signing in or changing the
// device's saved Firebase session. Product navigation is covered by guest_router_test.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
            body: const GuestHomeScreen(),
            bottomNavigationBar:
                NavigationBar(selectedIndex: 0, destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.explore_outlined), label: 'Discover'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline), label: 'You'),
            ]))),
    GoRoute(path: '/:section', builder: (context, _) => _ReturnToPreview()),
    GoRoute(
        path: '/:section/:detail', builder: (context, _) => _ReturnToPreview()),
  ]);
  runApp(MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router));
}

class _ReturnToPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/'))),
      body: const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'Home preview. Open the full Flixie app to continue.'))));
}
