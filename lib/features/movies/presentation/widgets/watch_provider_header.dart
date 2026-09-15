import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class WatchProviderHeader extends StatelessWidget {
  const WatchProviderHeader(
      {super.key, required this.region, required this.onChange});
  final String region;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(
              child: Text('Where to watch',
                  style: TextStyle(
                      color: FlixieColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Semantics(
            label: 'Change watch provider country, $region',
            child: TextButton(
              onPressed: onChange,
              style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(region == 'GB' ? 'UK' : region,
                    style: const TextStyle(
                        color: FlixieColors.primaryText,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: FlixieColors.primaryText, size: 22),
              ]),
            ),
          ),
        ],
      );
}
