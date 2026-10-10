import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';

class ComposerAccountSheet extends StatelessWidget {
  const ComposerAccountSheet(
      {super.key, required this.viewer, required this.child});
  final String viewer;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider?>(context);
    if (auth == null || auth.dbUser?.id == viewer) return child;
    final route = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && route != null && route.isActive) {
        route.navigator?.removeRoute(route);
      }
    });
    return const SizedBox.shrink();
  }
}
