import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/authentication/presentation/pages/splash_screen.dart';

// Deliberately unresolved fictional auth for watching the production splash.
// No Firebase initialization, credentials, requests or delayed production route.
class _PreviewAuth extends ChangeNotifier implements AuthProvider {
  @override
  String? get recoveryError => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() => runApp(ChangeNotifierProvider<AuthProvider>(
    create: (_) => _PreviewAuth(),
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen())));
