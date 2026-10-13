import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/pip_startup_brand.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: context.colors.background,
      body: FadeTransition(
        opacity: MediaQuery.disableAnimationsOf(context)
            ? const AlwaysStoppedAnimation(1.0)
            : _fadeIn,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Center(
              child: PipStartupBrand(),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: auth.recoveryError != null
                      ? Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(auth.recoveryError!,
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: context.colors.textPrimary)),
                          TextButton(
                              onPressed: auth.retrySession,
                              child: const Text('Retry')),
                        ])
                      : const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              FlixieColors.primary,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
