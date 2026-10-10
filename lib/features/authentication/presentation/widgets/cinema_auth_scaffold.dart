import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/cinema_light_background.dart';
import 'package:flixie_app/core/widgets/cinema_wordmark.dart';

/// Open, scrollable authentication forms in the welcome's visual world.
class CinemaAuthScaffold extends StatelessWidget {
  const CinemaAuthScaffold(
      {super.key,
      required this.heading,
      required this.subtitle,
      required this.form,
      this.onBack});
  final String heading, subtitle;
  final Widget form;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        resizeToAvoidBottomInset: true,
        body: Stack(children: [
          const Positioned.fill(child: CinemaLightBackground()),
          SafeArea(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 28, 12),
                      child: Row(children: [
                        if (onBack != null)
                          IconButton(
                              tooltip: 'Back',
                              onPressed: onBack,
                              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 20)),
                        if (onBack == null) const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        const Flexible(child: CinemaWordmark(fontSize: 30)),
                      ])),
                  Expanded(
                      child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(heading,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                      fontSize: 31,
                                      height: 1.15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -.6)),
                          const SizedBox(height: 12),
                          Text(subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(height: 1.5)),
                          const SizedBox(height: 28),
                          form,
                        ]),
                  )),
                ]),
          ))),
        ]),
      );
}
