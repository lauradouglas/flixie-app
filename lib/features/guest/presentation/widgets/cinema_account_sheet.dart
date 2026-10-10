import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/cinema_light_background.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';

/// Contextual account invitation in the shared Cinema light visual style.
class CinemaAccountSheet extends StatelessWidget {
  const CinemaAccountSheet(
      {super.key,
      required this.title,
      required this.message,
      required this.onChoice,
      this.showReturnNote = false});
  final String title, message;
  final bool showReturnNote;
  final ValueChanged<String?> onChoice;

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
          child: Stack(children: [
            const Positioned.fill(child: CinemaLightBackground()),
            SafeArea(
                top: false,
                child: SingleChildScrollView(
                    child: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 12, 24, 16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Center(
                                          child: Container(
                                              width: 34,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                  color: context.colors.medium,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          4)))),
                                      const SizedBox(height: 12),
                                      Row(children: [
                                        const Expanded(
                                            child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: FlixieWordmark(
                                                    fontSize: 28))),
                                        IconButton(
                                            tooltip: 'Close',
                                            onPressed: () => onChoice(null),
                                            icon:
                                                const Icon(Icons.close_rounded),
                                            color: context.colors.light),
                                      ]),
                                      const SizedBox(height: 20),
                                      Text(title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                  fontSize: 28,
                                                  height: 1.15,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -.5)),
                                      const SizedBox(height: 16),
                                      Text(message,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                  color: context.colors.light,
                                                  height: 1.5)),
                                      const SizedBox(height: 28),
                                      FilledButton(
                                          onPressed: () => onChoice('signup'),
                                          style: FilledButton.styleFrom(
                                              minimumSize: const Size(0, 55)),
                                          child: const Text('Create account')),
                                      if (showReturnNote) ...[
                                        const SizedBox(height: 12),
                                        Text('We’ll bring you back here.',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                    color:
                                                        context.colors.light)),
                                      ],
                                      const SizedBox(height: 8),
                                      TextButton(
                                          onPressed: () => onChoice('login'),
                                          style: TextButton.styleFrom(
                                              textStyle: const TextStyle(
                                                  fontSize: 14)),
                                          child: const Text(
                                              'Already a member? Sign in')),
                                      TextButton(
                                          onPressed: () => onChoice(null),
                                          style: TextButton.styleFrom(
                                              foregroundColor:
                                                  context.colors.light,
                                              textStyle: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500)),
                                          child: const Text('Keep exploring')),
                                    ])))))),
          ])));
}
