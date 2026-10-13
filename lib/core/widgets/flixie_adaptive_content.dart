import 'package:flutter/material.dart';

/// Keeps tablet reading surfaces centred without changing the phone layout.
class FlixieAdaptiveContent extends StatelessWidget {
  const FlixieAdaptiveContent({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth >= 700 ? 24 : 0),
              child: child,
            ),
          ),
        ),
      );
}

/// Related sections share a row only when both have a useful reading width.
/// Large text and narrow tablet windows return to the natural reading order.
class FlixieAdaptiveColumns extends StatelessWidget {
  const FlixieAdaptiveColumns({
    super.key,
    required this.primary,
    required this.secondary,
    this.breakpoint = 900,
    this.primaryFlex = 2,
    this.secondaryFlex = 1,
  });
  final Widget primary, secondary;
  final double breakpoint;
  final int primaryFlex, secondaryFlex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= breakpoint &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.4;
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [primary, const SizedBox(height: 24), secondary],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: primaryFlex, child: primary),
              const SizedBox(width: 28),
              Expanded(flex: secondaryFlex, child: secondary),
            ],
          );
        },
      );
}
