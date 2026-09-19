import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';

/// A plain-language starting point shared by watchlist and discovery.
class WatchRequestInput extends StatelessWidget {
  const WatchRequestInput(
      {super.key, required this.controller, this.enabled = true});
  final TextEditingController controller;
  final bool enabled;

  void _choose(String value) {
    controller.value = TextEditingValue(
        text: value, selection: TextSelection.collapsed(offset: value.length));
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            enabled: enabled,
            maxLength: 300,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What do you fancy?',
              hintText: 'A chick flick, something cozy, a gripping romance…',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final chickFlick =
                    RegExp(r'\bchick\s*flicks?\b', caseSensitive: false)
                        .hasMatch(controller.text);
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (controller.text.trim().isEmpty)
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          for (final example in const [
                            'Chick flick',
                            'Something cozy',
                            'Get hooked'
                          ])
                            FlixiePill.action(
                                label: Text(example),
                                onPressed:
                                    enabled ? () => _choose(example) : null),
                        ]),
                      if (chickFlick) ...[
                        const Text(
                            'Romance or friendship stories. Narrow it down?'),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          for (final entry in const {
                            'Rom-com': 'rom com',
                            'Friendship': 'friendship',
                            'Emotional romance': 'emotional romance'
                          }.entries)
                            FlixiePill.action(
                                label: Text(entry.key),
                                onPressed: enabled
                                    ? () => _choose(controller.text.replaceAll(
                                        RegExp(r'\bchick\s*flicks?\b',
                                            caseSensitive: false),
                                        entry.value))
                                    : null),
                        ]),
                      ],
                    ]);
              }),
        ],
      );
}
