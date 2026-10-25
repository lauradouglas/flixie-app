import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/pip_startup_brand.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(fit: StackFit.expand, children: [
        const Center(child: PipStartupBrand()),
        if (auth.recoveryError != null)
          SafeArea(
              child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(auth.recoveryError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colors.textPrimary)),
                      TextButton(
                          onPressed: auth.retrySession,
                          child: const Text('Retry')),
                    ]),
                  ))),
      ]),
    );
  }
}
