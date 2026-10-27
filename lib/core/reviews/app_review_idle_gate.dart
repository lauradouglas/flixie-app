import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import 'app_review_service.dart';

/// Review requests wait until the user returns Home and stops interacting.
class AppReviewIdleGate extends StatefulWidget {
  const AppReviewIdleGate({super.key, required this.child});
  final Widget child;
  @override
  State<AppReviewIdleGate> createState() => _AppReviewIdleGateState();
}

class _AppReviewIdleGateState extends State<AppReviewIdleGate>
    with WidgetsBindingObserver {
  Timer? _idle;
  GoRouter? _router;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppReviewService.changes.addListener(_schedule);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_router != router) {
      _router?.routeInformationProvider.removeListener(_schedule);
      _router = router;
      router.routeInformationProvider.addListener(_schedule);
    }
    _schedule();
  }

  bool _safe(String user) =>
      mounted &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
      _router?.routeInformationProvider.value.uri.path == '/' &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      context.read<AuthProvider>().dbUser?.id == user &&
      context.read<AuthProvider>().dbUser?.completedSetup == true;

  void _schedule() {
    _idle?.cancel();
    final generation = ++_generation;
    if (!mounted) return;
    final user = context.read<AuthProvider>().dbUser;
    if (user == null || !user.completedSetup) return;
    _idle = Timer(const Duration(seconds: 4), () {
      AppReviewService.requestIfEligible(user.id,
          canPrompt: () => generation == _generation && _safe(user.id));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _idle?.cancel();
    _generation++;
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void dispose() {
    _idle?.cancel();
    _router?.routeInformationProvider.removeListener(_schedule);
    AppReviewService.changes.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    return Listener(
        onPointerDown: (_) => _schedule(),
        onPointerMove: (_) => _schedule(),
        onPointerSignal: (_) => _schedule(),
        child: NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _schedule();
              return false;
            },
            child: widget.child));
  }
}
