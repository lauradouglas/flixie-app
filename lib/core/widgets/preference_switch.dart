import 'package:flutter/material.dart';

/// Unknown preferences have no on/off state until their saved value is loaded.
class PreferenceSwitch extends StatelessWidget {
  const PreferenceSwitch(
      {super.key,
      required this.value,
      required this.onChanged,
      this.loading = true});
  final bool? value;
  final bool loading;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => value == null
      ? SizedBox(
          width: 52,
          height: 32,
          child: Center(
              child: SizedBox.square(
                  dimension: 18,
                  child: loading
                      ? const CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Loading saved preference')
                      : const Icon(Icons.more_horiz,
                          semanticLabel: 'Saved preference unavailable'))))
      : Switch.adaptive(value: value!, onChanged: onChanged);
}
