import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

bool _canPop(BuildContext context) =>
    GoRouter.maybeOf(context)?.canPop() ?? Navigator.of(context).canPop();

String flixieBackLabel(BuildContext context) =>
    _canPop(context) ? 'Back' : 'Home';

IconData flixieBackIcon(BuildContext context,
        {IconData backIcon = Icons.arrow_back}) =>
    _canPop(context) ? backIcon : Icons.home_outlined;

void flixieBackOrHome(BuildContext context) {
  if (_canPop(context)) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.pop();
    } else {
      Navigator.of(context).maybePop();
    }
  } else {
    GoRouter.maybeOf(context)?.go('/');
  }
}

/// Returns to the preserved page, or offers Home for a standalone destination.
class FlixieBackButton extends StatelessWidget {
  const FlixieBackButton(
      {super.key, this.fallbackLocation = '/', this.enabled = true});

  final String fallbackLocation;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return IconButton(
          tooltip: flixieBackLabel(context),
          icon: Icon(flixieBackIcon(context)),
          onPressed: null);
    }
    if (!_canPop(context) && fallbackLocation == '/') {
      return IconButton(
        tooltip: 'Home',
        icon: const Icon(Icons.home_outlined),
        onPressed: enabled ? () => GoRouter.maybeOf(context)?.go('/') : null,
      );
    }
    return BackButton(
        onPressed: enabled
            ? () {
                if (_canPop(context)) {
                  final router = GoRouter.maybeOf(context);
                  if (router != null) {
                    router.pop();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                } else {
                  GoRouter.maybeOf(context)?.go(fallbackLocation);
                }
              }
            : null);
  }
}
