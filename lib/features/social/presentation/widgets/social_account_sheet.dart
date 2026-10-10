import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';

/// A root-navigator sheet must not keep another account's controls alive.
class SocialAccountSheet extends StatelessWidget {
  const SocialAccountSheet(
      {super.key, required this.viewer, required this.child});
  final String? viewer;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final current =
        context.select<AuthProvider?, String?>((auth) => auth?.dbUser?.id);
    if (current == viewer) return child;
    final route = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && route != null && route.isActive) {
        route.navigator?.removeRoute(route);
      }
    });
    return const SizedBox.shrink();
  }
}
