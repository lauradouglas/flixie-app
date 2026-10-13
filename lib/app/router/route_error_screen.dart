import 'package:flixie_app/core/widgets/pip_startup_illustration.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/reviews/app_review_service.dart';

/// Recovery for navigation failures. Never expose link tokens or exceptions.
class RouteErrorScreen extends StatefulWidget {
  const RouteErrorScreen(
      {super.key, required this.unknownLink, this.openStore});
  final bool unknownLink;
  final Future<bool> Function()? openStore;

  @override
  State<RouteErrorScreen> createState() => _RouteErrorScreenState();
}

class _RouteErrorScreenState extends State<RouteErrorScreen> {
  bool _openingStore = false;
  String? _storeError;

  Future<void> _update() async {
    if (_openingStore) return;
    setState(() {
      _openingStore = true;
      _storeError = null;
    });
    var opened = false;
    try {
      opened = await (widget.openStore ?? AppReviewService.openUpdateListing)();
    } catch (_) {
      // Keep recovery available when a store/plugin is unavailable.
    }
    if (!mounted) return;
    setState(() {
      _openingStore = false;
      if (!opened) {
        _storeError =
            'Couldn’t open the store. Search for Flixie in your app store to check for an update.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight:
                      (constraints.maxHeight - 48).clamp(0, double.infinity)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(
                        width: 200,
                        height: 210,
                        child: PipStartupIllustration(
                            asset: 'assets/splash/pip/confused-phone.png',
                            size: 200)),
                    const SizedBox(height: 24),
                    Text('Pip couldn’t find this page',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text(
                        widget.unknownLink
                            ? 'This link may belong to a newer version of Flixie, or the page may have moved. You may need to update Flixie to open it.'
                            : 'Something went wrong opening this page. Head home and try opening it again.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 28),
                    if (widget.unknownLink) ...[
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _openingStore ? null : _update,
                            child: Text(_openingStore
                                ? 'Opening store…'
                                : 'Check for an update'),
                          )),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.go('/'),
                          child: const Text('Go home'),
                        )),
                    if (_storeError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(_storeError!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium)),
                      ),
                  ]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
