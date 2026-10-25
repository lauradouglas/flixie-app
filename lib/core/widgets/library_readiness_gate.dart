import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';

/// Protect collection-dependent routes from treating an unloaded library as empty.
/// Home can render independently while its library hydrates in the background.
class LibraryReadinessGate extends StatefulWidget {
  const LibraryReadinessGate(
      {super.key,
      required this.requiredForRoute,
      required this.onHome,
      required this.child});
  final bool requiredForRoute;
  final VoidCallback onHome;
  final Widget child;
  @override
  State<LibraryReadinessGate> createState() => _LibraryReadinessGateState();
}

class _LibraryReadinessGateState extends State<LibraryReadinessGate> {
  String? _owner;
  bool _attempted = false, _failed = false;
  void _load(AuthProvider auth) {
    _attempted = true;
    final owner = auth.dbUser?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || auth.dbUser?.id != owner) return;
      final success = await auth.ensureLibraryLoaded();
      if (success && auth.dbUser?.id == owner && owner != null) {
        auth.releaseStartupWarmup(owner);
      }
      if (mounted && auth.dbUser?.id == owner) {
        setState(() => _failed = !success);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (_owner != auth.dbUser?.id) {
      _owner = auth.dbUser?.id;
      _attempted = false;
      _failed = false;
    }
    final blocked = widget.requiredForRoute &&
        auth.status == AuthStatus.authenticated &&
        auth.termsVerified &&
        auth.dbUser?.completedSetup == true &&
        auth.dbUser?.hasLibrarySnapshot != true;
    if (blocked && !_attempted && TickerMode.valuesOf(context).enabled) {
      _load(auth);
    }
    if (!blocked) return widget.child;
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: widget.onHome)),
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!_failed) const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
              _failed ? 'Couldn’t load your library.' : 'Loading your library…',
              textAlign: TextAlign.center),
          if (_failed)
            TextButton(
                onPressed: () {
                  setState(() => _failed = false);
                  _load(auth);
                },
                child: const Text('Try again')),
        ]),
      ))),
    );
  }
}
